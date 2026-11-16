from django.urls import path

from apps.maintenance.views import create_maintenance_request


urlpatterns = [
    path('maintenance', create_maintenance_request, name='create-maintenance-request'),
]
