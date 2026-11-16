from datetime import date

from django.conf import settings
from django.http import JsonResponse
from django.utils import timezone
from django.views.decorators.http import require_GET

from apps.bookings.services.availability import get_available_intervals
from apps.cabins.models import Cabin


@require_GET
def available_cabins(request):
    raw_date = request.GET.get('date', '')
    try:
        service_date = date.fromisoformat(raw_date)
    except ValueError:
        return JsonResponse(
            {'detail': 'date must be provided in YYYY-MM-DD format.'},
            status=400,
        )

    if service_date.isoformat() != raw_date:
        return JsonResponse(
            {'detail': 'date must be provided in YYYY-MM-DD format.'},
            status=400,
        )

    cabins = []
    for cabin in Cabin.objects.filter(is_active=True):
        intervals = get_available_intervals(cabin, service_date)
        if intervals:
            cabins.append({
                'id': cabin.pk,
                'number': cabin.number,
                'available_intervals': [
                    {
                        'starts_at': timezone.localtime(interval.starts_at).isoformat(),
                        'ends_at': timezone.localtime(interval.ends_at).isoformat(),
                    }
                    for interval in intervals
                ],
            })

    return JsonResponse({
        'date': service_date.isoformat(),
        'timezone': settings.TIME_ZONE,
        'cabins': cabins,
    })
