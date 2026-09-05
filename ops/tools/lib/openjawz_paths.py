"""
openjawz_paths — the one place tools resolve where things live. stdlib only.

    OPENJAWZ_HOME  default $XDG_DATA_HOME/openjawz         (the engram)
    OPENJAWZ_DATA  default $OPENJAWZ_HOME/data            (tasks.json, *.db)
    context        $OPENJAWZ_HOME/context                 (active/, full/, people.md)
    OPENJAWZ_USER  from identity.env USER_NAME             (never a literal name in a tool)
"""
import os
from pathlib import Path

_XDG_DATA = Path(os.environ.get("XDG_DATA_HOME", Path.home() / ".local" / "share"))
_XDG_CONFIG = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config"))


def home() -> Path:
    return Path(os.environ.get("OPENJAWZ_HOME", _XDG_DATA / "openjawz"))


def data() -> Path:
    return Path(os.environ.get("OPENJAWZ_DATA", home() / "data"))


def context() -> Path:
    return home() / "context"


def config_dir() -> Path:
    return Path(os.environ.get("OPENJAWZ_CONFIG", _XDG_CONFIG / "openjawz"))


def identity() -> dict:
    """identity.env as a dict (empty if absent). Values are unquoted key=value lines."""
    out = {}
    try:
        for line in (config_dir() / "identity.env").read_text().splitlines():
            if "=" in line and not line.lstrip().startswith("#"):
                k, v = line.split("=", 1)
                out[k.strip()] = v.strip()
    except OSError:
        pass
    return out


def user_name() -> str:
    return os.environ.get("OPENJAWZ_USER") or identity().get("USER_NAME") or os.environ.get("USER", "user")


def agent_name() -> str:
    return os.environ.get("OPENJAWZ_AGENT_NAME") or identity().get("AGENT_NAME") or "the agent"


def no_color() -> bool:
    return bool(os.environ.get("NO_COLOR")) or not os.isatty(1)
