from django.urls import path

from apps.bookings.views import bookings_collection, cancel_booking


urlpatterns = [
    path('bookings', bookings_collection, name='create-booking'),
    path('bookings/<int:booking_id>', cancel_booking, name='cancel-booking'),
]
