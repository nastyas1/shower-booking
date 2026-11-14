from datetime import date, timedelta

from django.contrib.auth import get_user_model
from django.test import TestCase

from apps.bookings.models import Booking
from apps.bookings.services.availability import get_operating_interval
from apps.cabins.models import Cabin


class CancelBookingApiTests(TestCase):
    def setUp(self):
        user_model = get_user_model()
        self.owner = user_model.objects.create_user(
            username='booking-owner',
            password='test-password',
        )
        self.other_user = user_model.objects.create_user(
            username='other-user',
            password='test-password',
        )
        self.cabin = Cabin.objects.create(number='C-01')
        starts_at = get_operating_interval(
            date.today() + timedelta(days=30)
        ).starts_at + timedelta(hours=1)
        self.booking = Booking.objects.create(
            user=self.owner,
            cabin=self.cabin,
            starts_at=starts_at,
            ends_at=starts_at + timedelta(minutes=15),
        )

    def test_owner_can_cancel_booking(self):
        self.client.force_login(self.owner)

        response = self.client.delete(f'/api/bookings/{self.booking.pk}')

        self.assertEqual(response.status_code, 204)
        self.assertFalse(Booking.objects.filter(pk=self.booking.pk).exists())

    def test_another_user_cannot_cancel_booking(self):
        self.client.force_login(self.other_user)

        response = self.client.delete(f'/api/bookings/{self.booking.pk}')

        self.assertEqual(response.status_code, 404)
        self.assertTrue(Booking.objects.filter(pk=self.booking.pk).exists())

    def test_requires_authentication(self):
        response = self.client.delete(f'/api/bookings/{self.booking.pk}')

        self.assertEqual(response.status_code, 401)
        self.assertTrue(Booking.objects.filter(pk=self.booking.pk).exists())

    def test_returns_not_found_for_unknown_booking(self):
        self.client.force_login(self.owner)

        response = self.client.delete('/api/bookings/999999')

        self.assertEqual(response.status_code, 404)

    def test_only_accepts_delete(self):
        self.client.force_login(self.owner)

        response = self.client.get(f'/api/bookings/{self.booking.pk}')

        self.assertEqual(response.status_code, 405)
