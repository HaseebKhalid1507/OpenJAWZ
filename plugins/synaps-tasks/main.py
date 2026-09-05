#!/usr/bin/env python3
"""
main.py — synaps-tasks plugin entry point.
JSON-RPC 2.0 over stdio with LSP-style Content-Length framing.
"""

import json
import os
import sys
from datetime import date
from tasks_engine import TaskEngine, _today, _elapsed_str, _now_ts

# ---------------------------------------------------------------------------
# Tool definitions
# ---------------------------------------------------------------------------

TOOLS = [
    {
        "name": "tasks_list",
        "description": "List tasks with optional filters. Returns active tasks.",
        "input_schema": {
            "type": "object",
            "properties": {
                "status": {"type": "string", "enum": ["todo", "in-progress", "done", "blocked"], "description": "Filter by status"},
                "priority": {"type": "string", "enum": ["high", "medium", "low"], "description": "Filter by priority"},
                "category": {"type": "string", "description": "Filter by category"},
                "search": {"type": "string", "description": "Full-text search query"},
                "sort": {"type": "string", "enum": ["created", "deadline", "priority"], "description": "Sort order"}
            }
        }
    },
    {
        "name": "tasks_add",
        "description": "Create a new task.",
        "input_schema": {
            "type": "object",
            "properties": {
                "title": {"type": "string", "description": "Task title"},
                "priority": {"type": "string", "enum": ["high", "medium", "low"], "description": "Priority level"},
                "deadline": {"type": "string", "description": "Deadline in YYYY-MM-DD format"},
                "category": {"type": "string", "description": "Category (work, personal, school, infra, startup, synaps-cli, etc.)"},
                "notes": {"type": "string", "description": "Additional notes"},
                "subtasks": {"type": "array", "items": {"type": "string"}, "description": "List of subtask titles"},
                "blocked_by": {"type": "array", "items": {"type": "integer"}, "description": "Task IDs that block this task"}
            },
            "required": ["title"]
        }
    },
    {
        "name": "tasks_update",
        "description": "Update fields on an existing task.",
        "input_schema": {
            "type": "object",
            "properties": {
                "task_id": {"type": "integer", "description": "Task ID to update"},
                "title": {"type": "string"},
                "status": {"type": "string", "enum": ["todo", "in-progress", "done", "blocked"]},
                "priority": {"type": "string", "enum": ["high", "medium", "low"]},
                "deadline": {"type": "string", "description": "YYYY-MM-DD or null to clear"},
                "category": {"type": "string"},
                "notes": {"type": "string"}
            },
            "required": ["task_id"]
        }
    },
    {
        "name": "tasks_done",
        "description": "Mark one or more tasks as done and archive them.",
        "input_schema": {
            "type": "object",
            "properties": {
                "task_ids": {"type": "array", "items": {"type": "integer"}, "description": "Task ID(s) to complete"}
            },
            "required": ["task_ids"]
        }
    },
    {
        "name": "tasks_delete",
        "description": "Delete one or more tasks permanently.",
        "input_schema": {
            "type": "object",
            "properties": {
                "task_ids": {"type": "array", "items": {"type": "integer"}, "description": "Task ID(s) to delete"}
            },
            "required": ["task_ids"]
        }
    },
    {
        "name": "tasks_search",
        "description": "Search tasks by text across titles, notes, and subtasks.",
        "input_schema": {
            "type": "object",
            "properties": {
                "query": {"type": "string", "description": "Search query"}
            },
            "required": ["query"]
        }
    },
    {
        "name": "tasks_subtask_add",
        "description": "Add a subtask to an existing task.",
        "input_schema": {
            "type": "object",
            "properties": {
                "task_id": {"type": "integer", "description": "Parent task ID"},
                "title": {"type": "string", "description": "Subtask title"}
            },
            "required": ["task_id", "title"]
        }
    },
    {
        "name": "tasks_subtask_done",
        "description": "Mark a subtask as done by index (0-based).",
        "input_schema": {
            "type": "object",
            "properties": {
                "task_id": {"type": "integer", "description": "Parent task ID"},
                "index": {"type": "integer", "description": "Subtask index (0-based)"}
            },
            "required": ["task_id", "index"]
        }
    },
    {
        "name": "tasks_today",
        "description": "Show today's tasks: due today, overdue, and high-priority tasks without deadlines. Excludes done/blocked.",
        "input_schema": {"type": "object", "properties": {}}
    },
    {
        "name": "tasks_due",
        "description": "Show all tasks with deadlines, sorted by urgency.",
        "input_schema": {"type": "object", "properties": {}}
    },
    {
        "name": "tasks_history",
        "description": "Query completed/archived tasks.",
        "input_schema": {
            "type": "object",
            "properties": {
                "search": {"type": "string", "description": "Search within archived tasks"},
                "limit": {"type": "integer", "description": "Max results (default 20)"}
            }
        }
    },
    {
        "name": "tasks_pin",
        "description": "Pin a task for context injection. Pinned tasks are injected into every LLM turn so the model stays aware of them.",
        "input_schema": {
            "type": "object",
            "properties": {
                "task_id": {"type": "integer", "description": "Task ID to pin"}
            },
            "required": ["task_id"]
        }
    },
    {
        "name": "tasks_unpin",
        "description": "Unpin a task, removing it from context injection.",
        "input_schema": {
            "type": "object",
            "properties": {
                "task_id": {"type": "integer", "description": "Task ID to unpin"}
            },
            "required": ["task_id"]
        }
    },
    {
        "name": "tasks_pins",
        "description": "List all currently pinned tasks with their details.",
        "input_schema": {"type": "object", "properties": {}}
    },
    {
        "name": "tasks_focus",
        "description": "Set the current focus task. The focus task gets prominent context injection and tracks elapsed working time. Only one task can be focused at a time.",
        "input_schema": {
            "type": "object",
            "properties": {
                "task_id": {"type": "integer", "description": "Task ID to focus on"}
            },
            "required": ["task_id"]
        }
    },
    {
        "name": "tasks_unfocus",
        "description": "Clear the current focus task and stop time tracking.",
        "input_schema": {"type": "object", "properties": {}}
    },
    {
        "name": "tasks_goals",
        "description": "Set session goals — 1-3 tasks you intend to complete or make progress on this session. Progress is scored at session end.",
        "input_schema": {
            "type": "object",
            "properties": {
                "task_ids": {"type": "array", "items": {"type": "integer"}, "description": "1-3 task IDs as session goals", "maxItems": 3}
            },
            "required": ["task_ids"]
        }
    },
    {
        "name": "tasks_status",
        "description": "Dashboard showing current focus, session goals progress, pinned count, and task velocity.",
        "input_schema": {"type": "object", "properties": {}}
    },
    {
        "name": "tasks_next",
        "description": "Get smart suggestions for the top tasks to work on next, scored by deadline urgency, priority, staleness, and blocker status.",
        "input_schema": {
            "type": "object",
            "properties": {
                "count": {"type": "integer", "description": "Number of suggestions (default 3)", "default": 3}
            }
        }
    },
    {
        "name": "tasks_block",
        "description": "Declare that a task is blocked by another task. When the blocker is completed, the blocked task auto-transitions from blocked to todo.",
        "input_schema": {
            "type": "object",
            "properties": {
                "task_id": {"type": "integer", "description": "Task that is blocked"},
                "blocker_id": {"type": "integer", "description": "Task that is blocking it"}
            },
            "required": ["task_id", "blocker_id"]
        }
    },
    {
        "name": "tasks_unblock",
        "description": "Remove a blocker relationship between tasks.",
        "input_schema": {
            "type": "object",
            "properties": {
                "task_id": {"type": "integer", "description": "Task to unblock"},
                "blocker_id": {"type": "integer", "description": "Blocker to remove"}
            },
            "required": ["task_id", "blocker_id"]
        }
    }
]

