import io
import struct
import tempfile
import unittest
from pathlib import Path

from PIL import Image
from optimize_glb import optimize, read_glb, write_glb


class GLBOptimizationTests(unittest.TestCase):
    def test_embedded_texture_resize_preserves_geometry_rig_and_alpha(self):
        pixels = Image.new("RGBA", (4096, 2048), (80, 120, 160, 96))
        encoded = io.BytesIO()
        pixels.save(encoded, "PNG")
        vertices = struct.pack("<9f", 0, 0, 0, 1, 0, 0, 0, 1, 0)
        source = vertices + encoded.getvalue()
        document = {"asset": {"version": "2.0"}, "buffers": [{"byteLength": len(source)}],
                    "bufferViews": [{"buffer": 0, "byteLength": len(vertices)},
                                    {"buffer": 0, "byteOffset": len(vertices), "byteLength": len(encoded.getvalue())}],
                    "accessors": [{"bufferView": 0, "componentType": 5126, "count": 3, "type": "VEC3"}],
                    "images": [{"bufferView": 1, "mimeType": "image/png"}],
                    "skins": [{"joints": [0]}], "animations": [{"name": "Walk"}],
                    "nodes": [{"name": "Root"}]}
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "pine_cluster.glb"
            path.write_bytes(write_glb(document, source))
            report = optimize(path)
            result, data = read_glb(path.read_bytes())
            self.assertEqual(result["skins"], document["skins"])
            self.assertEqual(result["animations"], document["animations"])
            self.assertEqual(result["accessors"], document["accessors"])
            v = result["bufferViews"][0]
            self.assertEqual(data[v["byteOffset"]:v["byteOffset"] + v["byteLength"]], vertices)
            image = result["bufferViews"][1]
            with Image.open(io.BytesIO(data[image["byteOffset"]:image["byteOffset"] + image["byteLength"]])) as texture:
                self.assertEqual(texture.size, (1024, 512))
                self.assertEqual(texture.getpixel((100, 100))[3], 96)
            self.assertLess(report["estimated_rgba_mips_after"], report["estimated_rgba_mips_before"])
            self.assertTrue(all(v["byteOffset"] % 4 == 0 for v in result["bufferViews"]))

    def test_duplicate_views_share_aligned_bytes_without_changing_indices(self):
        document = {"asset": {"version": "2.0"}, "buffers": [{"byteLength": 9}],
                    "bufferViews": [{"buffer": 0, "byteLength": 3},
                                    {"buffer": 0, "byteOffset": 3, "byteLength": 3}],
                    "accessors": [{"bufferView": 1, "componentType": 5121, "type": "SCALAR", "count": 3}]}
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "rifle.glb"
            path.write_bytes(write_glb(document, b"abcabcXYZ"))
            optimize(path)
            result, data = read_glb(path.read_bytes())
            self.assertEqual(result["bufferViews"][0]["byteOffset"], result["bufferViews"][1]["byteOffset"])
            self.assertEqual(result["accessors"][0]["bufferView"], 1)
            self.assertEqual(data[:3], b"abc")

    def test_rejects_invalid_container(self):
        with self.assertRaises((ValueError, struct.error)):
            read_glb(b"invalid")


if __name__ == "__main__":
    unittest.main()
