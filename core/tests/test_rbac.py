import pytest
from django.contrib.auth import get_user_model
from django.test import Client

from core.models import UserRole, get_user_role


# --- Helper ---


@pytest.fixture
def company_id(admin_client):
    r = admin_client.post(
        "/api/companies",
        {"name": "Co", "country": "US", "category": "T"},
        content_type="application/json",
    )
    return r.json()["id"]


# --- get_user_role helper ---


@pytest.mark.django_db
def test_default_role_is_viewer():
    User = get_user_model()
    user = User.objects.create_user(username="norole", password="pass")
    assert get_user_role(user) == "viewer"


@pytest.mark.django_db
def test_explicit_role():
    User = get_user_model()
    user = User.objects.create_user(username="ed", password="pass")
    UserRole.objects.create(user=user, role="editor")
    assert get_user_role(user) == "editor"


# --- Viewer: read-only ---


def test_viewer_can_read(viewer_client):
    r = viewer_client.get("/api/companies")
    assert r.status_code == 200


def test_viewer_cannot_create(viewer_client):
    r = viewer_client.post(
        "/api/companies",
        {"name": "X", "country": "US", "category": "T"},
        content_type="application/json",
    )
    assert r.status_code == 403


def test_viewer_cannot_update(viewer_client, company_id):
    r = viewer_client.put(
        f"/api/companies/{company_id}",
        {"name": "X2"},
        content_type="application/json",
    )
    assert r.status_code == 403


def test_viewer_cannot_delete(viewer_client, company_id):
    r = viewer_client.delete(f"/api/companies/{company_id}")
    assert r.status_code == 403


# --- Editor: create/read/update, no delete ---


def test_editor_can_read(editor_client):
    r = editor_client.get("/api/companies")
    assert r.status_code == 200


def test_editor_can_create(editor_client):
    r = editor_client.post(
        "/api/companies",
        {"name": "EdCo", "country": "US", "category": "T"},
        content_type="application/json",
    )
    assert r.status_code == 201


def test_editor_can_update(editor_client, company_id):
    r = editor_client.put(
        f"/api/companies/{company_id}",
        {"name": "Updated"},
        content_type="application/json",
    )
    assert r.status_code == 200


def test_editor_cannot_delete(editor_client, company_id):
    r = editor_client.delete(f"/api/companies/{company_id}")
    assert r.status_code == 403


# --- Admin: full access ---


def test_admin_can_read(admin_client):
    r = admin_client.get("/api/companies")
    assert r.status_code == 200


def test_admin_can_create(admin_client):
    r = admin_client.post(
        "/api/companies",
        {"name": "AdCo", "country": "US", "category": "T"},
        content_type="application/json",
    )
    assert r.status_code == 201


def test_admin_can_update(admin_client, company_id):
    r = admin_client.put(
        f"/api/companies/{company_id}",
        {"name": "Updated"},
        content_type="application/json",
    )
    assert r.status_code == 200


def test_admin_can_delete(admin_client, company_id):
    r = admin_client.delete(f"/api/companies/{company_id}")
    assert r.status_code == 200


# --- No UserRole row defaults to viewer ---


@pytest.mark.django_db
def test_no_role_row_defaults_to_viewer():
    User = get_user_model()
    user = User.objects.create_user(
        username="newguy", email="new@example.com", password="pass"
    )
    client = Client()
    client.force_login(user)

    # Can read
    r = client.get("/api/companies")
    assert r.status_code == 200

    # Cannot create
    r = client.post(
        "/api/companies",
        {"name": "X", "country": "US", "category": "T"},
        content_type="application/json",
    )
    assert r.status_code == 403


# --- /api/me endpoint ---


def test_me_endpoint_admin(admin_client):
    r = admin_client.get("/api/me")
    assert r.status_code == 200
    data = r.json()
    assert data["username"] == "adminuser"
    assert data["role"] == "admin"


def test_me_endpoint_viewer(viewer_client):
    r = viewer_client.get("/api/me")
    assert r.status_code == 200
    assert r.json()["role"] == "viewer"


# --- Admin middleware ---


def test_admin_panel_requires_admin_role(viewer_client):
    r = viewer_client.get("/admin/")
    assert r.status_code == 403


def test_admin_panel_allowed_for_admin(admin_client):
    r = admin_client.get("/admin/")
    # Admin redirects to login page or shows admin; either way not 403
    assert r.status_code != 403
