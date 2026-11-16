from datetime import date, timedelta

from django.contrib.auth import get_user_model
from django.test import TestCase
from rest_framework_simplejwt.tokens import RefreshToken

from apps.bookings.models import Booking
from apps.bookings.services.availability import get_operating_interval
from apps.cabins.models import Cabin


class MyBookingsApiTests(TestCase):
    def setUp(self):
        user_model = get_user_model()
        self.user = user_model.objects.create_user(username='my-bookings-user')
        self.other_user = user_model.objects.create_user(username='other-user')
        self.cabin = Cabin.objects.create(number='LIST-01')
        self.client.defaults['HTTP_AUTHORIZATION'] = (
            f'Bearer {RefreshToken.for_user(self.user).access_token}'
        )
        service_date = date.today() + timedelta(days=30)
        self.first_start = (
            get_operating_interval(service_date).starts_at + timedelta(hours=1)
        )

    def test_lists_only_current_users_bookings_in_expected_shape(self):
        first = Booking.objects.create(
            user=self.user,
            cabin=self.cabin,
            starts_at=self.first_start,
            ends_at=self.first_start + timedelta(minutes=30),
        )
        second_start = self.first_start + timedelta(hours=1)
        second = Booking.objects.create(
            user=self.user,
            cabin=Cabin.objects.create(number='LIST-02'),
            starts_at=second_start,
            ends_at=second_start + timedelta(minutes=15),
        )
        Booking.objects.create(
            user=self.other_user,
            cabin=self.cabin,
            starts_at=self.first_start + timedelta(hours=2),
            ends_at=self.first_start + timedelta(hours=2, minutes=15),
        )

        response = self.client.get('/api/bookings')

        self.assertEqual(response.status_code, 200)
        self.assertEqual(
            response.json(),
            {
                'bookings': [
                    {
                        'id': first.pk,
                        'cabin_number': 'LIST-01',
                        'starts_at': self.first_start.isoformat(),
                        'ends_at': (
                            self.first_start + timedelta(minutes=30)
                        ).isoformat(),
                    },
                    {
                        'id': second.pk,
                        'cabin_number': 'LIST-02',
                        'starts_at': second_start.isoformat(),
                        'ends_at': (
                            second_start + timedelta(minutes=15)
                        ).isoformat(),
                    },
                ],
            },
        )

    def test_returns_empty_bookings_for_user_without_bookings(self):
        response = self.client.get('/api/bookings')

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json(), {'bookings': []})

    def test_requires_authentication(self):
        self.client.logout()
        self.client.defaults.pop('HTTP_AUTHORIZATION', None)

        response = self.client.get('/api/bookings')

        self.assertEqual(response.status_code, 401)

    def test_rejects_invalid_bearer_token(self):
        self.client.defaults['HTTP_AUTHORIZATION'] = 'Bearer invalid-token'

        response = self.client.get('/api/bookings')

        self.assertEqual(response.status_code, 401)

    def test_rejects_non_get_and_non_post_methods(self):
        response = self.client.delete('/api/bookings')

        self.assertEqual(response.status_code, 405)
