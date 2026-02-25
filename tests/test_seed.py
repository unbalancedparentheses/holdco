import db
from seed import load_seed_data, seed


def test_load_seed_data():
    data = load_seed_data()
    assert isinstance(data, dict)
    assert "settings" in data
    assert "categories" in data
    assert "companies" in data


def test_seed_populates_tables(tmp_db):
    seed()

    companies = db.get_all_companies()
    assert len(companies) >= 1

    categories = db.get_categories()
    assert len(categories) >= 1

    settings = db.get_all_settings()
    assert "app_name" in settings

    stats = db.get_stats()
    assert stats["total_companies"] >= 1
    assert stats["asset_holdings"] >= 1
    assert stats["bank_accounts"] >= 1
    assert stats["transactions"] >= 1
    assert stats["liabilities"] >= 1
    assert stats["service_providers"] >= 1
    assert stats["insurance_policies"] >= 1
    assert stats["board_meetings"] >= 1


def test_seed_idempotent(tmp_db):
    seed()
    count_before = len(db.get_all_companies())
    assert count_before >= 1

    seed()  # second call should skip
    count_after = len(db.get_all_companies())
    assert count_after == count_before


def test_seed_creates_subsidiaries(tmp_db):
    seed()
    stats = db.get_stats()
    assert stats["subsidiaries"] >= 1


def test_seed_creates_custodians(tmp_db):
    seed()
    stats = db.get_stats()
    assert stats["custodian_accounts"] >= 1


def test_seeded_db_fixture(seeded_db):
    assert len(db.get_all_companies()) >= 1
    assert len(db.get_categories()) >= 1


def test_seed_export_structure(tmp_db):
    seed()
    data = db.export_json()
    assert len(data["entities"]) >= 1
    entity = data["entities"][0]
    assert "subsidiaries" in entity
    assert len(entity["subsidiaries"]) >= 1
