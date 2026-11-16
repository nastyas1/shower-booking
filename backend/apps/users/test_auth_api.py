import json
from datetime import date, timedelta

from django.contrib.auth import get_user_model
from django.test import TestCase
from rest_framework_simplejwt.tokens import AccessToken, RefreshToken

from apps.bookings.models import Booking
from apps.bookings.services.availability import get_operating_interval
from apps.cabins.models import Cabin
from apps.maintenance.models import MaintenanceRequest


class AuthenticationApiTests(TestCase):
    registration_password = 'Strong-password-for-api-tests-2026!'

    def _post_json(self, path, payload):
        return self.client.post(
            path,
            data=json.dumps(payload),
            content_type='application/json',
        )

    def test_register_creates_user_and_returns_access_and_refresh_tokens(self):
        response = self._post_json(
            '/api/auth/register/',
            {
                'username': 'mobile-user',
                'email': 'mobile-user@example.com',
                'password': self.registration_password,
            },
        )

        self.assertEqual(response.status_code, 201)
        payload = response.json()
        self.assertTrue(payload['access'])
        self.assertTrue(payload['refresh'])
        user = get_user_model().objects.get(username='mobile-user')
        self.assertTrue(user.check_password(self.registration_password))
        self.assertEqual(AccessToken(payload['access'])['user_id'], str(user.pk))
        self.assertEqual(RefreshToken(payload['refresh'])['user_id'], str(user.pk))

    def test_register_rejects_invalid_fields_duplicate_username_and_weak_password(self):
        cases = [
            ({'email': 'missing-user@example.com', 'password': self.registration_password}, 400),
            (
                {
                    'username': 'bad-email',
                    'email': 'not-an-email',
                    'password': self.registration_password,
                },
                400,
            ),
            (
                {
                    'username': 'weak-password',
                    'email': 'weak@example.com',
                    'password': '123',
                },
                400,
            ),
        ]
        get_user_model().objects.create_user(username='already-used')
        cases.append(
            (
                {
                    'username': 'already-used',
                    'email': 'duplicate@example.com',
                    'password': self.registration_password,
                },
                400,
            ),
        )

        for payload, expected_status in cases:
            with self.subTest(payload=payload):
                response = self._post_json('/api/auth/register/', payload)
                self.assertEqual(response.status_code, expected_status)

        self.assertEqual(get_user_model().objects.count(), 1)

    def test_register_rejects_malformed_json(self):
        response = self.client.post(
            '/api/auth/register/',
            data='{',
            content_type='application/json',
        )

        self.assertEqual(response.status_code, 400)

    def test_login_returns_access_and_refresh_tokens_for_valid_credentials(self):
        user = get_user_model().objects.create_user(
            username='login-user',
            password=self.registration_password,
        )

        response = self._post_json(
            '/api/auth/token/',
            {'username': user.username, 'password': self.registration_password},
        )

        self.assertEqual(response.status_code, 200)
        payload = response.json()
        self.assertTrue(payload['access'])
        self.assertTrue(payload['refresh'])
        self.assertEqual(AccessToken(payload['access'])['user_id'], str(user.pk))

    def test_login_rejects_invalid_credentials(self):
        get_user_model().objects.create_user(
            username='login-user',
            password=self.registration_password,
        )

        response = self._post_json(
            '/api/auth/token/',
            {'username': 'login-user', 'password': 'incorrect'},
        )

        self.assertEqual(response.status_code, 401)

    def test_refresh_endpoint_returns_a_new_access_token(self):
        user = get_user_model().objects.create_user(username='refresh-user')
        refresh = RefreshToken.for_user(user)

        response = self._post_json(
            '/api/auth/token/refresh/',
            {'refresh': str(refresh)},
        )

        self.assertEqual(response.status_code, 200)
        self.assertEqual(
            AccessToken(response.json()['access'])['user_id'],
            str(user.pk),
        )

    def test_bearer_access_token_authenticates_booking_and_maintenance_requests(self):
        user = get_user_model().objects.create_user(username='bearer-user')
        cabin = Cabin.objects.create(number='JWT-01')
        access = str(RefreshToken.for_user(user).access_token)
        self.client.defaults['HTTP_AUTHORIZATION'] = f'Bearer {access}'
        service_date = date.today() + timedelta(days=30)
        starts_at = get_operating_interval(service_date).starts_at + timedelta(hours=1)

        booking_response = self._post_json(
            '/api/bookings',
            {
                'cabin_id': cabin.pk,
                'starts_at': starts_at.isoformat(),
                'ends_at': (starts_at + timedelta(minutes=30)).isoformat(),
            },
        )
        maintenance_response = self._post_json(
            '/api/maintenance',
            {'cabin_id': cabin.pk, 'description': 'The shower is leaking.'},
        )

        self.assertEqual(booking_response.status_code, 201)
        self.assertEqual(maintenance_response.status_code, 201)
        self.assertEqual(Booking.objects.get().user, user)
        self.assertEqual(MaintenanceRequest.objects.get().reported_by, user)

    def test_invalid_bearer_token_does_not_fall_back_to_session_authentication(self):
        user = get_user_model().objects.create_user(username='session-user')
        cabin = Cabin.objects.create(number='JWT-02')
        self.client.force_login(user)
        self.client.defaults['HTTP_AUTHORIZATION'] = 'Bearer invalid-token'

        response = self._post_json(
            '/api/maintenance',
            {'cabin_id': cabin.pk, 'description': 'The shower is leaking.'},
        )

        self.assertEqual(response.status_code, 401)
        self.assertFalse(MaintenanceRequest.objects.exists())
