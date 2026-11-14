from django.urls import path

from apps.bookings.views import cancel_booking, create_booking


urlpatterns = [
    path('bookings', create_booking, name='create-booking'),
    path('bookings/<int:booking_id>', cancel_booking, name='cancel-booking'),
]
