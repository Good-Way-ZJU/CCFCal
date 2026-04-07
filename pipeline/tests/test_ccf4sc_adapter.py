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
from ccf4sc_adapter import FilterConfig, build_candidates, expand_records, load_source_records


class CCF4SCAdapterTests(unittest.TestCase):
    def setUp(self) -> None:
        self.root = PIPELINE_ROOT
        self.source_path = self.root / "sample_ccf4sc_source.json"
        self.filter_path = self.root / "sample_ccf4sc_filter.json"
        self.records = load_source_records(self.source_path)

    def test_expand_records_keeps_future_deadlines(self) -> None:
        expanded = expand_records(self.records, now=datetime(2026, 4, 1, tzinfo=timezone.utc))
        self.assertEqual(len(expanded), 3)
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

    def test_source_loader_supports_json_snapshots(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            temp_path = Path(directory) / "source.json"
            temp_path.write_text(self.source_path.read_text(encoding="utf-8"), encoding="utf-8")
            loaded = load_source_records(temp_path)
        self.assertEqual(len(loaded), len(self.records))

    @unittest.skipIf(ccf4sc_adapter.yaml is None, "PyYAML is not installed")
    def test_source_loader_filters_yaml_control_characters(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            temp_path = Path(directory) / "source.yml"
            temp_path.write_text("- title: Test\x8c\n  confs: []\n", encoding="utf-8")
            loaded = load_source_records(temp_path)
        self.assertEqual(loaded, [{"title": "Test", "confs": []}])


if __name__ == "__main__":
    unittest.main()
