from django.contrib import admin


class ShowerBookingAdminSite(admin.AdminSite):
    site_header = 'Shower Booking administration'
    site_title = 'Shower Booking admin'
    index_title = 'Administration'


admin_site = ShowerBookingAdminSite(name='admin')
