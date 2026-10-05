"""
db_profiles.py

Decides WHICH Postgres database a given report render runs against.

WHY THIS EXISTS
---------------
ZMRP lets each user switch between databases (and those databases can live
on different hosts/ports). Before this module, CrystalReportWrapper.exe
only ever saw one set of PG_HOST/PG_PORT/PG_DATABASE/PG_USER/PG_PASSWORD
values - the container's own environment - so a ZMRP user looking at the
test database would silently get a report rendered from whatever database
the container happened to be configured for. Nothing errored; the PDF just
showed the wrong company's data.

HOW IT WORKS
------------
The server owns a list of named connection profiles (config/db_profiles.json,
path overridable with RPTCONVERT_DB_PROFILES). Each profile is host / port /
database / user, plus the NAME of an environment variable holding its
password - passwords never go in the JSON file and never cross the network.

A caller picks a profile one of two ways:

    db_profile="live"                                  # by name
    db_target={"host": "johnaton", "port": 5430,
               "database": "zonu_live"}                # by what ZMRP is
                                                       # actually connected to

db_target is what ZMRP should normally send - straight off its SQLAlchemy
engine.url - so the two apps never have to agree on profile names. A
profile matches a target when database and port are equal and the target's
host is the profile's host or one of its "match_hosts" aliases (case-
insensitive). match_hosts exists because the hostname ZMRP uses to reach
Postgres (e.g. an IP, or "JOHNATON.corp.local") isn't always the same
string the container uses (e.g. "host.docker.internal").

FAIL CLOSED: a db_profile/db_target that doesn't resolve to exactly one
profile raises UnknownDatabaseError. It never falls back to the default -
falling back is precisely the wrong-database bug this module fixes.

Only when the caller sends NEITHER field is the "default" profile used
(built from the legacy PG_* environment variables), so an un-updated ZMRP
client keeps working exactly as before during the rollout. Set
RPTCONVERT_REQUIRE_DB=1 once every client sends a database, to turn that
fallback off too.

The resolved profile is handed to the C# worker as PG_* environment
variables on ITS subprocess only (see main.CrystalReportsPipeline) - not
argv (visible in any process listing) and not os.environ (shared across
every concurrent render thread). Program.cs already reads exactly those
variables, so the worker needed no change.

FILE FORMAT (config/db_profiles.json)
-------------------------------------
    {
      "live": {
        "host": "johnaton", "port": 5430, "database": "zonu_live",
        "user": "postgres", "password_env": "PG_PASSWORD_LIVE",
        "match_hosts": ["192.168.1.50", "localhost"]
      },
      "test": { ... }
    }

The file is re-read automatically when its modification time changes, so
adding a database doesn't need a container restart.
"""

from __future__ import annotations

import json
import os
import threading
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Mapping, Optional

def get_user_roaming_dir(app_name: str = "ManufacturingDatabase") -> Path:
    """Returns the per-user AppData/Roaming path for connection JSON storage."""
    appdata = os.getenv("APPDATA")
    if appdata:
        base_dir = Path(appdata) / app_name
    else:
        # Fallback for non-Windows environments
        base_dir = Path.home() / ".config" / app_name

    base_dir.mkdir(parents=True, exist_ok=True)
    return base_dir

ROAMING_DIR = get_user_roaming_dir()
PROJECT_ROOT = Path(__file__).parent
PROFILES_PATH = Path(os.environ.get(
    "RPTCONVERT_DB_PROFILES",
    str(ROAMING_DIR / "config" / "pg_config.json"),
))

DEFAULT_PROFILE_NAME = "default"


class UnknownDatabaseError(ValueError):
    """The requested database doesn't match any configured profile (or
    matches more than one). A ValueError subclass so report_api_server's
    existing ValueError -> HTTP 400 mapping covers it."""


@dataclass(frozen=True)
class DbProfile:
    name: str
    host: str
    port: int
    database: str
    user: str
    password_env: str
    match_hosts: tuple[str, ...] = field(default_factory=tuple)

    @property
    def password(self) -> str:
        """Read the password from the env variable named in the profile. Raises UnknownDatabaseError if database
        is unknown"""
        value = os.environ.get(self.password_env)
        if value is None:
            raise UnknownDatabaseError(
                f"Database profile '{self.name}' reads its password from the "
                f"{self.password_env} environment variable, which isn't set on "
                f"the report server - add it to .env and restart the container."
            )
        return value

    def worker_env(self) -> dict[str, str]:
        """The PG_* variables Program.cs reads, for this profile."""
        return {
            "PG_HOST": self.host,
            "PG_PORT": str(self.port),
            "PG_DATABASE": self.database,
            "PG_USER": self.user,
            "PG_PASSWORD": self.password,
        }

    def matches(self, host: str, port: int, database: str) -> bool:
        hosts = {self.host.lower(), *(h.lower() for h in self.match_hosts)}
        return (
            database == self.database           # Postgres DB names are case-sensitive
            and int(port) == self.port
            and host.strip().lower() in hosts
        )

    def describe(self) -> dict[str, Any]:
        """Safe-to-return summary (no password)."""
        return {"name": self.name, "host": self.host, "port": self.port,
                "database": self.database, "user": self.user}


