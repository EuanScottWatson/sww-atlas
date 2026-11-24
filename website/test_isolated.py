"""
Test the website API with an isolated database and empty import fixture.
"""

import importlib.util
import json
import tempfile
import threading
import unittest
import urllib.request

from pathlib import Path
from shutil import copytree

spec = importlib.util.spec_from_file_location("atlas_server", Path(__file__).with_name("server.py"))
server = importlib.util.module_from_spec(spec)
spec.loader.exec_module(server)


class AtlasAPITests(unittest.TestCase):
    """
    Exercise trip, journey and calendar event persistence independently of production.
    """

    @classmethod
    def setUpClass(cls):
        """
        Start an HTTP server using a temporary database and clean import fixtures.
        """
        cls.temp = tempfile.TemporaryDirectory()
        root = Path(cls.temp.name)
        copytree(Path(__file__).with_name("import-example"), root / "import")
        server.ROOT = root
        server.DATA = root / "data"
        server.DATA.mkdir()
        server.PHOTOS = root / "photos"
        server.init()
        cls.http = server.ThreadingHTTPServer(("127.0.0.1", 0), server.Handler)
        cls.thread = threading.Thread(target=cls.http.serve_forever, daemon=True)
        cls.thread.start()
        cls.base = f"http://127.0.0.1:{cls.http.server_port}"

    @classmethod
    def tearDownClass(cls):
        """
        Stop the test server and remove temporary data.
        """
        cls.http.shutdown()
        cls.http.server_close()
        cls.thread.join()
        cls.temp.cleanup()

    def request(self, path: str, body: dict | None = None) -> dict:
        """
        Send a JSON request to the isolated test server.
        """
        payload = json.dumps(body).encode() if body is not None else None
        request = urllib.request.Request(
            self.base + path,
            data=payload,
            headers={"Content-Type": "application/json"} if body is not None else {},
        )
        with urllib.request.urlopen(request, timeout=5) as response:
            return json.load(response)

    def test_events_trips_and_journeys(self):
        """
        Save, update and retrieve entries without touching the live server.
        """
        event = self.request(
            "/api/save",
            {
                "kind": "events",
                "record": {
                    "name": "Example concert",
                    "start": "2026-05-02",
                    "end": "2026-05-02",
                    "notes": "Example",
                },
            },
        )
        trip = self.request(
            "/api/save",
            {
                "kind": "trips",
                "record": {
                    "name": "Example trip",
                    "start": "2026-05-01",
                    "end": "2026-05-04",
                    "year": 2026,
                    "travel": 15,
                    "accommodation": 25,
                    "total": 40,
                    "country": "France",
                    "pins": [{"name": "Example place", "lat": 48.8, "lon": 2.3}],
                },
            },
        )
        trip["notes"] = "Updated"
        saved = self.request("/api/save", {"kind": "trips", "id": trip["id"], "record": trip})
        self.assertEqual(saved["pins"], trip["pins"])
        group = "journey-test-example"
        rows = [
            {
                "name": name,
                "start": "2027-02-01",
                "end": "2027-02-02",
                "year": 2027,
                "group": group,
                "journey_name": "Example journey",
                "shared_fields": ["travel"] if index == 0 else [],
                "travel": 20 if index == 0 else None,
                "accommodation": 10,
                "total": 30 if index == 0 else 10,
            }
            for index, name in enumerate(("First stop", "Second stop"))
        ]
        journey = self.request("/api/save-journey", {"group": group, "records": rows})
        self.assertEqual(len(journey["trips"]), 2)
        data = self.request("/api/data")
        self.assertEqual(data["events"][0]["id"], event["id"])
        self.assertEqual(len(data["trips"]), 3)
        self.request("/api/delete", {"kind": "events", "id": event["id"]})
        self.assertEqual(self.request("/api/data")["events"], [])
        annual = {"total": 123.45, "leave_left": 4, "notes": "Preserved note"}
        self.request("/api/summary", {"year": 2026, "values": annual})
        self.assertEqual(self.request("/api/data")["summaries"]["2026"], annual)


if __name__ == "__main__":
    unittest.main()
