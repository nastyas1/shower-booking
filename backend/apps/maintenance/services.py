from apps.cabins.models import Cabin
from apps.maintenance.models import MaintenanceRequest


def is_cabin_under_maintenance(cabin: Cabin) -> bool:
    return MaintenanceRequest.objects.filter(
        cabin=cabin,
        status__in=[
            MaintenanceRequest.Status.OPEN,
            MaintenanceRequest.Status.IN_PROGRESS,
        ],
    ).exists()
