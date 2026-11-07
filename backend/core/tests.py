from django.test import SimpleTestCase
from django.urls import reverse


class HealthTests(SimpleTestCase):
    def test_health_contract_without_database_or_provider(self):
        response = self.client.get(reverse("health"))
        self.assertEqual(response.status_code, 200)
        self.assertEqual(
            response.json(), {"status": "ok", "service": "musicapp", "api_version": "v1"}
        )
        self.assertIn("no-store", response["Cache-Control"])

    def test_health_does_not_accept_mutations(self):
        self.assertEqual(self.client.post(reverse("health")).status_code, 405)

    def test_unimplemented_content_is_not_reported_as_available(self):
        self.assertEqual(self.client.get("/api/v1/tracks/1/lyrics/").status_code, 404)
