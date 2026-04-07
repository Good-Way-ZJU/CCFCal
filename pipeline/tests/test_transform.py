import json
import sys
import tempfile
import unittest
from pathlib import Path

PIPELINE_ROOT = Path(__file__).resolve().parent.parent
if str(PIPELINE_ROOT) not in sys.path:
    sys.path.insert(0, str(PIPELINE_ROOT))

from ccfddl_transform import export_ics, load_candidates


class TransformTests(unittest.TestCase):
    def setUp(self) -> None:
        self.sample_path = PIPELINE_ROOT / "sample_ccfddl.json"
        self.candidates = load_candidates(self.sample_path)

    def test_load_candidates_creates_stable_ids(self) -> None:
        first = self.candidates[0]
        self.assertTrue(first.id.startswith("iclr-2027-"))
        self.assertEqual(first.ccf_rank, "A")
        self.assertIn("AI", first.domains)

    def test_export_ics_contains_expected_metadata(self) -> None:
        ics = export_ics(self.candidates[:1])
        self.assertIn("BEGIN:VCALENDAR", ics)
        self.assertIn("SUMMARY:[DDL][CCF-A][AI] ICLR 2027 Abstract", ics)
        self.assertIn("item_id:", ics)
        self.assertIn("source_timezone:AoE", ics)

    def test_transformed_payload_normalizes_to_utc(self) -> None:
        payload = self.candidates[0].to_payload()
        abstract_deadline = payload["deadlines"][0]
        self.assertTrue(abstract_deadline["timestamp"].endswith("Z"))

    def test_roundtrip_output_writes_json(self) -> None:
        payload = [candidate.to_payload() for candidate in self.candidates]
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "candidates.json"
            path.write_text(json.dumps(payload), encoding="utf-8")
            loaded = json.loads(path.read_text(encoding="utf-8"))
        self.assertEqual(len(loaded), len(self.candidates))


if __name__ == "__main__":
    unittest.main()
