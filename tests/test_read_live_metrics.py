from __future__ import annotations

import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TOOLS = ROOT / "tools"
if str(TOOLS) not in sys.path:
    sys.path.insert(0, str(TOOLS))

import read_live_metrics  # noqa: E402


DEFINITIONS = {
    "tutorialSteps": [
        {"index": 1, "id": "hatch_first_egg", "name": "Hatch"},
        {"index": 2, "id": "equip_pet", "name": "Deploy"},
    ]
}


def day(date: str, new_players: int, sessions: int) -> dict:
    return {
        "dateUtc": date,
        "definitions": DEFINITIONS,
        "builds": {"place:10": {}},
        "counters": {
            "newPlayers": new_players,
            "newPlayerSessionsEnded": new_players,
            "newPlayerTotalSessionSeconds": new_players * 100,
            "sessionsStarted": sessions,
            "sessionsEnded": sessions,
            "totalSessionSeconds": sessions * 100,
            "newPlayerTutorialCompleted": 1,
            "distinctReturners": {"d1": 1, "d2_7": 2, "d8_30": 1},
            "tutorialSteps": {
                "hatch_first_egg": {"reached": 2, "totalSecondsToReach": 20},
                "equip_pet": {"reached": 1, "totalSecondsToReach": 20},
            },
            "starterChoice": {"shown": 2, "selected": 1},
            "questsCompleted": {"fs_boost": 1},
            "exitedBeforeEarnedLevel2": 1,
        },
    }


class LiveMetricsTests(unittest.TestCase):
    def test_merge_days_and_metric_snapshot(self) -> None:
        window = read_live_metrics.merge_days(
            [day("20260101", 4, 6), day("20260102", 6, 9)]
        )
        metrics = read_live_metrics.metric_snapshot(window)

        self.assertEqual(metrics["newPlayers"], 10)
        self.assertEqual(metrics["newPlayersPerDay"], 5)
        self.assertEqual(metrics["sessionsStarted"], 15)
        self.assertEqual(metrics["repeatSessionVolume"], 5)
        self.assertEqual(metrics["distinctD1Returners"], 2)
        self.assertEqual(metrics["distinctD1RetentionRate"], 0.2)
        self.assertEqual(metrics["distinctD2To7Returners"], 4)
        self.assertEqual(metrics["distinctD2To7RetentionRate"], 0.4)
        self.assertEqual(metrics["distinctD8To30Returners"], 2)
        self.assertEqual(metrics["distinctD8To30RetentionRate"], 0.2)
        self.assertEqual(metrics["firstHatch"], 4)
        self.assertEqual(metrics["firstHatchRate"], 0.4)
        self.assertEqual(metrics["tutorialCompleted"], 2)
        self.assertEqual(metrics["tutorialCompletionRate"], 0.2)
        self.assertEqual(metrics["reachedLevel2ByExitRate"], 0.8)
        self.assertEqual(metrics["sessionEndCoverage"], 1)

    def test_change_formats_percentage_points(self) -> None:
        self.assertEqual(read_live_metrics.change(0.25, 0.2, rate=True), "+5.0 pp")


if __name__ == "__main__":
    unittest.main()
