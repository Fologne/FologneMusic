import os
from pathlib import Path

from django.core.exceptions import ImproperlyConfigured

BASE_DIR = Path(__file__).resolve().parent.parent
DEBUG = os.environ.get("DJANGO_DEBUG", "false").lower() == "true"
SECRET_KEY = os.environ.get("DJANGO_SECRET_KEY", "")
if not SECRET_KEY and (key_file := os.environ.get("DJANGO_SECRET_KEY_FILE")):
    SECRET_KEY = Path(key_file).read_text(encoding="utf-8").strip()
if not SECRET_KEY:
    if not DEBUG:
        raise ImproperlyConfigured("Configure DJANGO_SECRET_KEY ou ative DJANGO_DEBUG localmente.")
    SECRET_KEY = "local-development-only-not-for-deployment"

ALLOWED_HOSTS = [
    host.strip()
    for host in os.environ.get("DJANGO_ALLOWED_HOSTS", "localhost,127.0.0.1,10.0.2.2").split(",")
    if host.strip()
]
INSTALLED_APPS = ["django.contrib.contenttypes", "rest_framework", "core"]
MIDDLEWARE = [
    "django.middleware.security.SecurityMiddleware",
    "django.middleware.common.CommonMiddleware",
    "django.middleware.csrf.CsrfViewMiddleware",
    "django.middleware.clickjacking.XFrameOptionsMiddleware",
]
ROOT_URLCONF = "config.urls"
WSGI_APPLICATION = "config.wsgi.application"
ASGI_APPLICATION = "config.asgi.application"
DATABASES = {
    "default": {
        "ENGINE": "django.db.backends.sqlite3",
        "NAME": os.environ.get("DJANGO_DB_PATH", BASE_DIR / "db.sqlite3"),
    }
}
REST_FRAMEWORK = {
    "DEFAULT_RENDERER_CLASSES": ["rest_framework.renderers.JSONRenderer"],
    "DEFAULT_AUTHENTICATION_CLASSES": [],
    "DEFAULT_PERMISSION_CLASSES": ["rest_framework.permissions.AllowAny"],
    "UNAUTHENTICATED_USER": None,
}
LANGUAGE_CODE = "pt-br"
TIME_ZONE = "America/Cuiaba"
USE_I18N = True
USE_TZ = True
DEFAULT_AUTO_FIELD = "django.db.models.BigAutoField"
MUSICAPP_USER_AGENT = os.environ.get(
    "MUSICAPP_USER_AGENT", "FologneMusic/1.0.0 (https://github.com/Fologne/RhapsodyMusic)"
)
if os.environ.get("DJANGO_TRUST_PROXY", "false").lower() == "true":
    SECURE_PROXY_SSL_HEADER = ("HTTP_X_FORWARDED_PROTO", "https")
SECURE_SSL_REDIRECT = os.environ.get("DJANGO_REQUIRE_HTTPS", "false").lower() == "true"
SECURE_HSTS_SECONDS = 31536000 if SECURE_SSL_REDIRECT else 0
CSRF_COOKIE_SECURE = SECURE_SSL_REDIRECT
SESSION_COOKIE_SECURE = SECURE_SSL_REDIRECT

if not DEBUG:
    LOGGING = {
        "version": 1,
        "disable_existing_loggers": False,
        "filters": {"safe_request": {"()": "config.logging.SafeRequestLog"}},
        "handlers": {
            "safe_console": {"class": "logging.StreamHandler", "filters": ["safe_request"]}
        },
        "loggers": {
            "django.request": {
                "handlers": ["safe_console"],
                "level": "WARNING",
                "propagate": False,
            }
        },
    }