# ---------------------------------------------------------------------------
# Formatting helpers
# ---------------------------------------------------------------------------

def _fmt_task(task: dict, today: str = None) -> str:
    """Format a single task into a compact, readable string."""
    if today is None:
        today = _today()

    tid = task.get("id", "?")
    title = task.get("title", "(untitled)")
    priority = task.get("priority", "")
    deadline = task.get("deadline", "")
    status = task.get("status", "todo")
    category = task.get("category", "")
    created = task.get("created", "")
    subtasks = task.get("subtasks", [])
    notes = task.get("notes", "")
    blocked_by = task.get("blocked_by", [])

    # Header line
    meta_parts = []
    if priority:
        meta_parts.append(priority)
    if deadline:
        if deadline < today:
            meta_parts.append(f"due: {deadline} ⚠️ OVERDUE")
        elif deadline == today:
            meta_parts.append("due: today!")
        else:
            meta_parts.append(f"due: {deadline}")
    meta = " | ".join(meta_parts)
    header = f"[#{tid}] {title}"
    if meta:
        header += f" ({meta})"

    lines = [header]

    # Status line
    detail_parts = [f"Status: {status}"]
    if category:
        detail_parts.append(f"Category: {category}")
    if created:
        detail_parts.append(f"Created: {created}")
    lines.append(f"  {' | '.join(detail_parts)}")

    if notes:
        lines.append(f"  Notes: {notes}")

    if subtasks:
        done_count = sum(1 for s in subtasks if s.get("status") == "done")
        lines.append(f"  Subtasks: {done_count}/{len(subtasks)} done")
        for i, st in enumerate(subtasks):
            mark = "✓" if st.get("status") == "done" else "○"
            lines.append(f"    {i}. [{mark}] {st.get('title', '')}")

    if blocked_by:
        lines.append(f"  Blocked by: {', '.join(f'#{b}' for b in blocked_by)}")

    return "\n".join(lines)


