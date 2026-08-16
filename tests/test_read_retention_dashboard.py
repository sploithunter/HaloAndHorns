from __future__ import annotations

import importlib.util
import sys
import unittest
from pathlib import Path


TOOLS_DIR = Path(__file__).parents[1] / "tools"
sys.path.insert(0, str(TOOLS_DIR))
MODULE_PATH = TOOLS_DIR / "read_retention_dashboard.py"
SPEC = importlib.util.spec_from_file_location("read_retention_dashboard", MODULE_PATH)
assert SPEC and SPEC.loader
dashboard = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(dashboard)


class RetentionDashboardTests(unittest.TestCase):
    def test_entry_path_encodes_fixed_key_without_listing(self):
        self.assertEqual(
            dashboard.entry_path("123", "RetentionDashboard_v1", "d20260725/b03"),
            "universes/123/data-stores/RetentionDashboard_v1/scopes/global/"
            "entries/d20260725%2Fb03",
        )

    def test_dashboard_payload_merges_bucket_counters(self):
        payload = dashboard.dashboard_payload(
            [
                {
                    "updatedAt": 10,
                    "contributions": {
                        "servera": {
                            "server": {"placeVersion": 100},
                            "counters": {"newPlayers": 2},
                        }
                    },
                    "definitions": {
                        "tutorialSteps": [
                            {"index": 1, "id": "hatch_first_egg", "name": "Hatch"}
                        ]
                    },
                    "exclusions": {"playerNamePrefixes": ["sploit"]},
                    "counters": {
                        "newPlayers": 2,
                        "distinctReturners": {"d1": 1, "d2_7": 1},
                        "newPlayerSessionsEnded": 2,
                        "tutorialSteps": {
                            "hatch_first_egg": {
                                "reached": 1,
                                "totalSecondsToReach": 10,
                            }
                        },
                        "starterChoice": {
                            "shown": 2,
                            "selected": 1,
                            "byPet": {"kitty": 1},
                        },
                    },
                },
                {
                    "updatedAt": 20,
                    "contributions": {
                        "serverb": {
                            "server": {"placeVersion": 101},
                            "counters": {"newPlayers": 3},
                        }
                    },
                    "counters": {
                        "newPlayers": 3,
                        "distinctReturners": {"d1": 1, "d8_30": 1},
                        "newPlayerSessionsEnded": 2,
                        "tutorialSteps": {
                            "hatch_first_egg": {
                                "reached": 2,
                                "totalSecondsToReach": 30,
                            }
                        },
                        "starterChoice": {
                            "shown": 3,
                            "selected": 3,
                            "byPet": {"bear": 2, "kitty": 1},
                        },
                    },
                },
            ],
            "20260725",
            16,
        )

        self.assertEqual(payload["bucketsPresent"], 2)
        self.assertEqual(payload["updatedAt"], 20)
        self.assertEqual(payload["summary"]["newPlayers"], 5)
        self.assertEqual(payload["summary"]["distinctD1Returners"], 2)
        self.assertEqual(payload["summary"]["distinctD1RetentionRate"], 0.4)
        self.assertEqual(payload["summary"]["distinctD2To7Returners"], 1)
        self.assertEqual(payload["summary"]["distinctD8To30Returners"], 1)
        self.assertEqual(payload["tutorialFunnel"][0]["reached"], 3)
        self.assertEqual(payload["starterChoice"]["byPet"], {"kitty": 2, "bear": 2})
        self.assertEqual(payload["builds"]["place:100"]["summary"]["newPlayers"], 2)
        self.assertEqual(payload["builds"]["place:101"]["summary"]["newPlayers"], 3)


if __name__ == "__main__":
    unittest.main()
