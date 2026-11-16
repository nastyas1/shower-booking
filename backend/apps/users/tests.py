import os
from unittest.mock import patch

from django.contrib.auth import get_user_model
from django.core.management import CommandError, call_command
from django.test import TestCase

from apps.cabins.models import Cabin


class SeedDataCommandTests(TestCase):
    @patch.dict(
        os.environ,
        {
            'SEED_ADMIN_USERNAME': 'admin',
            'SEED_ADMIN_EMAIL': 'admin@example.com',
            'SEED_ADMIN_PASSWORD': 'Long-local-admin-passphrase-2026',
        },
    )
    def test_creates_admin_cabins_and_users(self):
        call_command('seed_data', verbosity=0)

        admin = get_user_model().objects.get(username='admin')
        self.assertTrue(admin.is_staff)
        self.assertTrue(admin.is_superuser)
        self.assertTrue(admin.check_password('Long-local-admin-passphrase-2026'))
        self.assertEqual(Cabin.objects.count(), 3)
        self.assertEqual(
            get_user_model().objects.filter(username__startswith='demo_user_').count(),
            2,
        )
        for user in get_user_model().objects.filter(
            username__startswith='demo_user_',
        ):
            self.assertFalse(user.has_usable_password())

    @patch.dict(
        os.environ,
        {
            'SEED_ADMIN_USERNAME': 'admin',
            'SEED_ADMIN_EMAIL': 'admin@example.com',
            'SEED_ADMIN_PASSWORD': 'Long-local-admin-passphrase-2026',
        },
    )
    def test_is_idempotent_and_does_not_reset_existing_password(self):
        call_command('seed_data', verbosity=0)
        admin = get_user_model().objects.get(username='admin')
        admin.set_password('Changed-local-admin-passphrase-2026')
        admin.save(update_fields=['password'])
        demo_user = get_user_model().objects.get(username='demo_user_1')
        demo_user.set_password('Changed-demo-user-password-2026')
        demo_user.save(update_fields=['password'])

        call_command('seed_data', verbosity=0)

        self.assertTrue(
            get_user_model().objects.get(username='admin').check_password(
                'Changed-local-admin-passphrase-2026',
            ),
        )
        self.assertTrue(
            get_user_model().objects.get(username='demo_user_1').check_password(
                'Changed-demo-user-password-2026',
            ),
        )
        self.assertEqual(Cabin.objects.count(), 3)
        self.assertEqual(
            get_user_model().objects.filter(username__startswith='demo_user_').count(),
            2,
        )

    @patch.dict(
        os.environ,
        {
            'SEED_ADMIN_USERNAME': 'admin',
            'SEED_ADMIN_EMAIL': 'admin@example.com',
            'SEED_ADMIN_PASSWORD': 'Long-local-admin-passphrase-2026',
            'SEED_USER_PASSWORD': 'Long-local-demo-user-passphrase-2026',
        },
    )
    def test_sets_optional_password_for_new_demo_users(self):
        call_command('seed_data', verbosity=0)

        for user in get_user_model().objects.filter(
            username__startswith='demo_user_',
        ):
            self.assertTrue(
                user.check_password('Long-local-demo-user-passphrase-2026'),
            )

    def test_requires_password_before_creating_seed_data(self):
        with patch.dict(os.environ, {}, clear=False):
            os.environ.pop('SEED_ADMIN_PASSWORD', None)
            with self.assertRaisesMessage(CommandError, 'Set SEED_ADMIN_PASSWORD'):
                call_command('seed_data', verbosity=0)

        self.assertEqual(Cabin.objects.count(), 0)
        self.assertEqual(get_user_model().objects.count(), 0)

    @patch.dict(
        os.environ,
        {
            'SEED_ADMIN_USERNAME': 'admin',
            'SEED_ADMIN_EMAIL': 'admin@example.com',
            'SEED_ADMIN_PASSWORD': 'Long-local-admin-passphrase-2026',
        },
    )
    def test_refuses_to_promote_existing_regular_user(self):
        get_user_model().objects.create_user(
            username='admin',
            password='Existing-user-password-2026',
        )

        with self.assertRaisesMessage(CommandError, 'is not a staff superuser'):
            call_command('seed_data', verbosity=0)

        self.assertEqual(Cabin.objects.count(), 0)
        self.assertEqual(
            get_user_model().objects.filter(username__startswith='demo_user_').count(),
            0,
        )
