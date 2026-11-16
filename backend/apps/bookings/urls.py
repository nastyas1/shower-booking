from django.urls import path

from apps.bookings.views import bookings_collection


urlpatterns = [
    path('bookings', bookings_collection, name='create-booking'),
]
