from django.contrib import admin

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
