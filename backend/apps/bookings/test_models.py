from datetime import timedelta

from django.contrib.auth import get_user_model
from django.core.exceptions import ValidationError
from django.db import IntegrityError, transaction
from django.db.models.deletion import ProtectedError
from django.test import TestCase
from django.utils import timezone

from apps.bookings.models import Booking
from apps.cabins.models import Cabin


class BookingModelTests(TestCase):
    def setUp(self):
        self.user = get_user_model().objects.create_user(username='booking-user')
        self.cabin = Cabin.objects.create(number='A-01')
        self.starts_at = timezone.now().replace(second=0, microsecond=0)

    def test_booking_links_user_and_cabin(self):
        booking = Booking.objects.create(
            user=self.user,
            cabin=self.cabin,
            starts_at=self.starts_at,
            ends_at=self.starts_at + timedelta(minutes=30),
        )

        self.assertEqual(booking.user, self.user)
        self.assertEqual(booking.cabin, self.cabin)
        self.assertEqual(self.user.bookings.get(), booking)
        self.assertEqual(self.cabin.bookings.get(), booking)
        self.assertIsNotNone(booking.created_at)

    def test_clean_accepts_supported_durations(self):
        for duration in (15, 30, 45):
            with self.subTest(duration=duration):
                booking = Booking(
                    user=self.user,
                    cabin=self.cabin,
                    starts_at=self.starts_at,
                    ends_at=self.starts_at + timedelta(minutes=duration),
                )
                booking.clean()

    def test_clean_rejects_unsupported_duration(self):
        booking = Booking(
            user=self.user,
            cabin=self.cabin,
            starts_at=self.starts_at,
            ends_at=self.starts_at + timedelta(minutes=20),
        )

        with self.assertRaisesMessage(
            ValidationError,
            'Booking duration must be 15, 30, or 45 minutes.',
        ):
            booking.clean()

    def test_database_rejects_end_time_not_after_start(self):
        with self.assertRaises(IntegrityError):
            with transaction.atomic():
                Booking.objects.create(
                    user=self.user,
                    cabin=self.cabin,
                    starts_at=self.starts_at,
                    ends_at=self.starts_at,
                )

    def test_linked_user_and_cabin_cannot_be_deleted(self):
        Booking.objects.create(
            user=self.user,
            cabin=self.cabin,
            starts_at=self.starts_at,
            ends_at=self.starts_at + timedelta(minutes=15),
        )

        with self.assertRaises(ProtectedError):
            self.user.delete()
        with self.assertRaises(ProtectedError):
            self.cabin.delete()
