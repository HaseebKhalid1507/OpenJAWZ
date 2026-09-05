"""
tasks_engine.py — Core task management engine for synaps-tasks plugin.
"""

import json
import os
import sys
import fcntl
import time
import math
import shutil
from datetime import date, datetime, timezone
from typing import Optional

DATA_DIR = os.environ.get("OPENJAWZ_DATA") or os.path.join(
    os.environ.get("OPENJAWZ_HOME", os.path.join(os.environ.get("XDG_DATA_HOME", os.path.expanduser("~/.local/share")), "openjawz")), "data")
TASKS_FILE = os.path.join(DATA_DIR, "tasks.json")
HISTORY_FILE = os.path.join(DATA_DIR, "tasks_history.json")
PINS_FILE = os.path.join(DATA_DIR, "pins.json")
LOCK_FILE = os.path.join(DATA_DIR, "tasks.json.lock")

VALID_STATUSES = {"todo", "in-progress", "done", "blocked"}
VALID_PRIORITIES = {"high", "medium", "low"}

PRIORITY_WEIGHT = {"high": 10, "medium": 5, "low": 2, None: 1}


def _log(msg):
    print(f"[synaps-tasks] {msg}", file=sys.stderr)


# ---------------------------------------------------------------------------
# File locking
# ---------------------------------------------------------------------------

