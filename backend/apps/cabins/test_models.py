from django.db import IntegrityError, transaction
from django.test import TestCase

from apps.cabins.models import Cabin


class CabinModelTests(TestCase):
    def test_defaults_to_active_and_string_is_number(self):
        cabin = Cabin.objects.create(number='A-01')

        self.assertTrue(cabin.is_active)
        self.assertEqual(str(cabin), 'A-01')

    def test_cabin_numbers_must_be_unique(self):
        Cabin.objects.create(number='A-01')

        with self.assertRaises(IntegrityError):
            with transaction.atomic():
                Cabin.objects.create(number='A-01')

    def test_cabins_are_ordered_by_number(self):
        Cabin.objects.create(number='A-02')
        Cabin.objects.create(number='A-01')

        self.assertEqual(
            list(Cabin.objects.values_list('number', flat=True)),
            ['A-01', 'A-02'],
        )
