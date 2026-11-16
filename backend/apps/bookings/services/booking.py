from datetime import UTC, date, datetime, time, timedelta

from django.conf import settings
from django.utils import timezone

from apps.bookings.models import Booking
from apps.bookings.services.availability import get_operating_interval
from apps.cabins.models import Cabin
from apps.maintenance.models import MaintenanceRequest


class BookingRequestError(Exception):
    pass


class BookingConflict(Exception):
    pass


def _service_date_for_start(starts_at: datetime) -> date:
    local_start = timezone.localtime(starts_at)
    opening_time = time.fromisoformat(settings.OPERATING_OPEN_TIME)
    closing_time = time.fromisoformat(settings.OPERATING_CLOSE_TIME)
    service_date = local_start.date()

    if (
        closing_time <= opening_time
        and local_start.time().replace(tzinfo=None) < closing_time
    ):
        service_date -= timedelta(days=1)

    return service_date


def validate_booking_request(
    cabin: Cabin,
    starts_at: datetime,
    ends_at: datetime,
    *,
    now: datetime | None = None,
) -> None:
    if timezone.is_naive(starts_at) or timezone.is_naive(ends_at):
        raise BookingRequestError('Start and end times must include a timezone.')
    if ends_at <= starts_at:
        raise BookingRequestError('The end time must be after the start time.')

    duration = (
        ends_at.astimezone(UTC) - starts_at.astimezone(UTC)
    )
    if duration not in {
        timedelta(minutes=15),
        timedelta(minutes=30),
        timedelta(minutes=45),
    }:
        raise BookingRequestError('Booking duration must be 15, 30, or 45 minutes.')

    current_time = now or timezone.now()
    if starts_at <= current_time:
        raise BookingRequestError('Bookings must start in the future.')

    operating_interval = get_operating_interval(
        _service_date_for_start(starts_at)
    )
    if (
        starts_at < operating_interval.starts_at
        or ends_at > operating_interval.ends_at
    ):
        raise BookingRequestError('The requested time is outside operating hours.')

    if not cabin.is_active:
        raise BookingConflict('The selected cabin is not active.')

    if MaintenanceRequest.objects.filter(
        cabin=cabin,
        status__in=[
            MaintenanceRequest.Status.OPEN,
            MaintenanceRequest.Status.IN_PROGRESS,
        ],
    ).exists():
        raise BookingConflict('The selected cabin is unavailable for maintenance.')

    if Booking.objects.filter(
        cabin=cabin,
        starts_at__lt=ends_at,
        ends_at__gt=starts_at,
    ).exists():
        raise BookingConflict('The requested time overlaps an existing booking.')
