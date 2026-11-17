from django.urls import path

from apps.bookings.views import create_booking


urlpatterns = [
    path('bookings', create_booking, name='create-booking'),
]
