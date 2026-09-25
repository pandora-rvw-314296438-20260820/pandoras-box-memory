#!/usr/bin/env python3
"""Render fixture, exact new read RPC and behavior into ONE disposable SQL connection."""
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]

def render() -> str:
    migrations = list((ROOT / "supabase/migrations").glob("*_pandora_operations_performance_read_v1.sql"))
    if len(migrations) != 1:
        raise ValueError("Expected one exact scoped performance-read migration")
    return "\n".join(path.read_text(encoding="utf-8") for path in (
        ROOT / "tests/operations-performance/fixture.sql",
        migrations[0],
        ROOT / "tests/operations-performance/behavior.sql",
    ))

if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    print(render())
