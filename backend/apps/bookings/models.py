from datetime import timedelta

from django.conf import settings
from django.core.exceptions import ValidationError
from django.db import models
from django.db.models import F, Q


class Booking(models.Model):
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.PROTECT,
        related_name='bookings',
        db_index=False,
    )
    cabin = models.ForeignKey(
        'cabins.Cabin',
        on_delete=models.PROTECT,
        related_name='bookings',
        db_index=False,
    )
    starts_at = models.DateTimeField()
    ends_at = models.DateTimeField()
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['starts_at']
        constraints = [
            models.CheckConstraint(
                condition=Q(ends_at__gt=F('starts_at')),
                name='booking_end_after_start',
            ),
        ]
        indexes = [
            models.Index(
                fields=['cabin', 'starts_at'],
                name='booking_cabin_start_idx',
            ),
            models.Index(
                fields=['user', 'starts_at'],
                name='booking_user_start_idx',
            ),
        ]

    def clean(self):
        super().clean()
        if self.starts_at and self.ends_at:
            duration = self.ends_at - self.starts_at
            allowed_durations = {
                timedelta(minutes=15),
                timedelta(minutes=30),
                timedelta(minutes=45),
            }
            if duration not in allowed_durations:
                raise ValidationError({
                    'ends_at': 'Booking duration must be 15, 30, or 45 minutes.',
                })

    def __str__(self):
        return f'{self.cabin} — {self.starts_at}'
