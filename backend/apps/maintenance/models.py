from django.conf import settings
from django.db import models


class MaintenanceRequest(models.Model):
    class Status(models.TextChoices):
        OPEN = 'open', 'Open'
        IN_PROGRESS = 'in_progress', 'In progress'
        RESOLVED = 'resolved', 'Resolved'

    cabin = models.ForeignKey(
        'cabins.Cabin',
        on_delete=models.PROTECT,
        related_name='maintenance_requests',
        db_index=False,
    )
    reported_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.PROTECT,
        related_name='maintenance_requests',
        db_index=False,
    )
    description = models.TextField()
    status = models.CharField(
        max_length=20,
        choices=Status.choices,
        default=Status.OPEN,
    )
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    resolved_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        ordering = ['-created_at']
        indexes = [
            models.Index(
                fields=['cabin', 'status', 'created_at'],
                name='maint_cabin_status_created_idx',
            ),
        ]

    def __str__(self):
        return f'{self.cabin} — {self.get_status_display()}'
