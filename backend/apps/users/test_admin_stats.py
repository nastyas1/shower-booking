from datetime import timedelta

from django.contrib.auth import get_user_model
from django.test import TestCase
from django.urls import reverse
from django.utils import timezone

from apps.bookings.models import Booking
from apps.bookings.services.availability import get_operating_interval
from apps.cabins.models import Cabin
from config.admin_site import admin_site


class AdminDashboardStatsTests(TestCase):
    def setUp(self):
        admin_user = get_user_model().objects.create_superuser(
            username='stats-admin',
            email='stats-admin@example.com',
            password='test-password',
        )
        self.client.force_login(admin_user)

    def test_dashboard_shows_daily_booking_load(self):
        user = get_user_model().objects.create_user(username='stats-user')
        first_cabin = Cabin.objects.create(number='S-01')
        Cabin.objects.create(number='S-02')
        inactive_cabin = Cabin.objects.create(number='S-03', is_active=False)
        interval = get_operating_interval(timezone.localdate())
        first_start = interval.starts_at + timedelta(hours=1)

        Booking.objects.create(
            user=user,
            cabin=first_cabin,
            starts_at=first_start,
            ends_at=first_start + timedelta(minutes=30),
        )
        Booking.objects.create(
            user=user,
            cabin=first_cabin,
            starts_at=first_start + timedelta(hours=1),
            ends_at=first_start + timedelta(hours=1, minutes=30),
        )
        Booking.objects.create(
            user=user,
            cabin=inactive_cabin,
            starts_at=first_start + timedelta(hours=2),
            ends_at=first_start + timedelta(hours=2, minutes=30),
        )

        response = self.client.get(reverse('admin:index'))

        self.assertEqual(response.status_code, 200)
        self.assertEqual(
            response.context['booking_load'],
            {
                'service_date': timezone.localdate(),
                'booking_count': 3,
                'active_cabin_count': 2,
                'occupied_cabin_count': 1,
                'utilization_percent': 50.0,
            },
        )
        self.assertContains(response, 'Cabin utilization')
        self.assertContains(response, '50.0%')

    def test_dashboard_handles_no_active_cabins(self):
        Cabin.objects.create(number='S-04', is_active=False)

        response = self.client.get(reverse('admin:index'))

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.context['booking_load']['utilization_percent'], 0)
        self.assertIn(Cabin, admin_site._registry)