def _fmt_task_list(tasks: list, header: str = None) -> str:
    if not tasks:
        return "No tasks found."

    parts = []
    if header:
        parts.append(header)
    today = _today()
    for task in tasks:
        parts.append(_fmt_task(task, today))
        parts.append("")  # blank line between tasks

    # Remove trailing blank
    if parts and parts[-1] == "":
        parts.pop()

    return "\n".join(parts)


def _fmt_status(status: dict) -> str:
    lines = []

    focus = status.get("focus")
    if focus:
        lines.append(f"🎯 Focus: [#{focus['task_id']}] {focus['title']} — {focus['elapsed_str']} elapsed")
    else:
        lines.append("🎯 Focus: none")

    goals = status.get("goals", [])
    goals_done = status.get("goals_done", 0)
    goals_total = status.get("goals_total", 0)
    if goals:
        lines.append(f"\n📊 Session Goals: {goals_done}/{goals_total} complete")
        for g in goals:
            mark = "✓" if g["done"] else "○"
            lines.append(f"  [{mark}] [#{g['task_id']}] {g['title']}")
    else:
        lines.append("\n📊 Session Goals: none set")

    pin_count = status.get("pin_count", 0)
    lines.append(f"\n📌 Pinned tasks: {pin_count}")

    v_avg = status.get("velocity_avg", 0)
    v_sessions = status.get("velocity_sessions", 0)
    if v_sessions > 0:
        lines.append(f"\n⚡ Velocity: ~{v_avg} tasks/session (last {v_sessions} sessions)")

    return "\n".join(lines)


def _fmt_suggestions(suggestions: list) -> str:
    if not suggestions:
        return "No suggestions — all tasks are blocked or done."

    lines = ["Top tasks to work on next:\n"]
    today = _today()
    for i, item in enumerate(suggestions, 1):
        task = item["task"]
        score = item["score"]
        reasons = item.get("reasons", [])
        reasons_str = ", ".join(reasons) if reasons else "no special urgency"
        lines.append(f"{i}. [#{task['id']}] {task['title']}")
        lines.append(f"   Score: {score:.1f} — {reasons_str}")
        lines.append("")

    return "\n".join(lines).rstrip()


def _fmt_pins_block(pinned_tasks: list, focus_info: dict, goals_info: dict) -> str:
    """Format the context injection block for before_message."""
    parts = []

    if pinned_tasks:
        parts.append("📌 Pinned Tasks:")
        today = _today()
        for task in pinned_tasks:
            tid = task["id"]
            title = task["title"]
            meta_parts = []
            if task.get("priority"):
                meta_parts.append(task["priority"])
            deadline = task.get("deadline", "")
            if deadline:
                if deadline < today:
                    meta_parts.append(f"due {deadline} ⚠️ OVERDUE")
                elif deadline == today:
                    meta_parts.append("due today!")
                else:
                    meta_parts.append(f"due {deadline}")
            meta = ", ".join(meta_parts)
            line = f"- [#{tid}] {title}"
            if meta:
                line += f" ({meta})"
            parts.append(line)

    if focus_info:
        if parts:
            parts.append("")
        parts.append(f"🎯 Focus: [#{focus_info['task_id']}] {focus_info['title']} — {focus_info['elapsed_str']} elapsed")

    goals = goals_info.get("goals", [])
    if goals:
        if parts:
            parts.append("")
        done = goals_info.get("goals_done", 0)
        total = goals_info.get("goals_total", 0)
        parts.append(f"📊 Session Goals: {done}/{total} complete")

    return "\n".join(parts)


