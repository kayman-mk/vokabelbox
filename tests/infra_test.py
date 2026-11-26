import json
import os
import re
import unittest
import urllib.error
import urllib.request
import uuid
from http.cookiejar import CookieJar

BASE_URL = os.environ.get("API_BASE_URL", "http://localhost:18081").rstrip("/")
USERNAME = os.environ.get("DEV_ADMIN_USERNAME", "test")
PASSWORD = os.environ.get("DEV_ADMIN_PASSWORD", "test")
UUID_PATTERN = re.compile(r"^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$")


def request(path, method="GET", body=None, opener=None):
    data = None if body is None else json.dumps(body).encode("utf-8")
    headers = {} if data is None else {"Content-Type": "application/json"}
    req = urllib.request.Request(BASE_URL + path, data=data, headers=headers, method=method)
    client = opener or urllib.request.build_opener()
    try:
        response = client.open(req, timeout=10)
    except urllib.error.HTTPError as error:
        response = error
    raw = response.read()
    content_type = response.headers.get("Content-Type", "")
    payload = json.loads(raw) if "json" in content_type and raw else None
    return response.status, raw, payload


class RunningInfrastructureTests(unittest.TestCase):
    def test_site_and_database_health(self):
        status, raw, _ = request("/")
        self.assertEqual(status, 200)
        self.assertIn(b"VokabelBox", raw)

        status, _, payload = request("/api/v1/health")
        self.assertEqual(status, 200)
        self.assertEqual(payload, {"status": "ok"})

        status, _, _ = request("/api/v1/auth/logout", "POST", {})
        self.assertEqual(status, 401)

        client = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(CookieJar()))
        status, _, _ = request(
            "/api/v1/auth/login", "POST", {"username": USERNAME, "password": PASSWORD}, client
        )
        self.assertEqual(status, 200)

        status, _, payload = request("/api/v1/health", opener=client)
        self.assertEqual(status, 200)
        self.assertEqual(payload, {"status": "ok"})

    def test_login_and_vocabulary_flow(self):
        client = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(CookieJar()))

        status, _, payload = request(
            "/api/v1/auth/login", "POST", {"username": "invalid", "password": "invalid"}, client
        )
        self.assertEqual(status, 401)
        self.assertIn("error", payload)

        status, _, user = request(
            "/api/v1/auth/login", "POST", {"username": USERNAME, "password": PASSWORD}, client
        )
        self.assertEqual(status, 200)
        self.assertRegex(user["id"], UUID_PATTERN)

        status, _, current_user = request("/api/v1/auth/me", opener=client)
        self.assertEqual(status, 200)
        self.assertEqual(current_user["id"], user["id"])

        list_name = f"Infrastructure test {uuid.uuid4()}"
        status, _, vocabulary_set = request("/api/v1/sets", "POST", {"name": list_name}, client)
        self.assertEqual(status, 201)
        self.assertRegex(vocabulary_set["id"], UUID_PATTERN)
        self.assertEqual(vocabulary_set["wordCount"], 0)

        status, _, empty_words = request(f"/api/v1/sets/{vocabulary_set['id']}/words", opener=client)
        self.assertEqual(status, 200)
        self.assertEqual(empty_words["words"], [])

        word = {"prompt": "house", "answer": "Haus"}
        status, _, created_word = request(
            f"/api/v1/sets/{vocabulary_set['id']}/words", "POST", word, client
        )
        self.assertEqual(status, 201)
        self.assertRegex(created_word["id"], UUID_PATTERN)
        self.assertEqual(created_word["prompt"], word["prompt"])
        self.assertEqual(created_word["answer"], word["answer"])

        status, _, stored_words = request(f"/api/v1/sets/{vocabulary_set['id']}/words", opener=client)
        self.assertEqual(status, 200)
        self.assertEqual(len(stored_words["words"]), 1)
        self.assertEqual(stored_words["words"][0]["prompt"], word["prompt"])
        self.assertEqual(stored_words["words"][0]["answer"], word["answer"])

        import_path = f"/api/v1/sets/{vocabulary_set['id']}/imports"
        status, _, payload = request(
            import_path,
            "POST",
            {"rows": [{"prompt": "tree", "answer": "Baum"}, {"prompt": "", "answer": "invalid"}]},
            client,
        )
        self.assertEqual(status, 422)
        self.assertIn("invalidRows", payload)
        status, _, unchanged_words = request(f"/api/v1/sets/{vocabulary_set['id']}/words", opener=client)
        self.assertEqual(status, 200)
        self.assertEqual(len(unchanged_words["words"]), 1)

        status, _, result = request(
            import_path,
            "POST",
            {"rows": [
                {"prompt": "house", "answer": "HAUS"},
                {"prompt": "Tree", "answer": "Baum"},
                {"prompt": "tree", "answer": "baum"},
            ]},
            client,
        )
        self.assertEqual(status, 201)
        self.assertEqual(result, {"created": 1, "skippedDuplicates": 2})
        status, _, imported_words = request(f"/api/v1/sets/{vocabulary_set['id']}/words", opener=client)
        self.assertEqual(status, 200)
        original_word = next(item for item in imported_words["words"] if item["id"] == created_word["id"])
        self.assertEqual(original_word["answer"], "Haus")

        status, _, sets = request("/api/v1/sets", opener=client)
        self.assertEqual(status, 200)
        saved_set = next(item for item in sets["sets"] if item["id"] == vocabulary_set["id"])
        self.assertEqual(saved_set["wordCount"], 2)

    def test_fsrs_statistics_are_isolated_by_box_and_direction(self):
        client = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(CookieJar()))
        status, _, user = request(
            "/api/v1/auth/login", "POST", {"username": USERNAME, "password": PASSWORD}, client
        )
        self.assertEqual(status, 200)

        def make_box_and_word(name):
            status, _, box = request("/api/v1/sets", "POST", {"name": name}, client)
            self.assertEqual(status, 201)
            status, _, word = request(
                f"/api/v1/sets/{box['id']}/words", "POST", {"prompt": "house", "answer": "Haus"}, client
            )
            self.assertEqual(status, 201)
            return box, word

        box_one, word_one = make_box_and_word(f"FSRS stats one {uuid.uuid4()}")
        box_two, _ = make_box_and_word(f"FSRS stats two {uuid.uuid4()}")
        forward = "foreign_to_local"
        reverse = "local_to_foreign"

        status, _, _ = request(f"/api/v1/sets/{box_one['id']}/statistics?method=fsrs&direction={forward}")
        self.assertEqual(status, 401)

        def statistics(box_id, direction):
            status, _, payload = request(
                f"/api/v1/sets/{box_id}/statistics?method=fsrs&direction={direction}", opener=client
            )
            self.assertEqual(status, 200)
            return payload

        initial = statistics(box_one["id"], forward)
        self.assertEqual(initial["method"], "fsrs")
        self.assertEqual(initial["direction"], forward)
        self.assertEqual(initial["progress"]["total"], 1)
        self.assertEqual(initial["progress"]["repetitions"], 0)
        self.assertEqual(initial["reviews"]["total"], 0)

        status, _, review = request(
            f"/api/v1/sets/{box_one['id']}/study/reviews?method=fsrs&direction={forward}",
            "POST", {"vocabularyId": word_one["id"], "rating": 3, "userId": "00000000-0000-4000-8000-000000000000"}, client,
        )
        self.assertEqual(status, 200)
        self.assertGreaterEqual(review["intervalDays"], 1)

        reviewed = statistics(box_one["id"], forward)
        self.assertEqual(reviewed["progress"]["repetitions"], 1)
        self.assertEqual(reviewed["progress"]["reviewed_count"], 1)
        self.assertEqual(reviewed["reviews"]["total"], 1)
        self.assertEqual(reviewed["reviews"]["good_count"], 1)
        self.assertEqual(sum(day["reviews"] for day in reviewed["dailyActivity"]), 1)
        self.assertEqual(statistics(box_one["id"], reverse)["reviews"]["total"], 0)
        self.assertEqual(statistics(box_two["id"], forward)["reviews"]["total"], 0)


if __name__ == "__main__":
    unittest.main(verbosity=2)
