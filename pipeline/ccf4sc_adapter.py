#!/usr/bin/env python3

from __future__ import annotations

import argparse
import json
from copy import deepcopy
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any

from ccfddl_transform import CandidateItem, Deadline, export_ics

try:
    import requests
    import yaml
except ImportError:  # pragma: no cover
    requests = None
    yaml = None


DEFAULT_SOURCE_URL = "https://ccfddl.github.io/conference/allconf.yml"
SUBJECT_MAP = {
    "DS": "ARCH",
    "NW": "NET",
    "SC": "SEC",
    "SE": "SE",
    "DB": "DB",
    "CT": "TH",
    "CG": "CG",
    "AI": "AI",
    "HI": "HCI",
    "MX": "SYS",
}
SUBJECT_LABELS = {
    "DS": "计算机体系结构/并行与分布计算/存储系统",
    "NW": "计算机网络",
    "SC": "网络与信息安全",
    "SE": "软件工程/系统软件/程序设计语言",
    "DB": "数据库/数据挖掘/内容检索",
    "CT": "计算机科学理论",
    "CG": "计算机图形学与多媒体",
    "AI": "人工智能",
    "HI": "人机交互与普适计算",
    "MX": "交叉/综合/新兴",
}


@dataclass(frozen=True)
class FilterConfig:
    conf: list[str]
    rank: str
    sub: str
    remove: dict[str, str]

    @staticmethod
    def from_payload(payload: dict[str, Any] | None) -> "FilterConfig":
        payload = payload or {}
        return FilterConfig(
            conf=[entry.lower() for entry in payload.get("conf", [])],
            rank=str(payload.get("rank", "ABC")),
            sub=str(payload.get("sub", "")),
            remove={str(key): str(value) for key, value in payload.get("remove", {}).items()},
        )


def alpha_id(value: str) -> str:
    return "".join(ch for ch in value.lower() if ch.isalpha())


def parse_tz(value: str) -> timezone:
    if value == "AoE":
        return timezone(timedelta(hours=-12))
    if value.startswith("UTC-"):
        return timezone(-timedelta(hours=int(value[4:])))
    if value.startswith("UTC+"):
        return timezone(timedelta(hours=int(value[4:])))
    return timezone.utc


def load_source_records(path: Path | None, source_url: str = DEFAULT_SOURCE_URL) -> list[dict[str, Any]]:
    if path is not None:
        suffix = path.suffix.lower()
        text = path.read_text(encoding="utf-8")
        if suffix == ".json":
            return json.loads(text)
        if suffix in {".yml", ".yaml"}:
            if yaml is None:
                raise RuntimeError("PyYAML is required to read YAML source files.")
            return yaml.safe_load(sanitize_yaml_text(text))
        raise ValueError(f"Unsupported source format: {path}")

    if requests is None or yaml is None:
        raise RuntimeError("requests and PyYAML are required to fetch the ccf4sc upstream source.")

    response = requests.get(source_url, timeout=30)
    response.raise_for_status()
    return yaml.safe_load(sanitize_yaml_text(response.text))


def sanitize_yaml_text(text: str) -> str:
    return "".join(character for character in text if is_yaml_printable(character))


def is_yaml_printable(character: str) -> bool:
    codepoint = ord(character)
    return (
        character in "\t\n\r"
        or codepoint == 0x85
        or 0x20 <= codepoint <= 0x7E
        or 0xA0 <= codepoint <= 0xD7FF
        or 0xE000 <= codepoint <= 0xFFFD
        or 0x10000 <= codepoint <= 0x10FFFF
    )