# ---------------------------------------------------------------------------
# JSON-RPC transport
# ---------------------------------------------------------------------------

def _read_message() -> dict | None:
    """Read one Content-Length framed JSON-RPC message from stdin."""
    try:
        header = b""
        while True:
            ch = sys.stdin.buffer.read(1)
            if not ch:
                return None
            header += ch
            if header.endswith(b"\r\n\r\n"):
                break

        length = None
        for line in header.split(b"\r\n"):
            if line.lower().startswith(b"content-length:"):
                length = int(line.split(b":", 1)[1].strip())
                break

        if length is None:
            return None

        body = sys.stdin.buffer.read(length)
        return json.loads(body.decode("utf-8"))
    except Exception as e:
        _log(f"read_message error: {e}")
        return None


def _send_message(obj: dict):
    """Write one Content-Length framed JSON-RPC message to stdout."""
    body = json.dumps(obj, ensure_ascii=False).encode("utf-8")
    header = f"Content-Length: {len(body)}\r\n\r\n".encode("utf-8")
    sys.stdout.buffer.write(header + body)
    sys.stdout.buffer.flush()


def _log(msg: str):
    print(f"[synaps-tasks] {msg}", file=sys.stderr, flush=True)


def _ok(req_id, result):
    _send_message({"jsonrpc": "2.0", "id": req_id, "result": result})


def _err(req_id, code: int, message: str):
    _send_message({
        "jsonrpc": "2.0",
        "id": req_id,
        "error": {"code": code, "message": message}
    })


# ---------------------------------------------------------------------------
# Tool dispatch
# ---------------------------------------------------------------------------

