from datetime import date, datetime, timedelta
from zoneinfo import ZoneInfo

from django.contrib.auth import get_user_model
from django.test import SimpleTestCase, TestCase

from apps.bookings.models import Booking
from apps.bookings.services.availability import (
    TimeInterval,
    get_available_intervals,
    get_operating_interval,
    subtract_intervals,
)
from apps.cabins.models import Cabin
from apps.maintenance.models import MaintenanceRequest


class SubtractIntervalsTests(SimpleTestCase):
    def setUp(self):
        timezone = ZoneInfo('Europe/Moscow')
        self.starts_at = datetime(2026, 11, 15, 6, tzinfo=timezone)
        self.ends_at = datetime(2026, 11, 16, 4, tzinfo=timezone)

    def test_returns_full_period_when_no_intervals_are_blocked(self):
        self.assertEqual(
            subtract_intervals(self.starts_at, self.ends_at, []),
            [TimeInterval(self.starts_at, self.ends_at)],
        )

    def test_subtracts_a_booking_inside_the_operating_period(self):
        blocked_start = self.starts_at + timedelta(hours=2)
        blocked_end = blocked_start + timedelta(minutes=30)

        self.assertEqual(
            subtract_intervals(
                self.starts_at,
                self.ends_at,
                [(blocked_start, blocked_end)],
            ),
            [
                TimeInterval(self.starts_at, blocked_start),
                TimeInterval(blocked_end, self.ends_at),
            ],
        )

    def test_handles_overlapping_and_adjacent_bookings(self):
        first = self.starts_at + timedelta(hours=1)
        second = first + timedelta(minutes=30)
        third = second + timedelta(minutes=15)
        last = third + timedelta(minutes=30)

        self.assertEqual(
            subtract_intervals(
                self.starts_at,
                self.ends_at,
                [(third, last), (first, second), (second, third)],
            ),
            [
                TimeInterval(self.starts_at, first),
                TimeInterval(last, self.ends_at),
            ],
        )

    def test_clips_intervals_to_operating_hours(self):
        self.assertEqual(
            subtract_intervals(
                self.starts_at,
                self.ends_at,
                [
                    (
                        self.starts_at - timedelta(hours=1),
                        self.starts_at + timedelta(minutes=30),
                    ),
                    (
                        self.ends_at - timedelta(minutes=30),
                        self.ends_at + timedelta(hours=1),
                    ),
                ],
            ),
            [
                TimeInterval(
                    self.starts_at + timedelta(minutes=30),
                    self.ends_at - timedelta(minutes=30),
                ),
            ],
        )

    def test_returns_no_time_when_bookings_cover_the_period(self):
        self.assertEqual(
            subtract_intervals(
                self.starts_at,
                self.ends_at,
                [
                    (
                        self.starts_at - timedelta(hours=1),
                        self.ends_at + timedelta(hours=1),
                    ),
                ],
            ),
            [],
        )

    def test_rejects_an_invalid_operating_period(self):
        with self.assertRaisesMessage(
            ValueError,
            'The operating interval must end after it starts.',
        ):
            subtract_intervals(self.ends_at, self.starts_at, [])

    def test_operating_interval_crosses_midnight_in_configured_timezone(self):
        interval = get_operating_interval(date(2026, 11, 15))

        self.assertEqual(interval.starts_at.isoformat(), '2026-11-15T06:00:00+03:00')
        self.assertEqual(interval.ends_at.isoformat(), '2026-11-16T04:00:00+03:00')


class AvailableIntervalsQueryTests(TestCase):
    def setUp(self):
        self.user = get_user_model().objects.create_user(username='availability-user')
        self.cabin = Cabin.objects.create(number='A-01')
        self.service_date = date.today() + timedelta(days=30)
        self.operating_interval = get_operating_interval(self.service_date)

    def test_subtracts_overlapping_bookings_from_operating_period(self):
        blocked_start = self.operating_interval.starts_at + timedelta(hours=2)
        blocked_end = blocked_start + timedelta(minutes=30)
        Booking.objects.create(
            user=self.user,
            cabin=self.cabin,
            starts_at=blocked_start,
            ends_at=blocked_end,
        )

        self.assertEqual(
            get_available_intervals(self.cabin, self.service_date),
            [
                TimeInterval(self.operating_interval.starts_at, blocked_start),
                TimeInterval(blocked_end, self.operating_interval.ends_at),
            ],
        )

    def test_open_maintenance_request_blocks_the_cabin(self):
        MaintenanceRequest.objects.create(
            cabin=self.cabin,
            reported_by=self.user,
            description='Cabin is unavailable for repair.',
        )

        self.assertEqual(
            get_available_intervals(self.cabin, self.service_date),
            [],
        )

    def test_resolved_maintenance_request_does_not_block_the_cabin(self):
        MaintenanceRequest.objects.create(
            cabin=self.cabin,
            reported_by=self.user,
            description='Repair has been completed.',
            status=MaintenanceRequest.Status.RESOLVED,
        )

        self.assertEqual(
            get_available_intervals(self.cabin, self.service_date),
            [self.operating_interval],
        )

    def test_removes_elapsed_time_from_today(self):
        now = self.operating_interval.starts_at + timedelta(hours=1)

        self.assertEqual(
            get_available_intervals(self.cabin, self.service_date, now=now),
            [TimeInterval(now, self.operating_interval.ends_at)],
        )
