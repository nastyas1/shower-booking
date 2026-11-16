import json

from django.contrib.auth.password_validation import validate_password
from django.core.exceptions import ValidationError
from django.db import IntegrityError, transaction
from django.http import JsonResponse
from django.views.decorators.http import require_POST
from rest_framework_simplejwt.tokens import RefreshToken

from apps.users.models import User


@require_POST
def register(request):
    try:
        payload = json.loads(request.body)
    except (json.JSONDecodeError, UnicodeDecodeError):
        return JsonResponse({'detail': 'Request body must be valid JSON.'}, status=400)
    if not isinstance(payload, dict):
        return JsonResponse({'detail': 'Request body must be a JSON object.'}, status=400)

    username = payload.get('username')
    email = payload.get('email')
    password = payload.get('password')
    if not isinstance(username, str) or not username.strip():
        return JsonResponse({'detail': 'username is required.'}, status=400)
    if not isinstance(email, str) or not email.strip():
        return JsonResponse({'detail': 'email is required.'}, status=400)
    if not isinstance(password, str) or not password:
        return JsonResponse({'detail': 'password is required.'}, status=400)

    user = User(username=username.strip(), email=email.strip())
    try:
        user.full_clean(exclude=['password'])
        validate_password(password, user=user)
    except ValidationError as exc:
        return JsonResponse({'detail': exc.messages}, status=400)

    user.set_password(password)
    try:
        with transaction.atomic():
            user.save()
    except IntegrityError:
        return JsonResponse(
            {'detail': 'A user with this username already exists.'},
            status=400,
        )

    refresh = RefreshToken.for_user(user)
    return JsonResponse(
        {'access': str(refresh.access_token), 'refresh': str(refresh)},
        status=201,
    )