def dispatch_tool(name: str, inp: dict) -> str:
    engine = TaskEngine()
    today = _today()

    if name == "tasks_list":
        tasks = engine.list_tasks(
            status=inp.get("status"),
            priority=inp.get("priority"),
            category=inp.get("category"),
            search=inp.get("search"),
            sort=inp.get("sort"),
        )
        count_str = f"Found {len(tasks)} task{'s' if len(tasks) != 1 else ''}:"
        return _fmt_task_list(tasks, header=count_str)

    elif name == "tasks_add":
        subtasks = inp.get("subtasks")
        task = engine.add_task(
            title=inp["title"],
            priority=inp.get("priority"),
            deadline=inp.get("deadline"),
            category=inp.get("category"),
            notes=inp.get("notes"),
            subtasks=subtasks,
            blocked_by=inp.get("blocked_by"),
        )
        return f"Created task #{task['id']}:\n\n" + _fmt_task(task, today)

    elif name == "tasks_update":
        task_id = int(inp["task_id"])
        fields = {k: v for k, v in inp.items() if k != "task_id"}
        task = engine.update_task(task_id, **fields)
        return f"Updated task #{task_id}:\n\n" + _fmt_task(task, today)

    elif name == "tasks_done":
        task_ids = [int(i) for i in inp["task_ids"]]
        completed = engine.complete_task(task_ids)
        if not completed:
            return f"No tasks found matching IDs: {task_ids}"
        lines = [f"Completed {len(completed)} task{'s' if len(completed) != 1 else ''}:"]
        for t in completed:
            lines.append(f"  ✓ [#{t['id']}] {t['title']}")
        return "\n".join(lines)

    elif name == "tasks_delete":
        task_ids = [int(i) for i in inp["task_ids"]]
        deleted = engine.delete_task(task_ids)
        if not deleted:
            return f"No tasks found matching IDs: {task_ids}"
        return f"Deleted {len(deleted)} task{'s' if len(deleted) != 1 else ''}: {', '.join(f'#{i}' for i in deleted)}"

    elif name == "tasks_search":
        tasks = engine.search_tasks(inp["query"])
        return _fmt_task_list(tasks, header=f"Search results for '{inp['query']}' ({len(tasks)} found):")

    elif name == "tasks_subtask_add":
        task = engine.add_subtask(int(inp["task_id"]), inp["title"])
        return f"Added subtask to #{task['id']}:\n\n" + _fmt_task(task, today)

    elif name == "tasks_subtask_done":
        task = engine.complete_subtask(int(inp["task_id"]), int(inp["index"]))
        subtasks = task.get("subtasks", [])
        done = sum(1 for s in subtasks if s.get("status") == "done")
        return (
            f"Subtask {inp['index']} marked done on #{task['id']} — "
            f"{done}/{len(subtasks)} subtasks complete.\n\n"
            + _fmt_task(task, today)
        )

    elif name == "tasks_today":
        tasks = engine.today_tasks()
        if not tasks:
            return "Nothing pressing today. Clear skies."
        return _fmt_task_list(tasks, header=f"Today's tasks ({len(tasks)}):")

    elif name == "tasks_due":
        tasks = engine.due_tasks()
        return _fmt_task_list(tasks, header=f"All tasks with deadlines ({len(tasks)}):")

    elif name == "tasks_history":
        limit = int(inp.get("limit", 20))
        tasks = engine.history_tasks(search=inp.get("search"), limit=limit)
        if not tasks:
            return "No archived tasks found."
        lines = [f"Archived tasks ({len(tasks)} shown):"]
        for t in tasks:
            completed_on = t.get("completed_on", "?")
            tid = t.get("id", "?")
            title = t.get("title", "(untitled)")
            cat = t.get("category", "")
            lines.append(f"  [#{tid}] {title} — completed {completed_on}" + (f" | {cat}" if cat else ""))
        return "\n".join(lines)

    elif name == "tasks_pin":
        engine.pin_task(int(inp["task_id"]))
        task = engine.find_task(int(inp["task_id"]))
        return f"📌 Pinned [#{inp['task_id']}] {task['title'] if task else '(task)'}. It will now appear in every session context."

    elif name == "tasks_unpin":
        engine.unpin_task(int(inp["task_id"]))
        return f"Unpinned #{inp['task_id']}."

    elif name == "tasks_pins":
        pinned = engine.get_pins()
        if not pinned:
            return "No tasks pinned."
        return _fmt_task_list(pinned, header=f"Pinned tasks ({len(pinned)}):")

    elif name == "tasks_focus":
        task_id = int(inp["task_id"])
        engine.set_focus(task_id)
        task = engine.find_task(task_id)
        return f"🎯 Focus set to [#{task_id}] {task['title'] if task else '(task)'}. Timer started."

    elif name == "tasks_unfocus":
        pins = engine.clear_focus()
        focus = pins.get("focus")
        if focus and not focus.get("active", True):
            elapsed = focus.get("elapsed_seconds", 0)
            return f"Focus cleared. Total time tracked: {_elapsed_str(elapsed)}."
        return "Focus cleared."

    elif name == "tasks_goals":
        task_ids = [int(i) for i in inp["task_ids"]]
        engine.set_goals(task_ids)
        lines = [f"Session goals set ({len(task_ids)}):"]
        for tid in task_ids:
            task = engine.find_task(tid)
            lines.append(f"  ○ [#{tid}] {task['title'] if task else '(not found)'}")
        return "\n".join(lines)

    elif name == "tasks_status":
        status = engine.get_status()
        return _fmt_status(status)

    elif name == "tasks_next":
        count = int(inp.get("count", 3))
        suggestions = engine.suggest_next(count=count)
        return _fmt_suggestions(suggestions)

    elif name == "tasks_block":
        task = engine.add_blocker(int(inp["task_id"]), int(inp["blocker_id"]))
        return f"[#{inp['task_id']}] {task['title']} is now blocked by #{inp['blocker_id']}. Status set to blocked."

    elif name == "tasks_unblock":
        task = engine.remove_blocker(int(inp["task_id"]), int(inp["blocker_id"]))
        return (
            f"Removed blocker #{inp['blocker_id']} from [#{inp['task_id']}] {task['title']}. "
            + (f"Status: {task['status']}." if task.get("blocked_by") else "Task is now unblocked (todo).")
        )

    else:
        raise ValueError(f"Unknown tool: {name}")


# ---------------------------------------------------------------------------
# Hook handlers
# ---------------------------------------------------------------------------

