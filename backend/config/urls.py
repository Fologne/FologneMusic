from django.urls import path

from core.views import health, resolve, track_content

urlpatterns = [
    path("api/v1/health/", health, name="health"),
    path("api/v1/tracks/resolve/", resolve, name="resolve-track"),
    path(
        "api/v1/tracks/<str:track_id>/lyrics/", track_content, {"resource": "lyrics"}, name="lyrics"
    ),
    path(
        "api/v1/tracks/<str:track_id>/meaning/",
        track_content,
        {"resource": "meaning"},
        name="meaning",
    ),
]