class FileLock:
    def __init__(self, path=LOCK_FILE, timeout=5):
        self.path = path
        self.timeout = timeout
        self._fd = None

    def __enter__(self):
        deadline = time.time() + self.timeout
        while True:
            try:
                self._fd = open(self.path, "w")
                fcntl.flock(self._fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
                self._fd.write(str(os.getpid()))
                self._fd.flush()
                return self
            except (IOError, OSError):
                if self._fd:
                    try:
                        self._fd.close()
                    except Exception:
                        pass
                    self._fd = None
                if time.time() >= deadline:
                    raise TimeoutError(f"Could not acquire lock on {self.path} after {self.timeout}s")
                time.sleep(0.05)

    def __exit__(self, *_):
        if self._fd:
            try:
                fcntl.flock(self._fd, fcntl.LOCK_UN)
                self._fd.close()
            except Exception:
                pass
            self._fd = None
        try:
            os.unlink(self.path)
        except FileNotFoundError:
            pass


# ---------------------------------------------------------------------------
# I/O helpers
# ---------------------------------------------------------------------------

def _read_json(path, default):
    if not os.path.exists(path):
        return default
    with open(path, "r", encoding="utf-8") as f:
        try:
            return json.load(f)
        except json.JSONDecodeError:
            _log(f"WARNING: corrupt JSON at {path}, returning default")
            return default


def _write_json(path, data):
    bak = path + ".bak"
    if os.path.exists(path):
        shutil.copy2(path, bak)
    tmp = path + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
        f.flush()
        os.fsync(f.fileno())
    os.replace(tmp, path)


# ---------------------------------------------------------------------------
# Date helpers
# ---------------------------------------------------------------------------

def _today() -> str:
    return date.today().isoformat()


def _days_until(deadline_str: str) -> Optional[int]:
    """Days until deadline. Negative means overdue."""
    try:
        d = date.fromisoformat(deadline_str)
        return (d - date.today()).days
    except (ValueError, TypeError):
        return None


def _now_ts() -> float:
    return datetime.now(timezone.utc).timestamp()


def _elapsed_str(seconds: float) -> str:
    """Human-readable elapsed time."""
    seconds = int(seconds)
    if seconds < 60:
        return f"{seconds}s"
    minutes = seconds // 60
    if minutes < 60:
        return f"{minutes}min"
    hours = minutes // 60
    rem_min = minutes % 60
    return f"{hours}h {rem_min}min" if rem_min else f"{hours}h"


# ---------------------------------------------------------------------------
# TaskEngine
# ---------------------------------------------------------------------------

class TaskEngine:

    # ---- loading / saving --------------------------------------------------

    def load_tasks(self) -> dict:
        return _read_json(TASKS_FILE, {"next_id": 1, "tasks": []})

    def save_tasks(self, data: dict):
        with FileLock():
            _write_json(TASKS_FILE, data)

    def load_history(self) -> dict:
        raw = _read_json(HISTORY_FILE, {})
        # Normalise: history may use "completed" or "tasks" key from old format
        if "tasks" not in raw:
            if "completed" in raw:
                raw["tasks"] = raw["completed"]
            else:
                raw["tasks"] = []
        return raw

    def save_history(self, data: dict):
        _write_json(HISTORY_FILE, data)

    def load_pins(self) -> dict:
        return _read_json(PINS_FILE, {
            "pinned": [],
            "focus": None,
            "session_goals": [],
            "session_start": None,
            "velocity": {"sessions": []}
        })

    def save_pins(self, data: dict):
        _write_json(PINS_FILE, data)

    # ---- task lookup -------------------------------------------------------

    def find_task(self, task_id: int) -> Optional[dict]:
        data = self.load_tasks()
        for t in data["tasks"]:
            if t["id"] == task_id:
                return t
        return None

    # ---- listing / filtering -----------------------------------------------

    def list_tasks(
        self,
        status=None,
        priority=None,
        category=None,
        search=None,
        sort=None,
    ) -> list:
        data = self.load_tasks()
        tasks = data["tasks"]

        if status:
            tasks = [t for t in tasks if t.get("status") == status]
        if priority:
            tasks = [t for t in tasks if t.get("priority") == priority]
        if category:
            tasks = [t for t in tasks if (t.get("category") or "").lower() == category.lower()]
        if search:
            q = search.lower()
            tasks = [t for t in tasks if self._matches_search(t, q)]

        if sort == "deadline":
            tasks = sorted(tasks, key=lambda t: (t.get("deadline") is None, t.get("deadline") or ""))
        elif sort == "priority":
            order = {"high": 0, "medium": 1, "low": 2, None: 3}
            tasks = sorted(tasks, key=lambda t: order.get(t.get("priority"), 3))
        elif sort == "created":
            tasks = sorted(tasks, key=lambda t: t.get("created", ""))
        # default: preserve file order (insertion order = natural)

        return tasks

    def _matches_search(self, task: dict, q: str) -> bool:
        if q in (task.get("title") or "").lower():
            return True
        if q in (task.get("notes") or "").lower():
            return True
        for st in task.get("subtasks", []):
            if q in (st.get("title") or "").lower():
                return True
        return False

    # ---- CRUD --------------------------------------------------------------

    def add_task(
        self,
        title: str,
        priority=None,
        deadline=None,
        category=None,
        notes=None,
        subtasks=None,
        blocked_by=None,
        session_id=None,
    ) -> dict:
        if not title or not title.strip():
            raise ValueError("Title is required")
        if priority and priority not in VALID_PRIORITIES:
            raise ValueError(f"Invalid priority: {priority}")
        if deadline:
            try:
                date.fromisoformat(deadline)
            except ValueError:
                raise ValueError(f"Invalid deadline format: {deadline} (expected YYYY-MM-DD)")

        with FileLock():
            data = self.load_tasks()
            task_id = data["next_id"]
            data["next_id"] += 1

            subtask_list = []
            if subtasks:
                for st_title in subtasks:
                    if isinstance(st_title, str) and st_title.strip():
                        subtask_list.append({"title": st_title.strip(), "status": "todo"})

            task = {
                "id": task_id,
                "title": title.strip(),
                "status": "todo",
                "priority": priority,
                "deadline": deadline,
                "category": category,
                "created": _today(),
                "notes": notes,
                "subtasks": subtask_list,
                "blocked_by": blocked_by or [],
                "session_created": session_id,
                "session_completed": None,
            }

            # If blocked_by is set, auto-mark as blocked
            if task["blocked_by"]:
                task["status"] = "blocked"

            data["tasks"].append(task)
            _write_json(TASKS_FILE, data)

        return task

    def update_task(self, task_id: int, **fields) -> dict:
        with FileLock():
            data = self.load_tasks()
            task = next((t for t in data["tasks"] if t["id"] == task_id), None)
            if task is None:
                raise KeyError(f"Task #{task_id} not found")

            allowed = {"title", "status", "priority", "deadline", "category", "notes", "session_completed"}
            for k, v in fields.items():
                if k not in allowed:
                    continue
                if k == "status" and v not in VALID_STATUSES:
                    raise ValueError(f"Invalid status: {v}")
                if k == "priority" and v is not None and v not in VALID_PRIORITIES:
                    raise ValueError(f"Invalid priority: {v}")
                if k == "deadline" and v:
                    try:
                        date.fromisoformat(v)
                    except ValueError:
                        raise ValueError(f"Invalid deadline: {v}")
                task[k] = v

            _write_json(TASKS_FILE, data)

        return task

    def complete_task(self, task_ids: list, session_id=None) -> list:
        """Mark tasks done and archive them to history."""
        completed = []
        with FileLock():
            data = self.load_tasks()
            history = self.load_history()

            remaining = []
            for task in data["tasks"]:
                if task["id"] in task_ids:
                    task["status"] = "done"
                    task["session_completed"] = session_id
                    archived = dict(task)
                    archived["completed_on"] = _today()
                    history["tasks"].append(archived)
                    completed.append(task)
                else:
                    remaining.append(task)

            data["tasks"] = remaining
            _write_json(TASKS_FILE, data)
            self.save_history(history)

        # After completing, unblock any tasks waiting on these
        for tid in task_ids:
            self.on_task_completed(tid)

        return completed

    def delete_task(self, task_ids: list) -> list:
        deleted = []
        with FileLock():
            data = self.load_tasks()
            remaining = []
            for task in data["tasks"]:
                if task["id"] in task_ids:
                    deleted.append(task["id"])
                else:
                    remaining.append(task)
            data["tasks"] = remaining
            _write_json(TASKS_FILE, data)
        return deleted

    def search_tasks(self, query: str) -> list:
        return self.list_tasks(search=query)

    # ---- subtasks ----------------------------------------------------------

    def add_subtask(self, task_id: int, title: str) -> dict:
        with FileLock():
            data = self.load_tasks()
            task = next((t for t in data["tasks"] if t["id"] == task_id), None)
            if task is None:
                raise KeyError(f"Task #{task_id} not found")
            task.setdefault("subtasks", []).append({"title": title.strip(), "status": "todo"})
            _write_json(TASKS_FILE, data)
        return task

    def complete_subtask(self, task_id: int, index: int) -> dict:
        with FileLock():
            data = self.load_tasks()
            task = next((t for t in data["tasks"] if t["id"] == task_id), None)
            if task is None:
                raise KeyError(f"Task #{task_id} not found")
            subtasks = task.get("subtasks", [])
            if index < 0 or index >= len(subtasks):
                raise IndexError(f"Subtask index {index} out of range (task has {len(subtasks)} subtasks)")
            subtasks[index]["status"] = "done"
            _write_json(TASKS_FILE, data)
        return task

    # ---- views -------------------------------------------------------------

    def today_tasks(self) -> list:
        data = self.load_tasks()
        today = _today()
        result = []
        for task in data["tasks"]:
            if task.get("status") in ("done", "blocked"):
                continue
            deadline = task.get("deadline")
            if deadline and deadline <= today:
                result.append(task)
            elif task.get("priority") == "high" and not deadline:
                result.append(task)
        # Sort: overdue first, then due today, then high-priority no deadline
        def sort_key(t):
            d = t.get("deadline")
            if d and d < today:
                return (0, d)
            if d == today:
                return (1, "")
            return (2, "")
        result.sort(key=sort_key)
        return result

    def due_tasks(self) -> list:
        data = self.load_tasks()
        tasks = [t for t in data["tasks"] if t.get("deadline") and t.get("status") not in ("done",)]
        tasks.sort(key=lambda t: t["deadline"])
        return tasks

    def history_tasks(self, search=None, limit=20) -> list:
        history = self.load_history()
        tasks = history.get("tasks", [])
        if search:
            q = search.lower()
            tasks = [t for t in tasks if self._matches_search(t, q)]
        # Most recent first
        tasks = list(reversed(tasks))
        return tasks[:limit]

    # ---- pins / focus / goals ----------------------------------------------

    def pin_task(self, task_id: int) -> dict:
        task = self.find_task(task_id)
        if task is None:
            raise KeyError(f"Task #{task_id} not found")
        pins = self.load_pins()
        if task_id not in pins["pinned"]:
            pins["pinned"].append(task_id)
        self.save_pins(pins)
        return pins

    def unpin_task(self, task_id: int) -> dict:
        pins = self.load_pins()
        pins["pinned"] = [i for i in pins["pinned"] if i != task_id]
        self.save_pins(pins)
        return pins

    def get_pins(self) -> list:
        pins = self.load_pins()
        resolved = []
        data = self.load_tasks()
        task_map = {t["id"]: t for t in data["tasks"]}
        for tid in pins.get("pinned", []):
            if tid in task_map:
                resolved.append(task_map[tid])
        return resolved

    def set_focus(self, task_id: int) -> dict:
        task = self.find_task(task_id)
        if task is None:
            raise KeyError(f"Task #{task_id} not found")
        pins = self.load_pins()
        pins["focus"] = {
            "task_id": task_id,
            "started_at": _now_ts(),
            "elapsed_seconds": 0,
        }
        self.save_pins(pins)
        return pins

    def clear_focus(self) -> dict:
        pins = self.load_pins()
        # Only accumulate on a LIVE focus. started_at is never reset, so a repeat
        # clear would re-add the whole span again and inflate the total.
        if pins.get("focus") and pins["focus"].get("active", True):
            elapsed = _now_ts() - pins["focus"].get("started_at", _now_ts())
            pins["focus"]["elapsed_seconds"] = pins["focus"].get("elapsed_seconds", 0) + elapsed
            pins["focus"]["stopped_at"] = _now_ts()
            # Keep record but mark cleared
            pins["focus"]["active"] = False
        else:
            pins["focus"] = None
        self.save_pins(pins)
        return pins

    def set_goals(self, task_ids: list) -> dict:
        # Validate tasks exist
        for tid in task_ids:
            if self.find_task(tid) is None:
                raise KeyError(f"Task #{tid} not found")
        pins = self.load_pins()
        pins["session_goals"] = task_ids
        self.save_pins(pins)
        return pins

    def get_status(self) -> dict:
        pins = self.load_pins()
        data = self.load_tasks()
        task_map = {t["id"]: t for t in data["tasks"]}

        # Focus info
        focus_info = None
        # A cleared focus keeps its row for the time record but must not display.
        # clear_focus() only sets active=False, so existence is NOT the test.
        if pins.get("focus") and pins["focus"].get("active", True):
            f = pins["focus"]
            tid = f["task_id"]
            task = task_map.get(tid)
            elapsed = f.get("elapsed_seconds", 0)
            if f.get("active", True) and "started_at" in f:
                elapsed += _now_ts() - f["started_at"]
            focus_info = {
                "task_id": tid,
                "title": task["title"] if task else f"[deleted #{tid}]",
                "elapsed_seconds": int(elapsed),
                "elapsed_str": _elapsed_str(elapsed),
            }

        # Goals progress
        goals = []
        for gid in pins.get("session_goals", []):
            t = task_map.get(gid)
            if t:
                goals.append({
                    "task_id": gid,
                    "title": t["title"],
                    "status": t.get("status", "todo"),
                    "done": t.get("status") == "done",
                })
            else:
                # Check history
                hist = self.load_history()
                hist_task = next((h for h in hist.get("tasks", []) if h["id"] == gid), None)
                if hist_task:
                    goals.append({
                        "task_id": gid,
                        "title": hist_task["title"],
                        "status": "done",
                        "done": True,
                    })

        goals_done = sum(1 for g in goals if g["done"])

        # Velocity
        velocity = pins.get("velocity", {}).get("sessions", [])
        recent_velocity = velocity[-7:] if velocity else []
        avg_completed = (
            sum(s.get("completed", 0) for s in recent_velocity) / len(recent_velocity)
            if recent_velocity else 0
        )

        return {
            "focus": focus_info,
            "goals": goals,
            "goals_total": len(goals),
            "goals_done": goals_done,
            "pin_count": len(pins.get("pinned", [])),
            "velocity_avg": round(avg_completed, 1),
            "velocity_sessions": len(recent_velocity),
        }

    # ---- smart suggestions -------------------------------------------------

    def suggest_next(self, count=3) -> list:
        data = self.load_tasks()
        today = date.today()

        candidates = [
            t for t in data["tasks"]
            if t.get("status") not in ("done",)
        ]

        scored = []
        for task in candidates:
            score = self._score_task(task, today)
            scored.append((score, task))

        scored.sort(key=lambda x: x[0], reverse=True)

        results = []
        for score, task in scored[:count]:
            reasons = self._score_reasons(task, today)
            results.append({
                "task": task,
                "score": round(score, 2),
                "reasons": reasons,
            })

        return results

    def _score_task(self, task: dict, today: date) -> float:
        # Deadline urgency (0-10)
        deadline = task.get("deadline")
        if not deadline:
            deadline_urgency = 3.0
        else:
            days = (date.fromisoformat(deadline) - today).days
            if days < 0:
                deadline_urgency = 10.0
            else:
                deadline_urgency = 10.0 * math.exp(-days / 7.0)

        # Priority weight (0-10)
        priority_weight = PRIORITY_WEIGHT.get(task.get("priority"), 1)

        # Staleness
        try:
            created = date.fromisoformat(task.get("created", str(today)))
            days_old = (today - created).days
        except ValueError:
            days_old = 0
        staleness = min(days_old / 7.0, 10.0)

        # Blocker clear
        blockers = task.get("blocked_by", [])
        blockers_clear = 0.0 if blockers else 10.0

        # Subtask momentum
        subtasks = task.get("subtasks", [])
        if subtasks:
            done_count = sum(1 for s in subtasks if s.get("status") == "done")
            subtask_momentum = (done_count / len(subtasks)) * 10.0
        else:
            subtask_momentum = 0.0

        return (
            deadline_urgency * 3.0
            + priority_weight * 2.5
            + staleness * 1.5
            + blockers_clear * 2.0
            + subtask_momentum * 1.0
        )

    def _score_reasons(self, task: dict, today: date) -> list:
        reasons = []
        deadline = task.get("deadline")
        if deadline:
            days = (date.fromisoformat(deadline) - today).days
            if days < 0:
                reasons.append(f"OVERDUE by {abs(days)}d")
            elif days == 0:
                reasons.append("due TODAY")
            elif days <= 3:
                reasons.append(f"due in {days}d")
        if task.get("priority") == "high":
            reasons.append("high priority")
        if task.get("blocked_by"):
            reasons.append("⚠ blocked")
        subtasks = task.get("subtasks", [])
        if subtasks:
            done = sum(1 for s in subtasks if s.get("status") == "done")
            if done > 0:
                reasons.append(f"momentum ({done}/{len(subtasks)} subtasks done)")
        return reasons

    # ---- blockers ----------------------------------------------------------

    def add_blocker(self, task_id: int, blocker_id: int) -> dict:
        if self.find_task(blocker_id) is None:
            raise KeyError(f"Blocker task #{blocker_id} not found")
        with FileLock():
            data = self.load_tasks()
            task = next((t for t in data["tasks"] if t["id"] == task_id), None)
            if task is None:
                raise KeyError(f"Task #{task_id} not found")
            task.setdefault("blocked_by", [])
            if blocker_id not in task["blocked_by"]:
                task["blocked_by"].append(blocker_id)
            if task["blocked_by"]:
                task["status"] = "blocked"
            _write_json(TASKS_FILE, data)
        return task

    def remove_blocker(self, task_id: int, blocker_id: int) -> dict:
        with FileLock():
            data = self.load_tasks()
            task = next((t for t in data["tasks"] if t["id"] == task_id), None)
            if task is None:
                raise KeyError(f"Task #{task_id} not found")
            task["blocked_by"] = [b for b in task.get("blocked_by", []) if b != blocker_id]
            # If no more blockers and status is blocked, revert to todo
            if not task["blocked_by"] and task.get("status") == "blocked":
                task["status"] = "todo"
            _write_json(TASKS_FILE, data)
        return task

    def on_task_completed(self, task_id: int):
        """When a task is completed, unblock any task waiting on it."""
        with FileLock():
            data = self.load_tasks()
            changed = False
            for task in data["tasks"]:
                blockers = task.get("blocked_by", [])
                if task_id in blockers:
                    task["blocked_by"] = [b for b in blockers if b != task_id]
                    if not task["blocked_by"] and task.get("status") == "blocked":
                        task["status"] = "todo"
                        _log(f"Task #{task['id']} unblocked by completion of #{task_id}")
                    changed = True
            if changed:
                _write_json(TASKS_FILE, data)