def expand_records(records: list[dict[str, Any]], now: datetime | None = None) -> list[dict[str, Any]]:
    now = now or datetime.now(timezone.utc)
    expanded: list[dict[str, Any]] = []
    for record in records:
        for conf in record.get("confs", []):
            entry = deepcopy(record)
            entry["title"] = f"{record['title']}{conf['year']}"
            entry.update(conf)

            deadlines: list[dict[str, Any]] = []
            for timeline in conf.get("timeline", []):
                deadline_text = timeline.get("deadline")
                if not deadline_text:
                    continue
                try:
                    deadline_dt = datetime.strptime(deadline_text, "%Y-%m-%d %H:%M:%S")
                except ValueError:
                    continue
                deadline_dt = deadline_dt.replace(tzinfo=parse_tz(conf.get("timezone", "UTC+0"))).astimezone(timezone.utc)
                if deadline_dt < now:
                    continue
                stage = timeline.get("abstract", "") or timeline.get("comment", "") or "Deadline"
                deadlines.append(
                    {
                        "stage": stage.strip() or "Deadline",
                        "timestamp": deadline_dt,
                        "timezone": conf.get("timezone", "UTC+0"),
                    }
                )

            if deadlines:
                entry["deadlines"] = sorted(deadlines, key=lambda item: item["timestamp"])
                entry["time_obj"] = entry["deadlines"][0]["timestamp"]
                expanded.append(entry)
    return sorted(expanded, key=lambda item: item["time_obj"])


def matches_filter(entry: dict[str, Any], filter_config: FilterConfig) -> bool:
    confs = filter_config.conf
    ccf_rank = str(entry.get("rank", {}).get("ccf", ""))
    subject = str(entry.get("sub", ""))

    matched = False
    if alpha_id(str(entry.get("id", ""))) in confs:
        matched = True
    elif alpha_id(subject) in filter_config.sub.lower():
        matched = True
    elif alpha_id(ccf_rank) in filter_config.rank.lower():
        matched = True

    if not matched:
        return False

    for remove_key, remove_value in filter_config.remove.items():
        key = remove_key.lower()
        if key == "conf" and entry.get("title") == remove_value:
            return False
        if key == "sub" and SUBJECT_LABELS.get(subject, subject) == remove_value:
            return False
        if key == "rank" and ccf_rank == remove_value:
            return False
    return True


def to_candidate_item(entry: dict[str, Any]) -> CandidateItem:
    subject = str(entry.get("sub", ""))
    primary_domain = SUBJECT_MAP.get(subject, alpha_id(subject).upper() or "GEN")
    deadlines = [
        Deadline(
            stage=deadline["stage"],
            timestamp=deadline["timestamp"].isoformat().replace("+00:00", "Z"),
            timezone_name=deadline["timezone"],
        )
        for deadline in entry["deadlines"]
    ]

    return CandidateItem.from_payload(
        {
            "title": entry["title"],
            "short_name": entry.get("title", ""),
            "kind": "conference",
            "ccf_rank": entry.get("rank", {}).get("ccf", "C"),
            "domains": [primary_domain],
            "url": entry.get("link", ""),
            "deadlines": [
                {
                    "stage": deadline.stage,
                    "timestamp": deadline.timestamp,
                    "timezone": deadline.timezone_name,
                }
                for deadline in deadlines
            ],
        }
    )


def build_candidates(records: list[dict[str, Any]], filter_config: FilterConfig, now: datetime | None = None) -> list[CandidateItem]:
    expanded = expand_records(records, now=now)
    matched = [record for record in expanded if matches_filter(record, filter_config)]
    return [to_candidate_item(record) for record in matched]


def main() -> None:
    parser = argparse.ArgumentParser(description="Adapt ccf4sc source/filter config into DDLCal candidate data and ICS.")
    parser.add_argument("--source", type=Path, help="Optional local ccfddl source snapshot (.json/.yml).")
    parser.add_argument("--source-url", default=DEFAULT_SOURCE_URL, help="Remote ccfddl YAML URL.")
    parser.add_argument("--filter-config", type=Path, help="Optional ccf4sc-style filter JSON, e.g. conf/rank/sub/remove.")
    parser.add_argument("--candidates-out", required=True, type=Path)
    parser.add_argument("--ics-out", required=True, type=Path)
    args = parser.parse_args()

    filter_config = FilterConfig.from_payload(
        json.loads(args.filter_config.read_text(encoding="utf-8")) if args.filter_config else None
    )
    records = load_source_records(args.source, source_url=args.source_url)
    candidates = build_candidates(records, filter_config)

    args.candidates_out.parent.mkdir(parents=True, exist_ok=True)
    args.ics_out.parent.mkdir(parents=True, exist_ok=True)
    args.candidates_out.write_text(
        json.dumps([candidate.to_payload() for candidate in candidates], indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )
    args.ics_out.write_text(export_ics(candidates), encoding="utf-8")


if __name__ == "__main__":
    main()
