"""Offline tests: original-license and signed-download guardrails. No tokens or HTTP."""
import io
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
from urllib.error import HTTPError
from zipfile import ZipFile

import fetch_sketchfab_cast as cast


class SketchfabContractTests(unittest.TestCase):
    def setUp(self):
        self.valid = {"license": {"url": "https://creativecommons.org/licenses/by/4.0/", "label": "Attribution"},
                      "isDownloadable": True, "user": {"username": "Speed12"}}

    def test_only_commercial_cc_by_and_authorized_download(self):
        cast.check_metadata(self.valid, "Smiler")
        for url in ("https://creativecommons.org/licenses/by-nc/4.0/",
                    "https://creativecommons.org/licenses/by-nd/4.0/"):
            with self.subTest(url=url), self.assertRaises(RuntimeError):
                cast.check_metadata({**self.valid, "license": {"url": url}}, "Smiler")
        with self.assertRaises(RuntimeError):
            cast.check_metadata({**self.valid, "isDownloadable": False}, "Smiler")
        with self.assertRaises(RuntimeError):
            cast.check_metadata({**self.valid, "license": {}}, "Smiler")

    def test_original_author_identity_required(self):
        cast.check_creator(self.valid, cast.ASSETS["smiler"])
        with self.assertRaisesRegex(RuntimeError, "creator"):
            cast.check_creator({**self.valid, "user": {"username": "DifferentArtist"}}, cast.ASSETS["smiler"])

    def test_download_uses_oauth_bearer_without_substitutes(self):
        response = {"gltf": {"url": "https://signed.example.org/model.zip"}}
        with patch.object(cast, "json_get", return_value=response) as getter:
            self.assertEqual(cast.download_authorized("demo-id", "TEST_ONLY_TOKEN"), response)
            getter.assert_called_once_with(cast.API + "demo-id/download", "Bearer TEST_ONLY_TOKEN")

    def test_expired_token_fails_closed_without_printing_secret(self):
        errors = [HTTPError("https://example.org", 401, "unauthorized", {}, None),
                  HTTPError("https://example.org", 500, "denied", {}, None)]
        with patch.object(cast, "json_get", side_effect=errors):
            with self.assertRaises(RuntimeError) as caught:
                cast.download_authorized("demo-id", "NEVER_PRINT_THIS_TOKEN")
        message = str(caught.exception)
        self.assertIn("Bearer=401", message)
        self.assertIn("Token=500", message)
        self.assertNotIn("NEVER_PRINT_THIS_TOKEN", message)

    def test_zipped_gltf_is_read_without_unsafe_paths(self):
        with tempfile.TemporaryDirectory() as tmp:
            good = io.BytesIO()
            with ZipFile(good, "w") as archive:
                archive.writestr("scene/main.gltf", '{"asset":{"version":"2.0"}}')
            result = cast.read_gltf_archive(good.getvalue(), Path(tmp))
            self.assertEqual(result.name, "main.gltf")
        with tempfile.TemporaryDirectory() as tmp:
            bad = io.BytesIO()
            with ZipFile(bad, "w") as archive:
                archive.writestr("../escaped.gltf", "not safe")
            with self.assertRaisesRegex(RuntimeError, "Unsafe path"):
                cast.read_gltf_archive(bad.getvalue(), Path(tmp))


if __name__ == "__main__":
    unittest.main()
