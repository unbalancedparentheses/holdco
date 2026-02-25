import os
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent.parent

SECRET_KEY = os.environ.get(
    "DJANGO_SECRET_KEY",
    "django-insecure-change-me-in-production",
)

DEBUG = os.environ.get("DJANGO_DEBUG", "1") == "1"

ALLOWED_HOSTS = os.environ.get("DJANGO_ALLOWED_HOSTS", "*").split(",")

INSTALLED_APPS = [
    "unfold",
    "django.contrib.admin",
    "django.contrib.auth",
    "django.contrib.contenttypes",
    "django.contrib.sessions",
    "django.contrib.messages",
    "django.contrib.staticfiles",
    "django.contrib.humanize",
    "django.contrib.sites",
    "rest_framework",
    "allauth",
    "allauth.account",
    "allauth.socialaccount",
    "allauth.socialaccount.providers.google",
    "django_otp",
    "django_otp.plugins.otp_totp",
    "django_otp.plugins.otp_static",
    "django_prometheus",
    "storages",
    "core",
]

# Channels (WebSocket support)
if os.environ.get("HOLDCO_WEBSOCKET", "0") == "1":
    INSTALLED_APPS.insert(0, "daphne")
    ASGI_APPLICATION = "holdco.asgi.application"
    CHANNEL_LAYERS = {
        "default": {
            "BACKEND": os.environ.get(
                "CHANNEL_BACKEND",
                "channels.layers.InMemoryChannelLayer",
            ),
        }
    }

SITE_ID = 1

MIDDLEWARE = [
    "django_prometheus.middleware.PrometheusBeforeMiddleware",
    "django.middleware.security.SecurityMiddleware",
    "django.contrib.sessions.middleware.SessionMiddleware",
    "django.middleware.locale.LocaleMiddleware",
    "allauth.account.middleware.AccountMiddleware",
    "django.middleware.common.CommonMiddleware",
    "django.middleware.csrf.CsrfViewMiddleware",
    "django.contrib.auth.middleware.AuthenticationMiddleware",
    "django_otp.middleware.OTPMiddleware",
    "django.contrib.messages.middleware.MessageMiddleware",
    "django.middleware.clickjacking.XFrameOptionsMiddleware",
    "holdco.middleware.AdminRoleMiddleware",
    "django_prometheus.middleware.PrometheusAfterMiddleware",
]

ROOT_URLCONF = "holdco.urls"

TEMPLATES = [
    {
        "BACKEND": "django.template.backends.django.DjangoTemplates",
        "DIRS": [],
        "APP_DIRS": True,
        "OPTIONS": {
            "context_processors": [
                "django.template.context_processors.debug",
                "django.template.context_processors.request",
                "django.contrib.auth.context_processors.auth",
                "django.contrib.messages.context_processors.messages",
                "django.template.context_processors.i18n",
            ],
        },
    },
]

WSGI_APPLICATION = "holdco.wsgi.application"

# Database — PostgreSQL or SQLite based on env vars
_db_engine = os.environ.get("HOLDCO_DB_ENGINE", "sqlite3")
if _db_engine == "postgresql":
    DATABASES = {
        "default": {
            "ENGINE": "django.db.backends.postgresql",
            "NAME": os.environ.get("HOLDCO_DB_NAME", "holdco"),
            "USER": os.environ.get("HOLDCO_DB_USER", "holdco"),
            "PASSWORD": os.environ.get("HOLDCO_DB_PASSWORD", ""),
            "HOST": os.environ.get("HOLDCO_DB_HOST", "localhost"),
            "PORT": os.environ.get("HOLDCO_DB_PORT", "5432"),
        }
    }
else:
    _db_path = os.environ.get("HOLDCO_DB", str(BASE_DIR / "holdco.db"))
    DATABASES = {
        "default": {
            "ENGINE": "django.db.backends.sqlite3",
            "NAME": _db_path,
        }
    }

AUTHENTICATION_BACKENDS = [
    "django.contrib.auth.backends.ModelBackend",
    "allauth.account.auth_backends.AuthenticationBackend",
]

AUTH_PASSWORD_VALIDATORS = []

# Internationalization
LANGUAGE_CODE = os.environ.get("HOLDCO_LANGUAGE", "en-us")
TIME_ZONE = os.environ.get("HOLDCO_TIMEZONE", "UTC")
USE_I18N = True
USE_L10N = True
USE_TZ = True

