from django.contrib import admin
from django.utils import timezone

from apps.maintenance.models import MaintenanceRequest
from config.admin_site import admin_site


@admin.register(MaintenanceRequest, site=admin_site)
class MaintenanceRequestAdmin(admin.ModelAdmin):
    list_display = ('cabin', 'reported_by', 'status', 'created_at', 'resolved_at')
    list_filter = ('status', 'created_at')
    search_fields = ('cabin__number', 'reported_by__username', 'description')
    ordering = ('-created_at',)
    date_hierarchy = 'created_at'
    readonly_fields = ('created_at', 'updated_at')

    @admin.action(description='Resolve selected requests and release cabins')
    def resolve_requests(self, request, queryset):
        resolved_at = timezone.now()
        resolved_count = queryset.filter(
            status__in=[
                MaintenanceRequest.Status.OPEN,
                MaintenanceRequest.Status.IN_PROGRESS,
            ],
        ).update(
            status=MaintenanceRequest.Status.RESOLVED,
            resolved_at=resolved_at,
            updated_at=resolved_at,
        )
        self.message_user(
            request,
            f'{resolved_count} maintenance request(s) resolved.',
        )

    actions = ('resolve_requests',)
