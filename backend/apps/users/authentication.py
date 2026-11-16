from django.contrib.auth.models import AnonymousUser
from rest_framework_simplejwt.authentication import JWTAuthentication
from rest_framework_simplejwt.exceptions import AuthenticationFailed, InvalidToken


def get_api_user(request):
    authentication = JWTAuthentication()
    header = authentication.get_header(request)
    if header is None:
        user = getattr(request, 'user', AnonymousUser())
        return user if user.is_authenticated else None

    raw_token = authentication.get_raw_token(header)
    if raw_token is None:
        return None

    try:
        token = authentication.get_validated_token(raw_token)
        return authentication.get_user(token)
    except (AuthenticationFailed, InvalidToken):
        return None
