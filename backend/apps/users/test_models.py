from django.contrib.auth import get_user_model
from django.test import TestCase


class UserModelTests(TestCase):
    def test_create_user_hashes_password_and_sets_default_permissions(self):
        user = get_user_model().objects.create_user(
            username='test-user',
            password='Test-user-password-2026',
        )

        self.assertTrue(user.check_password('Test-user-password-2026'))
        self.assertNotEqual(user.password, 'Test-user-password-2026')
        self.assertTrue(user.is_active)
        self.assertFalse(user.is_staff)
        self.assertFalse(user.is_superuser)

    def test_user_string_is_username(self):
        user = get_user_model()(username='test-user')

        self.assertEqual(str(user), 'test-user')
