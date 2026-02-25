import pytest

import db


@pytest.fixture
def tmp_db(tmp_path):
    """Fresh empty database for each test."""
    db_file = tmp_path / "test.db"
    original = db.DB_PATH
    db.DB_PATH = db_file
    db.init_db()
    yield db_file
    db.DB_PATH = original


@pytest.fixture
def seeded_db(tmp_db):
    """Database pre-populated with seed.example.json data."""
    from seed import seed

    seed()
    return tmp_db


@pytest.fixture
def client(tmp_db):
    from fastapi.testclient import TestClient

    from api import app

    return TestClient(app)


@pytest.fixture
def company_id(tmp_db):
    """Insert a test company and return its ID."""
    return db.insert_company("Test Corp", "United States", "Technology")