LANGUAGES = [
    ("en", "English"),
    ("es", "Spanish"),
    ("fr", "French"),
    ("de", "German"),
    ("pt", "Portuguese"),
    ("zh-hans", "Chinese (Simplified)"),
    ("ja", "Japanese"),
]

LOCALE_PATHS = [
    BASE_DIR / "locale",
]

STATIC_URL = "static/"
STATIC_ROOT = BASE_DIR / "staticfiles"

# Media / file uploads
MEDIA_URL = "/media/"
MEDIA_ROOT = BASE_DIR / "media"

DEFAULT_AUTO_FIELD = "django.db.models.BigAutoField"

# DRF
REST_FRAMEWORK = {
    "DEFAULT_PERMISSION_CLASSES": [
        "rest_framework.permissions.IsAuthenticated",
        "core.permissions.RolePermission",
    ],
    "DEFAULT_AUTHENTICATION_CLASSES": [
        "rest_framework.authentication.SessionAuthentication",
    ],
    "DEFAULT_PAGINATION_CLASS": None,
}

# django-allauth
SOCIALACCOUNT_PROVIDERS = {
    "google": {
        "SCOPE": ["profile", "email"],
        "AUTH_PARAMS": {"access_type": "online"},
        "APP": {
            "client_id": os.environ.get("GOOGLE_CLIENT_ID", ""),
            "secret": os.environ.get("GOOGLE_CLIENT_SECRET", ""),
        },
    }
}
ACCOUNT_LOGIN_METHODS = {"email"}
ACCOUNT_SIGNUP_FIELDS = ["email*", "password1*", "password2*"]
LOGIN_URL = "/accounts/login/"
LOGIN_REDIRECT_URL = "/"
LOGOUT_REDIRECT_URL = "/"

# Unfold admin theme
UNFOLD = {
    "SITE_TITLE": "Holdco",
    "SITE_HEADER": "Holdco",
}

# S3 / MinIO storage for documents
_storage_backend = os.environ.get("HOLDCO_STORAGE_BACKEND", "local")
if _storage_backend in ("s3", "minio"):
    DEFAULT_FILE_STORAGE = "storages.backends.s3boto3.S3Boto3Storage"
    AWS_ACCESS_KEY_ID = os.environ.get("AWS_ACCESS_KEY_ID", "")
    AWS_SECRET_ACCESS_KEY = os.environ.get("AWS_SECRET_ACCESS_KEY", "")
    AWS_STORAGE_BUCKET_NAME = os.environ.get("AWS_STORAGE_BUCKET_NAME", "holdco")
    AWS_S3_REGION_NAME = os.environ.get("AWS_S3_REGION_NAME", "us-east-1")
    if _storage_backend == "minio":
        AWS_S3_ENDPOINT_URL = os.environ.get("AWS_S3_ENDPOINT_URL", "http://localhost:9000")
        AWS_S3_USE_SSL = os.environ.get("AWS_S3_USE_SSL", "0") == "1"

# Encryption key for sensitive fields
FIELD_ENCRYPTION_KEY = os.environ.get("HOLDCO_ENCRYPTION_KEY", "")

# Email configuration
EMAIL_BACKEND = os.environ.get("EMAIL_BACKEND", "django.core.mail.backends.console.EmailBackend")
EMAIL_HOST = os.environ.get("EMAIL_HOST", "localhost")
EMAIL_PORT = int(os.environ.get("EMAIL_PORT", "587"))
EMAIL_USE_TLS = os.environ.get("EMAIL_USE_TLS", "1") == "1"
EMAIL_HOST_USER = os.environ.get("EMAIL_HOST_USER", "")
EMAIL_HOST_PASSWORD = os.environ.get("EMAIL_HOST_PASSWORD", "")
DEFAULT_FROM_EMAIL = os.environ.get("DEFAULT_FROM_EMAIL", "holdco@example.com")

# OpenTelemetry
if os.environ.get("HOLDCO_OTEL_ENABLED", "0") == "1":
    OTEL_EXPORTER_OTLP_ENDPOINT = os.environ.get("OTEL_EXPORTER_OTLP_ENDPOINT", "http://localhost:4317")
    OTEL_SERVICE_NAME = os.environ.get("OTEL_SERVICE_NAME", "holdco")
