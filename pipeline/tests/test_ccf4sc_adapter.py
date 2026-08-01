import json
import sys
import tempfile
import unittest
from datetime import datetime, timezone
from pathlib import Path

PIPELINE_ROOT = Path(__file__).resolve().parent.parent
if str(PIPELINE_ROOT) not in sys.path:
    sys.path.insert(0, str(PIPELINE_ROOT))

import ccf4sc_adapter
from ccf4sc_adapter import FilterConfig, build_candidates, expand_records, load_source_records, parse_deadline


class CCF4SCAdapterTests(unittest.TestCase):
    def setUp(self) -> None:
        self.root = PIPELINE_ROOT
        self.source_path = self.root / "sample_ccf4sc_source.json"
        self.filter_path = self.root / "sample_ccf4sc_filter.json"
        self.records = load_source_records(self.source_path)

    def test_expand_records_keeps_future_deadlines(self) -> None:
        expanded = expand_records(self.records, now=datetime(2026, 4, 1, tzinfo=timezone.utc))
        self.assertEqual(len(expanded), 4)
        self.assertEqual(expanded[0]["title"], "WISE2027")

    def test_build_candidates_honors_ccf4sc_filter(self) -> None:
        filter_config = FilterConfig.from_payload(json.loads(self.filter_path.read_text(encoding="utf-8")))
        candidates = build_candidates(self.records, filter_config, now=datetime(2026, 4, 1, tzinfo=timezone.utc))

        self.assertEqual([candidate.short_name for candidate in candidates], ["ICLR2027", "CVPR2027"])
        self.assertTrue(candidates[0].to_payload()["deadlines"][0]["timestamp"].endswith("Z"))

    def test_filter_can_match_by_rank_without_explicit_conf(self) -> None:
        filter_config = FilterConfig.from_payload({"rank": "C", "conf": [], "sub": "", "remove": {}})
        candidates = build_candidates(self.records, filter_config, now=datetime(2026, 4, 1, tzinfo=timezone.utc))
        self.assertEqual(len(candidates), 1)
        self.assertEqual(candidates[0].short_name, "WISE2027")

    def test_default_filter_includes_ccf_none_candidates(self) -> None:
        candidates = build_candidates(
            self.records,
            FilterConfig.from_payload(None),
            now=datetime(2026, 4, 1, tzinfo=timezone.utc),
        )
        none_candidates = [candidate for candidate in candidates if candidate.ccf_rank == "N"]
        self.assertEqual([candidate.short_name for candidate in none_candidates], ["COLM2027"])

    def test_filter_can_match_ccf_none_rank(self) -> None:
        filter_config = FilterConfig.from_payload({"rank": "N", "conf": [], "sub": "", "remove": {}})
        candidates = build_candidates(self.records, filter_config, now=datetime(2026, 4, 1, tzinfo=timezone.utc))
        self.assertEqual([candidate.short_name for candidate in candidates], ["COLM2027"])

    def test_source_loader_supports_json_snapshots(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            temp_path = Path(directory) / "source.json"
            temp_path.write_text(self.source_path.read_text(encoding="utf-8"), encoding="utf-8")
            loaded = load_source_records(temp_path)
        self.assertEqual(len(loaded), len(self.records))

    def test_abstract_and_paper_deadlines_are_both_preserved(self) -> None:
        records = [
            {
                "id": "test",
                "title": "TEST",
                "sub": "AI",
                "rank": {"ccf": "A"},
                "link": "https://example.com",
                "confs": [
                    {
                        "year": 2027,
                        "timezone": "AoE",
                        "timeline": [
                            {
                                "abstract_deadline": "2026-09-01 23:59:00",
                                "deadline": "2026-09-08 23:59:00",
                            }
                        ],
                    }
                ],
            }
        ]
        candidates = build_candidates(records, FilterConfig.from_payload(None), now=datetime(2026, 4, 1, tzinfo=timezone.utc))
        deadlines = candidates[0].to_payload()["deadlines"]
        self.assertEqual([deadline["stage"] for deadline in deadlines], ["Abstract", "Full Paper"])

    def test_pt_timezone_observes_daylight_saving_time(self) -> None:
        summer = parse_deadline("2026-08-01 17:00:00", "PT")
        winter = parse_deadline("2026-12-01 17:00:00", "PT")
        self.assertEqual(summer, datetime(2026, 8, 2, 0, 0, tzinfo=timezone.utc))
        self.assertEqual(winter, datetime(2026, 12, 2, 1, 0, tzinfo=timezone.utc))

    @unittest.skipIf(ccf4sc_adapter.yaml is None, "PyYAML is not installed")
    def test_source_loader_filters_yaml_control_characters(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            temp_path = Path(directory) / "source.yml"
            temp_path.write_text("- title: Test\x8c\n  confs: []\n", encoding="utf-8")
            loaded = load_source_records(temp_path)
        self.assertEqual(loaded, [{"title": "Test", "confs": []}])


if __name__ == "__main__":
    unittest.main()
