from django.contrib import admin
from django.utils import timezone

from apps.bookings.models import Booking
from apps.bookings.services.availability import get_operating_interval
from apps.cabins.models import Cabin


class ShowerBookingAdminSite(admin.AdminSite):
    site_header = 'Shower Booking administration'
    site_title = 'Shower Booking admin'
    index_title = 'Administration'
    index_template = 'admin/dashboard.html'

    def index(self, request, extra_context=None):
        service_date = timezone.localdate()
        operating_interval = get_operating_interval(service_date)
        bookings = Booking.objects.filter(
            starts_at__lt=operating_interval.ends_at,
            ends_at__gt=operating_interval.starts_at,
        )
        active_cabin_count = Cabin.objects.filter(is_active=True).count()
        occupied_cabin_count = bookings.filter(
            cabin__is_active=True,
        ).values('cabin_id').distinct().count()
        booking_load = {
            'service_date': service_date,
            'booking_count': bookings.count(),
            'active_cabin_count': active_cabin_count,
            'occupied_cabin_count': occupied_cabin_count,
            'utilization_percent': (
                round(occupied_cabin_count / active_cabin_count * 100, 1)
                if active_cabin_count
                else 0
            ),
        }
        context = {'booking_load': booking_load}
        context.update(extra_context or {})
        return super().index(request, extra_context=context)


admin_site = ShowerBookingAdminSite(name='admin')
