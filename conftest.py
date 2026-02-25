import django
from django.conf import settings


def pytest_configure():
    import os
    os.environ.setdefault("DJANGO_SETTINGS_MODULE", "holdco.settings")
    django.setup()


import pytest
from django.contrib.auth import get_user_model
from django.test import Client

from core.models import UserRole


def _make_client(db, username, role):
    User = get_user_model()
    user = User.objects.create_user(
        username=username, email=f"{username}@example.com", password="testpass123"
    )
    UserRole.objects.create(user=user, role=role)
    client = Client()
    client.force_login(user)
    return client


@pytest.fixture
def logged_in_client(db):
    """Backwards-compatible fixture — creates an admin user so existing tests pass."""
    return _make_client(db, "testuser", "admin")


@pytest.fixture
def admin_client(db):
    return _make_client(db, "adminuser", "admin")


@pytest.fixture
def editor_client(db):
    return _make_client(db, "editoruser", "editor")


@pytest.fixture
def viewer_client(db):
    return _make_client(db, "vieweruser", "viewer")
