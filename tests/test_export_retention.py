from __future__ import annotations

import importlib.util
import io
import unittest
import urllib.error
from pathlib import Path
from unittest import mock


MODULE_PATH = Path(__file__).parents[1] / "tools" / "export_retention.py"
SPEC = importlib.util.spec_from_file_location("export_retention", MODULE_PATH)
assert SPEC and SPEC.loader
export_retention = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(export_retention)


class ExportRetentionApiTests(unittest.TestCase):
    def http_error(self, code: int, body: bytes, retry_after: str | None = None):
        headers = {"Retry-After": retry_after} if retry_after else {}
        return urllib.error.HTTPError(
            "https://example.test/data",
            code,
            "error",
            headers,
            io.BytesIO(body),
        )

    @mock.patch.object(export_retention.time, "sleep")
    @mock.patch.object(export_retention.urllib.request, "urlopen")
    def test_api_get_retries_rate_limits(self, urlopen, sleep):
        urlopen.side_effect = [
            self.http_error(429, b'{"message":"slow down"}', "2"),
            io.BytesIO(b'{"ok":true}'),
        ]

        payload = export_retention.api_get("test", "secret")

        self.assertEqual(payload, {"ok": True})
        self.assertEqual(urlopen.call_count, 2)
        sleep.assert_called_once_with(2.0)

    @mock.patch.object(export_retention.time, "sleep")
    @mock.patch.object(export_retention.urllib.request, "urlopen")
    def test_api_get_does_not_retry_permanent_errors(self, urlopen, sleep):
        urlopen.side_effect = self.http_error(404, b'{"message":"missing"}')

        with self.assertRaisesRegex(RuntimeError, "HTTP 404"):
            export_retention.api_get("test", "secret")

        self.assertEqual(urlopen.call_count, 1)
        sleep.assert_not_called()

    @mock.patch.object(export_retention.time, "sleep")
    @mock.patch.object(export_retention, "api_get")
    def test_get_entry_paces_successful_reads(self, api_get, sleep):
        api_get.return_value = {"value": {"events": []}}

        value = export_retention.get_entry({"path": "example/path"}, "secret")

        self.assertEqual(value["events"], [])
        self.assertEqual(value["_entryPath"], "example/path")
        sleep.assert_called_once_with(export_retention.ENTRY_REQUEST_DELAY_SECONDS)

    def test_listed_session_number_decodes_entry_path(self):
        entry = {
            "path": "universes/1/data-stores/RetentionEvents_v1/scopes/global/"
            "entries/d20260721%2Fu42%2Fs17%2Fc00003"
        }

        self.assertEqual(export_retention.listed_session_number(entry), 17)

    def test_listed_session_number_rejects_non_event_path(self):
        self.assertIsNone(
            export_retention.listed_session_number(
                {"path": "entries/a20260721%2Fjabc"}
            )
        )


if __name__ == "__main__":
    unittest.main()
