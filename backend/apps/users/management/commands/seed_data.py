import os

from django.contrib.auth import get_user_model
from django.core.management import BaseCommand, CommandError
from django.db import transaction

from apps.cabins.models import Cabin


class Command(BaseCommand):
    help = 'Create local demo cabins, users, and an administrator.'

    @transaction.atomic
    def handle(self, *args, **options):
        admin_password = os.getenv('SEED_ADMIN_PASSWORD')
        if not admin_password:
            raise CommandError('Set SEED_ADMIN_PASSWORD before seeding data.')

        User = get_user_model()
        admin_username = os.getenv('SEED_ADMIN_USERNAME', 'admin')
        admin_email = os.getenv('SEED_ADMIN_EMAIL', 'admin@example.com')

        admin = User.objects.filter(username=admin_username).first()
        if admin and not (admin.is_staff and admin.is_superuser):
            raise CommandError(
                f'User "{admin_username}" is not a staff superuser; '
                'refusing to promote an existing user.'
            )

        if admin is None:
            admin = User.objects.create_superuser(
                username=admin_username,
                email=admin_email,
                password=admin_password,
            )
        elif admin.email != admin_email:
            admin.email = admin_email
            admin.save(update_fields=['email'])

        for cabin_number in ('A-01', 'A-02', 'A-03'):
            Cabin.objects.get_or_create(number=cabin_number)

        demo_password = os.getenv('SEED_USER_PASSWORD') or None
        for index in (1, 2):
            username = f'demo_user_{index}'
            if not User.objects.filter(username=username).exists():
                User.objects.create_user(
                    username=username,
                    email=f'{username}@example.com',
                    password=demo_password,
                )

        self.stdout.write(self.style.SUCCESS('Seed data is ready.'))
