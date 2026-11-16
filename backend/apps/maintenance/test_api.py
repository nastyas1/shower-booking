import json
from datetime import date, timedelta

from django.contrib.auth import get_user_model
from django.test import TestCase

from apps.bookings.models import Booking
from apps.bookings.services.availability import get_operating_interval
from apps.cabins.models import Cabin
from apps.maintenance.models import MaintenanceRequest


class CreateMaintenanceRequestApiTests(TestCase):
    def setUp(self):
        self.user = get_user_model().objects.create_user(
            username='maintenance-api-user',
            password='test-password',
        )
        self.cabin = Cabin.objects.create(number='M-01')
        self.client.force_login(self.user)
        operating_interval = get_operating_interval(date.today() + timedelta(days=30))
        self.starts_at = operating_interval.starts_at + timedelta(hours=1)
        self.ends_at = self.starts_at + timedelta(minutes=30)

    def _post_request(self, **overrides):
        payload = {
            'cabin_id': self.cabin.pk,
            'description': 'Shower temperature control is broken.',
        }
        payload.update(overrides)
        return self.client.post(
            '/api/maintenance',
            data=json.dumps(payload),
            content_type='application/json',
        )

    def test_creates_open_request_for_authenticated_user(self):
        response = self._post_request()

        self.assertEqual(response.status_code, 201)
        maintenance_request = MaintenanceRequest.objects.get()
        self.assertEqual(maintenance_request.cabin, self.cabin)
        self.assertEqual(maintenance_request.reported_by, self.user)
        self.assertEqual(
            maintenance_request.description,
            'Shower temperature control is broken.',
        )
        self.assertEqual(maintenance_request.status, MaintenanceRequest.Status.OPEN)
        self.assertEqual(response.json()['id'], maintenance_request.pk)
        self.assertEqual(response.json()['cabin_id'], self.cabin.pk)

    def test_requires_authentication(self):
        self.client.logout()

        response = self._post_request()

        self.assertEqual(response.status_code, 401)
        self.assertFalse(MaintenanceRequest.objects.exists())

    def test_rejects_invalid_json_and_non_object_payloads(self):
        for body in ('{', '[]'):
            with self.subTest(body=body):
                response = self.client.post(
                    '/api/maintenance',
                    data=body,
                    content_type='application/json',
                )
                self.assertEqual(response.status_code, 400)

    def test_rejects_invalid_cabin_ids(self):
        for value in (None, 'not-an-id', True, 0, -1):
            with self.subTest(value=value):
                response = self._post_request(cabin_id=value)
                self.assertEqual(response.status_code, 400)
                self.assertFalse(MaintenanceRequest.objects.exists())

    def test_returns_not_found_for_unknown_cabin(self):
        response = self._post_request(cabin_id=self.cabin.pk + 100)

        self.assertEqual(response.status_code, 404)
        self.assertFalse(MaintenanceRequest.objects.exists())

    def test_requires_non_empty_description(self):
        for value in (None, 42, '', '  '):
            with self.subTest(value=value):
                response = self._post_request(description=value)
                self.assertEqual(response.status_code, 400)
                self.assertFalse(MaintenanceRequest.objects.exists())

    def test_trims_description_and_rejects_non_post_methods(self):
        response = self._post_request(description='  Leaking pipe.  ')

        self.assertEqual(response.status_code, 201)
        self.assertEqual(
            MaintenanceRequest.objects.get().description,
            'Leaking pipe.',
        )

        response = self.client.get('/api/maintenance')
        self.assertEqual(response.status_code, 405)

    def test_new_request_prevents_booking_the_cabin(self):
        response = self._post_request()
        self.assertEqual(response.status_code, 201)

        response = self.client.post(
            '/api/bookings',
            data=json.dumps({
                'cabin_id': self.cabin.pk,
                'starts_at': self.starts_at.isoformat(),
                'ends_at': self.ends_at.isoformat(),
            }),
            content_type='application/json',
        )

        self.assertEqual(response.status_code, 409)
        self.assertFalse(Booking.objects.exists())
