import hashlib
import io
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from fetch_real_backrooms_assets import download


class Response(io.BytesIO):
    status = 200
    headers = {"Content-Type": "image/jpeg"}

    def geturl(self):
        return "https://dl.polyhaven.org/test.jpg"


class IntegrityTests(unittest.TestCase):
    def setUp(self):
        self.original = b"original publisher data" * 20
        self.info = {"url": "https://dl.polyhaven.org/test.jpg",
                     "size": len(self.original), "md5": hashlib.md5(self.original).hexdigest()}

    def test_corrupt_response_is_discarded_before_retry(self):
        with tempfile.TemporaryDirectory() as directory:
            target = Path(directory) / "texture.jpg"
            with patch("fetch_real_backrooms_assets.urllib.request.urlopen",
                       side_effect=[Response(b"<html>CDN error</html>"), Response(self.original)]) as request, \
                 patch("fetch_real_backrooms_assets.time.sleep"):
                self.assertEqual(download(self.info, target), self.original)
            self.assertEqual(request.call_count, 2)
            self.assertEqual(target.read_bytes(), self.original)

    def test_same_size_wrong_digest_never_written(self):
        with tempfile.TemporaryDirectory() as directory:
            target = Path(directory) / "texture.jpg"
            wrong = b"x" * len(self.original)
            with patch("fetch_real_backrooms_assets.urllib.request.urlopen",
                       side_effect=lambda *a, **k: Response(wrong)) as request, \
                 patch("fetch_real_backrooms_assets.time.sleep"):
                with self.assertRaisesRegex(ValueError, "MD5 mismatch"):
                    download(self.info, target)
            self.assertEqual(request.call_count, 3)
            self.assertFalse(target.exists())

    def test_unapproved_redirect_is_rejected(self):
        response = Response(self.original)
        response.geturl = lambda: "https://unapproved.example/test.jpg"
        with tempfile.TemporaryDirectory() as directory, \
             patch("fetch_real_backrooms_assets.urllib.request.urlopen", return_value=response):
            with self.assertRaisesRegex(ValueError, "redirect host"):
                download(self.info, Path(directory) / "texture.jpg")


if __name__ == "__main__":
    unittest.main()