def handle_before_message(params: dict) -> dict:
    try:
        engine = TaskEngine()
        status = engine.get_status()

        pinned_tasks = engine.get_pins()
        focus = status.get("focus")
        goals_info = {
            "goals": status.get("goals", []),
            "goals_done": status.get("goals_done", 0),
            "goals_total": status.get("goals_total", 0),
        }

        if not pinned_tasks and not focus and not goals_info["goals"]:
            return {"action": "continue"}

        content = _fmt_pins_block(pinned_tasks, focus, goals_info)
        if content.strip():
            return {"action": "inject", "content": content}

    except Exception as e:
        _log(f"before_message error: {e}")

    return {"action": "continue"}


def handle_session_start(params: dict) -> dict:
    try:
        engine = TaskEngine()
        pins = engine.load_pins()
        pins["session_start"] = _now_ts()
        engine.save_pins(pins)
        _log("Session started, timestamp recorded.")
    except Exception as e:
        _log(f"on_session_start error: {e}")
    return {"action": "continue"}


def handle_session_end(params: dict) -> dict:
    try:
        engine = TaskEngine()
        pins = engine.load_pins()
        session_id = params.get("session_id")

        # Score goals
        goals = pins.get("session_goals", [])
        completed_goals = 0
        if goals:
            data = engine.load_tasks()
            task_map = {t["id"]: t for t in data["tasks"]}
            history = engine.load_history()
            hist_ids = {t["id"] for t in history.get("tasks", [])}
            for gid in goals:
                # Done if in history (completed this session) or status == done in active
                if gid in hist_ids:
                    completed_goals += 1
                elif gid in task_map and task_map[gid].get("status") == "done":
                    completed_goals += 1

        # Record velocity
        velocity = pins.setdefault("velocity", {"sessions": []})
        sessions = velocity.setdefault("sessions", [])
        sessions.append({
            "session_id": session_id,
            "timestamp": _now_ts(),
            "goals_set": len(goals),
            "goals_completed": completed_goals,
            "completed": completed_goals,
        })
        # Keep last 30 sessions
        velocity["sessions"] = sessions[-30:]

        # Clear active focus timer (preserve elapsed data)
        if pins.get("focus") and pins["focus"].get("active", True):
            started_at = pins["focus"].get("started_at", _now_ts())
            elapsed = _now_ts() - started_at
            pins["focus"]["elapsed_seconds"] = pins["focus"].get("elapsed_seconds", 0) + elapsed
            pins["focus"]["active"] = False

        engine.save_pins(pins)
        _log(f"Session ended. Goals: {completed_goals}/{len(goals)}.")
    except Exception as e:
        _log(f"on_session_end error: {e}")
    return {"action": "continue"}


# ---------------------------------------------------------------------------
# Main loop
# ---------------------------------------------------------------------------

def main():
    _log("synaps-tasks plugin starting")

    while True:
        msg = _read_message()
        if msg is None:
            _log("stdin closed, shutting down")
            break

        req_id = msg.get("id")
        method = msg.get("method", "")
        params = msg.get("params", {})

        _log(f"→ {method} (id={req_id})")

        try:
            if method == "initialize":
                _ok(req_id, {
                    "protocol_version": 1,
                    "capabilities": {
                        "tools": TOOLS
                    }
                })

            elif method == "tool.call":
                tool_name = params.get("name", "")
                tool_input = params.get("input", {})
                try:
                    result_text = dispatch_tool(tool_name, tool_input)
                    _ok(req_id, {"content": result_text})
                except (KeyError, IndexError, ValueError) as e:
                    _err(req_id, -32602, str(e))
                except Exception as e:
                    _log(f"tool error: {e}")
                    _err(req_id, -32603, f"Internal error: {e}")

            elif method == "hook.handle":
                hook = params.get("kind", params.get("hook", ""))
                if hook == "before_message":
                    result = handle_before_message(params)
                elif hook == "on_session_start":
                    result = handle_session_start(params)
                elif hook == "on_session_end":
                    result = handle_session_end(params)
                else:
                    result = {"action": "continue"}
                _ok(req_id, result)

            elif method == "shutdown":
                _log("shutdown received")
                _ok(req_id, {})
                break

            else:
                _err(req_id, -32601, f"Method not found: {method}")

        except Exception as e:
            _log(f"unhandled error processing {method}: {e}")
            try:
                _err(req_id, -32603, f"Internal error: {e}")
            except Exception:
                pass


if __name__ == "__main__":
    main()
