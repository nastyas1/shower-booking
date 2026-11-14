from django.contrib.auth import get_user_model
from django.core.exceptions import ValidationError
from django.test import TestCase

from apps.cabins.models import Cabin
from apps.maintenance.models import MaintenanceRequest


class MaintenanceRequestModelTests(TestCase):
    def setUp(self):
        self.user = get_user_model().objects.create_user(username='reporter')
        self.cabin = Cabin.objects.create(number='A-01')

    def test_request_links_reporter_and_cabin_with_open_default(self):
        request = MaintenanceRequest.objects.create(
            cabin=self.cabin,
            reported_by=self.user,
            description='Shower handle is broken.',
        )

        self.assertEqual(request.cabin, self.cabin)
        self.assertEqual(request.reported_by, self.user)
        self.assertEqual(self.cabin.maintenance_requests.get(), request)
        self.assertEqual(self.user.maintenance_requests.get(), request)
        self.assertEqual(request.status, MaintenanceRequest.Status.OPEN)
        self.assertIsNone(request.resolved_at)
        self.assertIsNotNone(request.created_at)
        self.assertIsNotNone(request.updated_at)

    def test_request_accepts_defined_statuses(self):
        for status in MaintenanceRequest.Status:
            with self.subTest(status=status):
                request = MaintenanceRequest(
                    cabin=self.cabin,
                    reported_by=self.user,
                    description='Test issue.',
                    status=status,
                )
                request.full_clean()

    def test_request_rejects_undefined_status(self):
        request = MaintenanceRequest(
            cabin=self.cabin,
            reported_by=self.user,
            description='Test issue.',
            status='unknown',
        )

        with self.assertRaises(ValidationError):
            request.full_clean()

    def test_string_includes_cabin_and_status(self):
        request = MaintenanceRequest.objects.create(
            cabin=self.cabin,
            reported_by=self.user,
            description='Shower handle is broken.',
        )

        self.assertEqual(str(request), 'A-01 — Open')
