import pytest

from core.management.commands.seed import do_seed, load_seed_data
from core.models import (
    AssetHolding,
    BankAccount,
    BoardMeeting,
    Category,
    Company,
    CustodianAccount,
    InsurancePolicy,
    Liability,
    ServiceProvider,
    Setting,
    Transaction,
)


def test_load_seed_data():
    data = load_seed_data()
    assert isinstance(data, dict)
    assert "settings" in data
    assert "categories" in data
    assert "companies" in data


@pytest.mark.django_db
def test_seed_populates_tables():
    do_seed()

    assert Company.objects.count() >= 1
    assert Category.objects.count() >= 1
    assert Setting.objects.filter(key="app_name").exists()
    assert AssetHolding.objects.count() >= 1
    assert BankAccount.objects.count() >= 1
    assert Transaction.objects.count() >= 1
    assert Liability.objects.count() >= 1
    assert ServiceProvider.objects.count() >= 1
    assert InsurancePolicy.objects.count() >= 1
    assert BoardMeeting.objects.count() >= 1


@pytest.mark.django_db
def test_seed_idempotent():
    do_seed()
    count_before = Company.objects.count()
    assert count_before >= 1

    do_seed()  # second call should skip
    count_after = Company.objects.count()
    assert count_after == count_before


@pytest.mark.django_db
def test_seed_creates_subsidiaries():
    do_seed()
    assert Company.objects.filter(parent__isnull=False).count() >= 1


@pytest.mark.django_db
def test_seed_creates_custodians():
    do_seed()
    assert CustodianAccount.objects.count() >= 1


@pytest.mark.django_db
def test_seed_export_structure():
    from core.views import _build_export

    do_seed()
    data = _build_export()
    assert len(data["entities"]) >= 1
    entity = data["entities"][0]
    assert "subsidiaries" in entity
    assert len(entity["subsidiaries"]) >= 1
