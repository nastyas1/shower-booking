import json
from concurrent.futures import ThreadPoolExecutor
from datetime import timedelta
from unittest import skipUnless

from django.contrib.auth import get_user_model
from django.db import close_old_connections, connection
from django.test import RequestFactory, TransactionTestCase
from django.utils import timezone

from apps.bookings.services.availability import get_operating_interval
from apps.bookings.views import create_booking
from apps.cabins.models import Cabin


@skipUnless(
    connection.vendor == 'postgresql',
    'Row-locking concurrency behavior requires PostgreSQL.',
)
class ConcurrentBookingTests(TransactionTestCase):
    reset_sequences = True

    def setUp(self):
        self.user = get_user_model().objects.create_user(
            username='concurrent-booking-user',
        )
        self.cabin = Cabin.objects.create(number='RACE-01')
        service_date = timezone.localdate() + timedelta(days=2)
        operating_interval = get_operating_interval(service_date)
        self.starts_at = operating_interval.starts_at + timedelta(hours=1)
        self.ends_at = self.starts_at + timedelta(minutes=15)
        self.payload = json.dumps({
            'cabin_id': self.cabin.pk,
            'starts_at': self.starts_at.isoformat(),
            'ends_at': self.ends_at.isoformat(),
        })

    def _create_booking(self, user_id):
        close_old_connections()
        try:
            user = get_user_model().objects.get(pk=user_id)
            request = RequestFactory().post(
                '/api/bookings',
                data=self.payload,
                content_type='application/json',
            )
            request.user = user
            return create_booking(request).status_code
        finally:
            close_old_connections()

    def test_only_one_of_ten_concurrent_requests_books_the_same_slot(self):
        with ThreadPoolExecutor(max_workers=10) as executor:
            statuses = list(
                executor.map(self._create_booking, [self.user.pk] * 10)
            )

        self.assertEqual(statuses.count(201), 1)
        self.assertEqual(statuses.count(409), 9)
        self.assertEqual(self.cabin.bookings.count(), 1)
