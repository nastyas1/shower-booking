from django.urls import path

from apps.cabins.views import available_cabins


urlpatterns = [
    path('cabins/available', available_cabins, name='available-cabins'),
]
