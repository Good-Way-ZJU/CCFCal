#!/usr/bin/env python3

from __future__ import annotations

import argparse
import json
import hashlib
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


def parse_datetime(value: str) -> datetime:
    normalized = value.replace("Z", "+00:00")
    result = datetime.fromisoformat(normalized)
    if result.tzinfo is None:
        raise ValueError(f"timestamp must include timezone: {value}")
    return result.astimezone(timezone.utc)


def slugify(value: str) -> str:
    return "".join(ch.lower() if ch.isalnum() else "-" for ch in value).strip("-")


@dataclass(frozen=True)
class Deadline:
    stage: str
    timestamp: str
    timezone_name: str

    def as_datetime(self) -> datetime:
        return parse_datetime(self.timestamp)


@dataclass(frozen=True)
class CandidateItem:
    id: str
    title: str
    short_name: str
    kind: str
    ccf_rank: str
    domains: list[str]
    url: str
    deadlines: list[Deadline]

    @staticmethod
    def from_payload(payload: dict[str, Any]) -> "CandidateItem":
        digest_source = "|".join(
            [
                payload["short_name"],
                payload["kind"],
                payload["ccf_rank"],
                ",".join(sorted(payload["domains"])),
            ]
        )
        digest = hashlib.sha1(digest_source.encode("utf-8")).hexdigest()[:12]
        identifier = f"{slugify(payload['short_name'])}-{digest}"
        deadlines = [
            Deadline(
                stage=deadline["stage"],
                timestamp=deadline["timestamp"],
                timezone_name=deadline["timezone"],
            )
            for deadline in payload["deadlines"]
        ]
        return CandidateItem(
            id=identifier,
            title=payload["title"],
            short_name=payload["short_name"],
            kind=payload["kind"],
            ccf_rank=payload["ccf_rank"],
            domains=sorted(payload["domains"]),
            url=payload["url"],
            deadlines=deadlines,
        )

    def to_payload(self) -> dict[str, Any]:
        return {
            "id": self.id,
            "title": self.title,
            "short_name": self.short_name,
            "kind": self.kind,
            "ccf_rank": self.ccf_rank,
            "domains": self.domains,
            "url": self.url,
            "deadlines": [
                {
                    "stage": deadline.stage,
                    "timestamp": deadline.as_datetime().isoformat().replace("+00:00", "Z"),
                    "timezone": deadline.timezone_name,
                }
                for deadline in sorted(self.deadlines, key=lambda item: item.as_datetime())
            ],
        }


def load_candidates(path: Path) -> list[CandidateItem]:
    raw = json.loads(path.read_text(encoding="utf-8"))
    return [CandidateItem.from_payload(item) for item in raw]


def format_ics_datetime(value: datetime) -> str:
    return value.strftime("%Y%m%dT%H%M%SZ")


def build_event_title(candidate: CandidateItem, deadline: Deadline) -> str:
    primary_domain = candidate.domains[0] if candidate.domains else "GEN"
    return f"[DDL][CCF-{candidate.ccf_rank}][{primary_domain}] {candidate.short_name} {deadline.stage}"


def build_event_description(candidate: CandidateItem, deadline: Deadline) -> str:
    parts = {
        "item_id": candidate.id,
        "ccf_rank": candidate.ccf_rank,
        "domains": ",".join(candidate.domains),
        "stage": deadline.stage,
        "kind": candidate.kind,
        "url": candidate.url,
        "source_timezone": deadline.timezone_name,
    }
    return "\\n".join(f"{key}:{value}" for key, value in parts.items())


def export_ics(candidates: list[CandidateItem]) -> str:
    lines = [
        "BEGIN:VCALENDAR",
        "VERSION:2.0",
        "PRODID:-//DDLCal//CCF DDL//EN",
        "CALSCALE:GREGORIAN",
        "METHOD:PUBLISH",
    ]
    generated_at = format_ics_datetime(datetime.now(timezone.utc))
    for candidate in candidates:
        for deadline in sorted(candidate.deadlines, key=lambda item: item.as_datetime()):
            dtstart = deadline.as_datetime()
            dtend = dtstart
            lines.extend(
                [
                    "BEGIN:VEVENT",
                    f"UID:{candidate.id}-{slugify(deadline.stage)}@ddlcal",
                    f"DTSTAMP:{generated_at}",
                    f"DTSTART:{format_ics_datetime(dtstart)}",
                    f"DTEND:{format_ics_datetime(dtend)}",
                    f"SUMMARY:{build_event_title(candidate, deadline)}",
                    f"DESCRIPTION:{build_event_description(candidate, deadline)}",
                    f"URL:{candidate.url}",
                    "END:VEVENT",
                ]
            )
    lines.append("END:VCALENDAR")
    return "\r\n".join(lines) + "\r\n"


def main() -> None:
    parser = argparse.ArgumentParser(description="Transform CCF DDL source data into candidates and ICS.")
    parser.add_argument("--input", required=True, type=Path)
    parser.add_argument("--candidates-out", required=True, type=Path)
    parser.add_argument("--ics-out", required=True, type=Path)
    args = parser.parse_args()

    candidates = load_candidates(args.input)
    args.candidates_out.parent.mkdir(parents=True, exist_ok=True)
    args.ics_out.parent.mkdir(parents=True, exist_ok=True)

    candidate_payload = [candidate.to_payload() for candidate in candidates]
    args.candidates_out.write_text(
        json.dumps(candidate_payload, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )
    args.ics_out.write_text(export_ics(candidates), encoding="utf-8")


if __name__ == "__main__":
    main()
