import json
from datetime import date, timedelta

from django.contrib.auth import get_user_model
from django.test import TestCase

from apps.bookings.models import Booking
from apps.bookings.services.availability import get_operating_interval
from apps.cabins.models import Cabin
from apps.maintenance.models import MaintenanceRequest


class CreateBookingApiTests(TestCase):
    def setUp(self):
        self.user = get_user_model().objects.create_user(
            username='booking-api-user',
            password='test-password',
        )
        self.cabin = Cabin.objects.create(number='A-01')
        self.client.force_login(self.user)
        self.operating_interval = get_operating_interval(
            date.today() + timedelta(days=30)
        )
        self.starts_at = self.operating_interval.starts_at + timedelta(hours=1)
        self.ends_at = self.starts_at + timedelta(minutes=30)

    def _post_booking(self, **overrides):
        payload = {
            'cabin_id': self.cabin.pk,
            'starts_at': self.starts_at.isoformat(),
            'ends_at': self.ends_at.isoformat(),
        }
        payload.update(overrides)
        return self.client.post(
            '/api/bookings',
            data=json.dumps(payload),
            content_type='application/json',
        )

    def test_creates_booking_for_authenticated_user(self):
        response = self._post_booking()

        self.assertEqual(response.status_code, 201)
        booking = Booking.objects.get()
        self.assertEqual(booking.user, self.user)
        self.assertEqual(booking.cabin, self.cabin)
        self.assertEqual(response.json()['id'], booking.pk)

    def test_requires_authentication(self):
        self.client.logout()

        response = self._post_booking()

        self.assertEqual(response.status_code, 401)

    def test_rejects_invalid_json_and_non_object_payloads(self):
        for body in ('{', '[]'):
            with self.subTest(body=body):
                response = self.client.post(
                    '/api/bookings',
                    data=body,
                    content_type='application/json',
                )
                self.assertEqual(response.status_code, 400)

    def test_rejects_missing_or_invalid_cabin_id(self):
        for value in (None, 'not-an-id', True, 0):
            with self.subTest(value=value):
                payload = {
                    'starts_at': self.starts_at.isoformat(),
                    'ends_at': self.ends_at.isoformat(),
                }
                if value is not None:
                    payload['cabin_id'] = value
                response = self.client.post(
                    '/api/bookings',
                    data=json.dumps(payload),
                    content_type='application/json',
                )
                self.assertEqual(response.status_code, 400)

    def test_rejects_naive_datetimes(self):
        response = self._post_booking(
            starts_at=self.starts_at.replace(tzinfo=None).isoformat(),
        )

        self.assertEqual(response.status_code, 400)

    def test_rejects_unsupported_duration(self):
        response = self._post_booking(
            ends_at=(self.starts_at + timedelta(minutes=20)).isoformat(),
        )

        self.assertEqual(response.status_code, 400)

    def test_rejects_booking_outside_operating_hours(self):
        response = self._post_booking(
            starts_at=(self.operating_interval.ends_at - timedelta(minutes=15)).isoformat(),
            ends_at=(self.operating_interval.ends_at + timedelta(minutes=15)).isoformat(),
        )

        self.assertEqual(response.status_code, 400)

    def test_rejects_existing_booking_overlap(self):
        Booking.objects.create(
            user=self.user,
            cabin=self.cabin,
            starts_at=self.starts_at,
            ends_at=self.ends_at,
        )

        response = self._post_booking()

        self.assertEqual(response.status_code, 409)

    def test_rejects_inactive_cabin(self):
        self.cabin.is_active = False
        self.cabin.save(update_fields=['is_active'])

        response = self._post_booking()

        self.assertEqual(response.status_code, 409)

    def test_rejects_cabin_under_maintenance(self):
        MaintenanceRequest.objects.create(
            cabin=self.cabin,
            reported_by=self.user,
            description='Cabin is under repair.',
        )

        response = self._post_booking()

        self.assertEqual(response.status_code, 409)
