from datetime import date, timedelta

from django.contrib.auth import get_user_model
from django.test import TestCase

from apps.bookings.models import Booking
from apps.bookings.services.availability import get_operating_interval
from apps.cabins.models import Cabin
from apps.maintenance.models import MaintenanceRequest


class AvailableCabinsApiTests(TestCase):
    def setUp(self):
        self.user = get_user_model().objects.create_user(username='api-user')
        self.cabin = Cabin.objects.create(number='A-01')
        self.service_date = date.today() + timedelta(days=30)

    def test_requires_an_iso_date(self):
        for value in ('', '2026/11/15', '2026-02-30'):
            with self.subTest(value=value):
                response = self.client.get('/api/cabins/available', {'date': value})

                self.assertEqual(response.status_code, 400)
                self.assertEqual(
                    response.json(),
                    {'detail': 'date must be provided in YYYY-MM-DD format.'},
                )

    def test_returns_only_active_cabins_with_available_intervals(self):
        inactive = Cabin.objects.create(number='A-02', is_active=False)
        blocked_start = get_operating_interval(self.service_date).starts_at
        Booking.objects.create(
            user=self.user,
            cabin=self.cabin,
            starts_at=blocked_start,
            ends_at=blocked_start + timedelta(minutes=30),
        )
        MaintenanceRequest.objects.create(
            cabin=inactive,
            reported_by=self.user,
            description='Unavailable cabin.',
        )

        response = self.client.get(
            '/api/cabins/available',
            {'date': self.service_date.isoformat()},
        )

        self.assertEqual(response.status_code, 200)
        payload = response.json()
        self.assertEqual(payload['date'], self.service_date.isoformat())
        self.assertEqual(payload['timezone'], 'Europe/Moscow')
        self.assertEqual(len(payload['cabins']), 1)
        self.assertEqual(payload['cabins'][0]['id'], self.cabin.pk)
        self.assertEqual(payload['cabins'][0]['number'], self.cabin.number)
        self.assertEqual(
            payload['cabins'][0]['available_intervals'][0]['starts_at'],
            (blocked_start + timedelta(minutes=30)).isoformat(),
        )

    def test_does_not_return_cabins_blocked_by_maintenance(self):
        MaintenanceRequest.objects.create(
            cabin=self.cabin,
            reported_by=self.user,
            description='Needs repair.',
        )

        response = self.client.get(
            '/api/cabins/available',
            {'date': self.service_date.isoformat()},
        )

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()['cabins'], [])

    def test_rejects_non_get_methods(self):
        response = self.client.post('/api/cabins/available', {'date': '2026-11-15'})

        self.assertEqual(response.status_code, 405)
