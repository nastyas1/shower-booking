import json

from django.db import transaction
from django.http import JsonResponse
from django.utils import timezone
from django.utils.dateparse import parse_datetime
from django.views.decorators.http import require_POST

from apps.bookings.models import Booking
from apps.bookings.services.booking import (
    BookingConflict,
    BookingRequestError,
    validate_booking_request,
)
from apps.cabins.models import Cabin
from apps.users.authentication import get_api_user


def _parse_aware_datetime(value):
    if not isinstance(value, str):
        return None
    try:
        parsed = parse_datetime(value)
    except ValueError:
        return None
    if parsed is None or timezone.is_naive(parsed):
        return None
    return parsed


@require_POST
def create_booking(request):
    user = get_api_user(request)
    if user is None:
        return JsonResponse(
            {'detail': 'Authentication credentials were not provided.'},
            status=401,
        )

    try:
        payload = json.loads(request.body)
    except (json.JSONDecodeError, UnicodeDecodeError):
        return JsonResponse({'detail': 'Request body must be valid JSON.'}, status=400)
    if not isinstance(payload, dict):
        return JsonResponse({'detail': 'Request body must be a JSON object.'}, status=400)

    raw_cabin_id = payload.get('cabin_id')
    if (
        isinstance(raw_cabin_id, bool)
        or not isinstance(raw_cabin_id, (int, str))
        or (isinstance(raw_cabin_id, str) and not raw_cabin_id.isdecimal())
    ):
        return JsonResponse({'detail': 'cabin_id must be an integer.'}, status=400)
    cabin_id = int(raw_cabin_id)
    if cabin_id < 1:
        return JsonResponse({'detail': 'cabin_id must be a positive integer.'}, status=400)

    starts_at = _parse_aware_datetime(payload.get('starts_at'))
    ends_at = _parse_aware_datetime(payload.get('ends_at'))
    if starts_at is None or ends_at is None:
        return JsonResponse(
            {'detail': 'starts_at and ends_at must be ISO datetimes with a timezone.'},
            status=400,
        )

    try:
        with transaction.atomic():
            cabin = Cabin.objects.get(pk=cabin_id)
            validate_booking_request(cabin, starts_at, ends_at)
            booking = Booking.objects.create(
                user=user,
                cabin=cabin,
                starts_at=starts_at,
                ends_at=ends_at,
            )
    except Cabin.DoesNotExist:
        return JsonResponse({'detail': 'Cabin not found.'}, status=404)
    except BookingRequestError as exc:
        return JsonResponse({'detail': str(exc)}, status=400)
    except BookingConflict as exc:
        return JsonResponse({'detail': str(exc)}, status=409)

    return JsonResponse(
        {
            'id': booking.pk,
            'cabin_id': booking.cabin_id,
            'starts_at': timezone.localtime(booking.starts_at).isoformat(),
            'ends_at': timezone.localtime(booking.ends_at).isoformat(),
        },
        status=201,
    )
