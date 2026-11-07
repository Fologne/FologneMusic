from django.core import signing
from django.views.decorators.cache import never_cache
from rest_framework.decorators import api_view, throttle_classes
from rest_framework.response import Response
from rest_framework.throttling import SimpleRateThrottle

from core.content import (
    TRACK_SALT,
    LanguageInput,
    TrackInput,
    lyrics,
    meaning,
    resolve_track,
    result,
)
from core.providers import ProviderError


class TrackThrottle(SimpleRateThrottle):
    rate = "20/min"

    def get_cache_key(self, request, view):
        return f"musicapp:track-throttle:{request.META.get('REMOTE_ADDR', 'unknown')}"


@never_cache
@api_view(["GET"])
def health(request):
    return Response({"status": "ok", "service": "musicapp", "api_version": "v1"})


@never_cache
@api_view(["POST"])
@throttle_classes([TrackThrottle])
def resolve(request):
    payload = TrackInput(data=request.data)
    payload.is_valid(raise_exception=True)
    return Response({"schema_version": 1, **resolve_track(payload.validated_data)})


@never_cache
@api_view(["GET"])
@throttle_classes([TrackThrottle])
def track_content(request, track_id, resource):
    if len(track_id) > 4096:
        return Response(result("unknown_track"), status=404)
    try:
        reference = signing.loads(track_id, salt=TRACK_SALT, max_age=86400)
    except signing.SignatureExpired:
        return Response(result("reference_expired"), status=410)
    except signing.BadSignature:
        return Response(result("unknown_track"), status=404)
    query = LanguageInput(data=request.query_params)
    query.is_valid(raise_exception=True)
    fetch = lyrics if resource == "lyrics" else meaning
    try:
        return Response(fetch(reference, query.validated_data["language"]))
    except ProviderError as exc:
        return Response(result(exc.status), status=503)
