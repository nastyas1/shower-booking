from dataclasses import dataclass
from datetime import date, datetime, time, timedelta
from typing import Iterable

from django.conf import settings
from django.utils import timezone

from apps.bookings.models import Booking
from apps.cabins.models import Cabin
from apps.maintenance.models import MaintenanceRequest


@dataclass(frozen=True)
class TimeInterval:
    starts_at: datetime
    ends_at: datetime


def subtract_intervals(
    starts_at: datetime,
    ends_at: datetime,
    blocked_intervals: Iterable[tuple[datetime, datetime]],
) -> list[TimeInterval]:
    if ends_at <= starts_at:
        raise ValueError('The operating interval must end after it starts.')

    clipped_intervals = sorted(
        (max(starts_at, block_start), min(ends_at, block_end))
        for block_start, block_end in blocked_intervals
        if block_end > starts_at and block_start < ends_at
    )

    available = []
    cursor = starts_at
    for block_start, block_end in clipped_intervals:
        if block_start > cursor:
            available.append(TimeInterval(cursor, block_start))
        cursor = max(cursor, block_end)

    if cursor < ends_at:
        available.append(TimeInterval(cursor, ends_at))

    return available


def get_operating_interval(service_date: date) -> TimeInterval:
    opening_time = time.fromisoformat(settings.OPERATING_OPEN_TIME)
    closing_time = time.fromisoformat(settings.OPERATING_CLOSE_TIME)
    local_timezone = timezone.get_default_timezone()

    starts_at = timezone.make_aware(
        datetime.combine(service_date, opening_time),
        local_timezone,
    )
    closing_date = service_date + timedelta(days=closing_time <= opening_time)
    ends_at = timezone.make_aware(
        datetime.combine(closing_date, closing_time),
        local_timezone,
    )
    return TimeInterval(starts_at, ends_at)


def get_available_intervals(
    cabin: Cabin,
    service_date: date,
    *,
    now: datetime | None = None,
) -> list[TimeInterval]:
    operating_interval = get_operating_interval(service_date)
    starts_at = operating_interval.starts_at
    ends_at = operating_interval.ends_at
    current_time = now or timezone.now()
    starts_at = max(starts_at, current_time)
    if starts_at >= ends_at:
        return []

    if MaintenanceRequest.objects.filter(
        cabin=cabin,
        status__in=[
            MaintenanceRequest.Status.OPEN,
            MaintenanceRequest.Status.IN_PROGRESS,
        ],
    ).exists():
        return []

    bookings = Booking.objects.filter(
        cabin=cabin,
        starts_at__lt=ends_at,
        ends_at__gt=starts_at,
    ).values_list('starts_at', 'ends_at')
    return subtract_intervals(starts_at, ends_at, bookings)