def _default_profile() -> DbProfile:
    # Same variables/defaults Program.cs falls back to, so a request that
    # names no database behaves exactly like before this module existed.
    return DbProfile(
        name=DEFAULT_PROFILE_NAME,
        host=os.environ.get("PG_HOST", "127.0.0.1"),
        port=int(os.environ.get("PG_PORT", "5430")),
        database=os.environ.get("PG_DATABASE", "postgres"),
        user=os.environ.get("PG_USER", "postgres"),
        password_env="PG_PASSWORD",
    )


_cache_lock = threading.Lock()
_cache_mtime: Optional[float] = None
_cache_profiles: dict[str, DbProfile] = {}


def _parse_profiles(raw: Mapping[str, Any]) -> dict[str, DbProfile]:
    profiles: dict[str, DbProfile] = {}
    for name, cfg in raw.items():
        if name.startswith("_"):  # allow "_comment" keys
            continue
        try:
            profiles[name] = DbProfile(
                name=name,
                host=str(cfg["host"]),
                port=int(cfg.get("port", 5432)),
                database=str(cfg["database"]),
                user=str(cfg.get("user", "postgres")),
                password_env=str(cfg["password_env"]),
                match_hosts=tuple(str(h) for h in cfg.get("match_hosts", [])),
            )
        except (KeyError, TypeError, ValueError) as exc:
            raise RuntimeError(
                f"{PROFILES_PATH}: profile '{name}' is malformed ({exc!r}) - "
                f"needs at least host, database and password_env."
            ) from exc
    return profiles


def load_profiles() -> dict[str, DbProfile]:
    """All configured profiles, plus "default" (legacy PG_* env vars) unless
    the file defines its own "default". Re-reads the file when it changes."""
    global _cache_mtime, _cache_profiles
    with _cache_lock:
        try:
            mtime = PROFILES_PATH.stat().st_mtime
        except FileNotFoundError:
            mtime = None
        if mtime != _cache_mtime:
            if mtime is None:
                _cache_profiles = {}
            else:
                with open(PROFILES_PATH, encoding="utf-8") as f:
                    _cache_profiles = _parse_profiles(json.load(f))
            _cache_mtime = mtime
        profiles = dict(_cache_profiles)
    profiles.setdefault(DEFAULT_PROFILE_NAME, _default_profile())
    return profiles


def _require_db() -> bool:
    return os.environ.get("RPTCONVERT_REQUIRE_DB", "").strip().lower() in ("1", "true", "yes")


def resolve(
    db_profile: Optional[str] = None,
    db_target: Optional[Mapping[str, Any]] = None,
) -> DbProfile:
    """Pick the profile a render should use. See module docstring.

    Raises UnknownDatabaseError if the request names a database that isn't
    configured, matches more than one profile, or names none while
    RPTCONVERT_REQUIRE_DB is on.
    """
    profiles = load_profiles()

    if db_profile:
        try:
            return profiles[db_profile]
        except KeyError:
            raise UnknownDatabaseError(
                f"Unknown database profile '{db_profile}'. Configured: "
                f"{', '.join(sorted(profiles))}."
            ) from None

    if db_target:
        try:
            host = str(db_target["host"])
            port = int(db_target.get("port") or 5432)
            database = str(db_target["database"])
        except (KeyError, TypeError, ValueError) as exc:
            raise UnknownDatabaseError(
                f"db_target must have host, database and (optionally) port - got {dict(db_target)!r}"
            ) from exc
        hits = [p for p in profiles.values() if p.matches(host, port, database)]
        # "default" is synthesized from env vars and may coincide with a
        # named profile - prefer the named one rather than calling it ambiguous.
        if len(hits) > 1:
            named = [p for p in hits if p.name != DEFAULT_PROFILE_NAME]
            hits = named if named else hits
        if len(hits) == 1:
            return hits[0]
        if not hits:
            raise UnknownDatabaseError(
                f"No database profile on the report server matches "
                f"{host}:{port}/{database}. Add one to {PROFILES_PATH.name} "
                f"(or add '{host}' to an existing profile's match_hosts)."
            )
        raise UnknownDatabaseError(
            f"{host}:{port}/{database} matches more than one profile "
            f"({', '.join(p.name for p in hits)}) - make them distinct."
        )

    if _require_db():
        raise UnknownDatabaseError(
            "This report server requires every request to say which database "
            "to use (db_profile or db_target), and this one didn't."
        )
    return profiles[DEFAULT_PROFILE_NAME]
