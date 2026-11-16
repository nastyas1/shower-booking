from datetime import date, timedelta

from django.contrib.auth import get_user_model
from django.test import TestCase
from rest_framework_simplejwt.tokens import RefreshToken

from apps.bookings.models import Booking
from apps.bookings.services.availability import get_operating_interval
from apps.cabins.models import Cabin


class CancelBookingApiTests(TestCase):
    def setUp(self):
        user_model = get_user_model()
        self.user = user_model.objects.create_user(username='cancel-user')
        self.other_user = user_model.objects.create_user(username='other-cancel-user')
        self.cabin = Cabin.objects.create(number='CANCEL-01')
        starts_at = (
            get_operating_interval(date.today() + timedelta(days=30)).starts_at
            + timedelta(hours=1)
        )
        self.booking = Booking.objects.create(
            user=self.user,
            cabin=self.cabin,
            starts_at=starts_at,
            ends_at=starts_at + timedelta(minutes=30),
        )
        self.client.defaults['HTTP_AUTHORIZATION'] = (
            f'Bearer {RefreshToken.for_user(self.user).access_token}'
        )

    def test_owner_can_cancel_booking_and_receives_empty_204_response(self):
        response = self.client.delete(f'/api/bookings/{self.booking.pk}')

        self.assertEqual(response.status_code, 204)
        self.assertEqual(response.content, b'')
        self.assertFalse(Booking.objects.filter(pk=self.booking.pk).exists())
        self.assertEqual(self.client.get('/api/bookings').json(), {'bookings': []})

    def test_cannot_cancel_another_users_booking(self):
        self.booking.user = self.other_user
        self.booking.save(update_fields=['user'])

        response = self.client.delete(f'/api/bookings/{self.booking.pk}')

        self.assertEqual(response.status_code, 404)
        self.assertTrue(Booking.objects.filter(pk=self.booking.pk).exists())

    def test_returns_not_found_for_unknown_booking(self):
        response = self.client.delete('/api/bookings/999999')

        self.assertEqual(response.status_code, 404)

    def test_requires_authentication(self):
        self.client.defaults.pop('HTTP_AUTHORIZATION', None)

        response = self.client.delete(f'/api/bookings/{self.booking.pk}')

        self.assertEqual(response.status_code, 401)
        self.assertTrue(Booking.objects.filter(pk=self.booking.pk).exists())

    def test_rejects_invalid_bearer_token(self):
        self.client.defaults['HTTP_AUTHORIZATION'] = 'Bearer invalid-token'

        response = self.client.delete(f'/api/bookings/{self.booking.pk}')

        self.assertEqual(response.status_code, 401)
        self.assertTrue(Booking.objects.filter(pk=self.booking.pk).exists())

    def test_rejects_non_delete_methods(self):
        response = self.client.post(f'/api/bookings/{self.booking.pk}')

        self.assertEqual(response.status_code, 405)
        self.assertTrue(Booking.objects.filter(pk=self.booking.pk).exists())
