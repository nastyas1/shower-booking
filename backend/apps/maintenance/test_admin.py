from datetime import date, timedelta

from django.contrib.auth import get_user_model
from django.test import TestCase
from django.urls import reverse

from apps.cabins.models import Cabin
from apps.maintenance.models import MaintenanceRequest


class MaintenanceAdminActionTests(TestCase):
    def setUp(self):
        admin_user = get_user_model().objects.create_superuser(
            username='maintenance-admin',
            email='maintenance-admin@example.com',
            password='test-password',
        )
        self.client.force_login(admin_user)
        self.cabin = Cabin.objects.create(number='M-02')
        self.maintenance_request = MaintenanceRequest.objects.create(
            cabin=self.cabin,
            reported_by=admin_user,
            description='Broken shower head.',
        )
        self.service_date = date.today() + timedelta(days=30)
        self.changelist_url = reverse(
            'admin:maintenance_maintenancerequest_changelist',
        )

    def test_resolving_request_releases_cabin_from_schedule(self):
        response = self.client.get(
            '/api/cabins/available',
            {'date': self.service_date.isoformat()},
        )
        self.assertEqual(response.json()['cabins'], [])

        response = self.client.post(
            self.changelist_url,
            {
                'action': 'resolve_requests',
                '_selected_action': [str(self.maintenance_request.pk)],
            },
        )

        self.assertEqual(response.status_code, 302)
        self.maintenance_request.refresh_from_db()
        self.assertEqual(
            self.maintenance_request.status,
            MaintenanceRequest.Status.RESOLVED,
        )
        self.assertIsNotNone(self.maintenance_request.resolved_at)

        response = self.client.get(
            '/api/cabins/available',
            {'date': self.service_date.isoformat()},
        )
        self.assertEqual(response.status_code, 200)
        self.assertEqual(
            [cabin['id'] for cabin in response.json()['cabins']],
            [self.cabin.pk],
        )

    def test_resolving_request_does_not_reactivate_inactive_cabin(self):
        self.cabin.is_active = False
        self.cabin.save(update_fields=['is_active'])

        response = self.client.post(
            self.changelist_url,
            {
                'action': 'resolve_requests',
                '_selected_action': [str(self.maintenance_request.pk)],
            },
        )

        self.assertEqual(response.status_code, 302)
        self.cabin.refresh_from_db()
        self.assertFalse(self.cabin.is_active)
