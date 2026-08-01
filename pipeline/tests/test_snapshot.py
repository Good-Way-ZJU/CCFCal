import json
import unittest
from datetime import datetime
from pathlib import Path


REPOSITORY_ROOT = Path(__file__).resolve().parents[2]
APP_SNAPSHOT = REPOSITORY_ROOT / "CCFCal" / "CCFCal" / "DDLCandidates.json"
DOCS_SNAPSHOT = REPOSITORY_ROOT / "docs" / "DDLCandidates.json"


class SnapshotTests(unittest.TestCase):
    def setUp(self) -> None:
        self.payload = json.loads(APP_SNAPSHOT.read_text(encoding="utf-8"))

    def test_hosted_and_bundled_snapshots_match(self) -> None:
        self.assertEqual(APP_SNAPSHOT.read_bytes(), DOCS_SNAPSHOT.read_bytes())

    def test_snapshot_has_valid_candidate_shape(self) -> None:
        generated_at = datetime.fromisoformat(self.payload["generated_at"].replace("Z", "+00:00"))
        self.assertIsNotNone(generated_at.tzinfo)

        items = self.payload["items"]
        self.assertGreaterEqual(len(items), 20)
        self.assertTrue({"A", "B", "C"}.issubset({item["ccf_rank"] for item in items}))
        self.assertEqual(len({item["id"] for item in items}), len(items))

        for item in items:
            self.assertTrue(item["id"])
            self.assertTrue(item["title"])
            self.assertTrue(item["short_name"])
            self.assertIn(item["ccf_rank"], {"A", "B", "C", "N"})
            self.assertTrue(item["domains"])
            self.assertTrue(item["deadlines"])
            next_timestamp = datetime.fromisoformat(item["next_deadline_timestamp"].replace("Z", "+00:00"))
            self.assertIsNotNone(next_timestamp.tzinfo)
            for deadline in item["deadlines"]:
                self.assertTrue(deadline["stage"])
                parsed = datetime.fromisoformat(deadline["timestamp"].replace("Z", "+00:00"))
                self.assertIsNotNone(parsed.tzinfo)


if __name__ == "__main__":
    unittest.main()
