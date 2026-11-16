from django.contrib import admin

from apps.bookings.models import Booking
from config.admin_site import admin_site


@admin.register(Booking, site=admin_site)
class BookingAdmin(admin.ModelAdmin):
    list_display = ('cabin', 'user', 'starts_at', 'ends_at', 'created_at')
    list_filter = ('cabin', 'starts_at')
    search_fields = ('cabin__number', 'user__username', 'user__email')
    ordering = ('starts_at',)
    date_hierarchy = 'starts_at'
    readonly_fields = ('created_at',)
