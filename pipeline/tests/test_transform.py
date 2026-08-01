import json
import sys
import tempfile
import unittest
from pathlib import Path

PIPELINE_ROOT = Path(__file__).resolve().parent.parent
if str(PIPELINE_ROOT) not in sys.path:
    sys.path.insert(0, str(PIPELINE_ROOT))

from ccfddl_transform import CandidateItem, export_ics, load_candidates
from update_ccfcal_candidates import preserve_generation_time_for_unchanged_snapshot


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
        self.assertNotIn("DTSTART:20260924035900Z\r\nDTEND:20260924035900Z", ics)

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

    def test_unchanged_snapshot_preserves_generation_time(self) -> None:
        existing = {"source": "ccfddl", "generated_at": "2026-08-01T10:00:00+00:00", "items": [{"id": "a"}]}
        refreshed = {"source": "ccfddl", "generated_at": "2026-08-02T10:00:00+00:00", "items": [{"id": "a"}]}
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "snapshot.json"
            path.write_text(json.dumps(existing), encoding="utf-8")
            result = preserve_generation_time_for_unchanged_snapshot(refreshed, path)
        self.assertEqual(result["generated_at"], existing["generated_at"])

    def test_ccf_none_alias_normalizes_and_displays_consistently(self) -> None:
        candidate = CandidateItem.from_payload(
            {
                "title": "Conference on Language Modeling 2027",
                "short_name": "COLM2027",
                "kind": "conference",
                "ccf_rank": "NONE",
                "domains": ["AI"],
                "url": "https://colmweb.org/",
                "deadlines": [
                    {
                        "stage": "Full Paper",
                        "timestamp": "2026-09-01T23:59:00Z",
                        "timezone": "UTC",
                    }
                ],
            }
        )
        self.assertEqual(candidate.ccf_rank, "N")
        self.assertIn("[CCF-NONE]", export_ics([candidate]))

    def test_ics_uids_include_timestamp_and_remain_unique(self) -> None:
        candidate = CandidateItem.from_payload(
            {
                "title": "VLDB 2027",
                "short_name": "VLDB2027",
                "kind": "conference",
                "ccf_rank": "A",
                "domains": ["DB"],
                "url": "https://example.com/a,b;c",
                "deadlines": [
                    {"stage": "Deadline, Cycle; 1", "timestamp": "2026-08-02T00:00:00Z", "timezone": "PT"},
                    {"stage": "Deadline", "timestamp": "2026-09-02T00:00:00Z", "timezone": "PT"},
                ],
            }
        )
        ics = export_ics([candidate])
        uids = [line for line in ics.splitlines() if line.startswith("UID:")]
        self.assertEqual(len(uids), 2)
        self.assertEqual(len(set(uids)), 2)
        self.assertIn("Deadline\\, Cycle\\; 1", ics)
        self.assertIn("URL:https://example.com/a,b;c", ics)


if __name__ == "__main__":
    unittest.main()
