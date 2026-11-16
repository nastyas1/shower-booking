import json

from django.http import JsonResponse
from django.utils import timezone
from django.views.decorators.http import require_POST

from apps.cabins.models import Cabin
from apps.maintenance.models import MaintenanceRequest


@require_POST
def create_maintenance_request(request):
    if not request.user.is_authenticated:
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

    description = payload.get('description')
    if not isinstance(description, str) or not description.strip():
        return JsonResponse(
            {'detail': 'description must be a non-empty string.'},
            status=400,
        )

    try:
        cabin = Cabin.objects.get(pk=cabin_id)
    except Cabin.DoesNotExist:
        return JsonResponse({'detail': 'Cabin not found.'}, status=404)

    maintenance_request = MaintenanceRequest.objects.create(
        cabin=cabin,
        reported_by=request.user,
        description=description.strip(),
    )
    return JsonResponse(
        {
            'id': maintenance_request.pk,
            'cabin_id': maintenance_request.cabin_id,
            'description': maintenance_request.description,
            'status': maintenance_request.status,
            'created_at': timezone.localtime(
                maintenance_request.created_at
            ).isoformat(),
        },
        status=201,
    )
