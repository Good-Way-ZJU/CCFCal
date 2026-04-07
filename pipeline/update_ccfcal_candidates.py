#!/usr/bin/env python3

from __future__ import annotations

import argparse
import json
import re
from datetime import datetime, timezone, timedelta
from pathlib import Path

from ccf4sc_adapter import FilterConfig, build_candidates, load_source_records
from ccfddl_transform import CandidateItem, Deadline, export_ics


SUMMARY_RE = re.compile(r"^(?P<name>.+?) \((?P<domain>.+) CCF-(?P<rank>[ABC])\)$")


def slugify(value: str) -> str:
    return "".join(ch.lower() if ch.isalnum() else "-" for ch in value).strip("-")


def unfold_ics_lines(text: str) -> list[str]:
    lines: list[str] = []
    for raw_line in text.splitlines():
        if raw_line.startswith((" ", "\t")) and lines:
            lines[-1] += raw_line[1:]
        else:
            lines.append(raw_line)
    return lines


def split_ics_property_line(line: str) -> tuple[str, str] | tuple[None, None]:
    in_quotes = False
    for index, char in enumerate(line):
        if char == '"':
            in_quotes = not in_quotes
        elif char == ":" and not in_quotes:
            return line[:index], line[index + 1:]
    return None, None


def parse_ics_datetime(header: str, value: str) -> datetime:
    tz_match = re.search(r'TZID="?UTC([+-]\d{2}):?(\d{2})"?', header)
    if value.endswith("Z"):
        return datetime.strptime(value, "%Y%m%dT%H%M%SZ").replace(tzinfo=timezone.utc)
    dt = datetime.strptime(value, "%Y%m%dT%H%M%S")
    if tz_match:
        sign_hours = int(tz_match.group(1))
        sign_minutes = int(tz_match.group(2))
        offset = timedelta(hours=sign_hours, minutes=sign_minutes if sign_hours >= 0 else -sign_minutes)
        return dt.replace(tzinfo=timezone(offset)).astimezone(timezone.utc)
    return dt.replace(tzinfo=timezone.utc)


def candidates_from_ccf4sc_ics(path: Path) -> list[CandidateItem]:
    text = path.read_text(encoding="utf-8", errors="ignore")
    lines = unfold_ics_lines(text)
    events: list[dict[str, str]] = []
    current: dict[str, str] | None = None
    for line in lines:
        if line == "BEGIN:VEVENT":
            current = {}
            continue
        if line == "END:VEVENT":
            if current:
                events.append(current)
            current = None
            continue
        if current is None or ":" not in line:
            continue
        key, value = split_ics_property_line(line)
        if key is None:
            continue
        current[key] = value

    candidates: list[CandidateItem] = []
    for event in events:
        summary = event.get("SUMMARY", "")
        match = SUMMARY_RE.match(summary)
        if not match:
            continue
        name = match.group("name").strip()
        domain = match.group("domain").strip()
        rank = match.group("rank").strip()
        deadline_dt = parse_ics_datetime(next((key for key in event.keys() if key.startswith("DTEND")), "DTEND"), next((value for key, value in event.items() if key.startswith("DTEND")), ""))
        deadline = Deadline(stage="Deadline", timestamp=deadline_dt.isoformat().replace("+00:00", "Z"), timezone_name="UTC+8")
        candidates.append(
            CandidateItem.from_payload(
                {
                    "title": name,
                    "short_name": name,
                    "kind": "conference",
                    "ccf_rank": rank,
                    "domains": [domain],
                    "url": event.get("UID", ""),
                    "deadlines": [
                        {
                            "stage": deadline.stage,
                            "timestamp": deadline.timestamp,
                            "timezone": deadline.timezone_name,
                        }
                    ],
                }
            )
        )
    return candidates


def build_app_payload(candidates: list[CandidateItem], source: str, generated_at: str) -> dict:
    return {
        "source": source,
        "generated_at": generated_at,
        "items": [
            {
                "id": candidate.id,
                "title": candidate.title,
                "short_name": candidate.short_name,
                "kind": candidate.kind,
                "ccf_rank": candidate.ccf_rank,
                "domains": candidate.domains,
                "url": candidate.url,
                "deadlines": [
                    {
                        "stage": deadline["stage"] if isinstance(deadline, dict) else deadline.stage,
                        "timestamp": deadline["timestamp"] if isinstance(deadline, dict) else deadline.timestamp,
                    }
                    for deadline in (candidate.deadlines if isinstance(candidate.deadlines, list) else [])
                ],
                "next_deadline_timestamp": candidate.deadlines[0]["timestamp"] if isinstance(candidate.deadlines[0], dict) else candidate.deadlines[0].timestamp,
                "next_deadline_display": (
                    datetime.fromisoformat(
                        (candidate.deadlines[0]["timestamp"] if isinstance(candidate.deadlines[0], dict) else candidate.deadlines[0].timestamp).replace("Z", "+00:00")
                    )
                    .astimezone(timezone(timedelta(hours=8)))
                    .strftime("%Y-%m-%d %H:%M")
                ),
            }
            for candidate in candidates
        ],
    }


def main() -> None:
    parser = argparse.ArgumentParser(description="Fetch the latest ccfddl snapshot and write CCFCal candidate data plus a real ICS feed.")
    parser.add_argument(
        "--output",
        type=Path,
        default=Path(__file__).resolve().parents[1] / "CCFCal" / "CCFCal" / "DDLCandidates.json",
        help="Target DDLCandidates.json path.",
    )
    parser.add_argument(
        "--source",
        type=Path,
        help="Optional local snapshot (.json/.yml). If omitted, fetch from ccfddl.github.io like ccf4sc.",
    )
    parser.add_argument(
        "--source-url",
        default="https://ccfddl.github.io/conference/allconf.yml",
        help="Remote ccfddl YAML URL.",
    )
    parser.add_argument(
        "--ics-output",
        type=Path,
        default=Path(__file__).resolve().parents[1] / "pipeline" / "output" / "DDLFeed.ics",
        help="Target real ICS feed path.",
    )
    parser.add_argument(
        "--ccf4sc-ics",
        type=Path,
        help="Optional local ccf4sc-generated ccf.ics snapshot to import directly.",
    )
    args = parser.parse_args()

    generated_at = datetime.now(timezone(timedelta(hours=8))).isoformat(timespec="seconds")
    if args.ccf4sc_ics:
        candidates = candidates_from_ccf4sc_ics(args.ccf4sc_ics)
        payload = build_app_payload(candidates, "local ccf4sc ccf.ics snapshot", generated_at)
    else:
        records = load_source_records(args.source, source_url=args.source_url)
        candidates = build_candidates(records, FilterConfig.from_payload({"rank": "ABC", "sub": "", "conf": [], "remove": {}}))
        payload = build_app_payload(candidates, "ccfddl.github.io/conference/allconf.yml via ccf4sc-style adapter", generated_at)

    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.ics_output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(payload, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    args.ics_output.write_text(export_ics(candidates), encoding="utf-8")


if __name__ == "__main__":
    main()
