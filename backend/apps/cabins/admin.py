from django.contrib import admin

from apps.cabins.models import Cabin
from config.admin_site import admin_site


@admin.register(Cabin, site=admin_site)
class CabinAdmin(admin.ModelAdmin):
    list_display = ('number', 'is_active')
    list_filter = ('is_active',)
    search_fields = ('number',)
    ordering = ('number',)
