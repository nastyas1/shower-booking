from django.contrib.auth import get_user_model
from django.test import TestCase
from django.urls import reverse

from apps.bookings.models import Booking
from apps.cabins.models import Cabin
from apps.maintenance.models import MaintenanceRequest
from config.admin_site import admin_site


class AdminModelListTests(TestCase):
    def setUp(self):
        self.admin_user = get_user_model().objects.create_superuser(
            username='admin-test-user',
            email='admin@example.com',
            password='test-password',
        )
        self.client.force_login(self.admin_user)

    def test_domain_models_are_registered_and_have_working_lists(self):
        models_and_urls = (
            (get_user_model(), 'admin:users_user_changelist'),
            (Cabin, 'admin:cabins_cabin_changelist'),
            (Booking, 'admin:bookings_booking_changelist'),
            (MaintenanceRequest, 'admin:maintenance_maintenancerequest_changelist'),
        )

        for model, url_name in models_and_urls:
            with self.subTest(model=model):
                self.assertIn(model, admin_site._registry)
                response = self.client.get(reverse(url_name))
                self.assertEqual(response.status_code, 200)

    def test_domain_model_lists_support_search_filters_and_sorting(self):
        for model in (get_user_model(), Cabin, Booking, MaintenanceRequest):
            with self.subTest(model=model):
                model_admin = admin_site._registry[model]
                self.assertTrue(model_admin.search_fields)
                self.assertTrue(model_admin.list_filter)
                self.assertTrue(model_admin.ordering)
                self.assertTrue(model_admin.list_display)
