import sqlite3

import pytest

from lead_service import (
    create_lead,
    get_lead,
    initialize_database,
    list_leads,
    update_lead_status,
)
from product_service import load_products


@pytest.fixture
def products():
    return load_products()


@pytest.fixture
def db_path(tmp_path):
    return tmp_path / "test_nexa.db"


def test_database_initialization(db_path):
    initialize_database(db_path)
    with sqlite3.connect(db_path) as connection:
        tables = connection.execute(
            "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'leads'"
        ).fetchall()
    assert tables == [("leads",)]


def test_valid_lead_creation(db_path, products):
    lead = create_lead(
        "Arfa",
        "arfahere@example.com",
        "Nexa Photon X1",
        phone="03001234567",
        budget=80000,
        notes="Interested in camera quality",
        db_path=db_path,
        products=products,
    )
    assert lead.id == 1
    assert lead.interested_product == "phone-001"
    assert lead.status == "new"
    assert lead.created_at


def test_missing_name_is_rejected(db_path, products):
    with pytest.raises(ValueError, match="name is required"):
        create_lead("  ", "person@example.com", "phone-001", db_path=db_path, products=products)


def test_invalid_email_is_rejected(db_path, products):
    with pytest.raises(ValueError, match="valid email"):
        create_lead("Arfa", "not-an-email", "phone-001", db_path=db_path, products=products)


def test_invalid_product_reference_is_rejected(db_path, products):
    with pytest.raises(ValueError, match="Unknown product"):
        create_lead("Arfa", "person@example.com", "imaginary-phone", db_path=db_path, products=products)


def test_lead_lookup_and_listing(db_path, products):
    first = create_lead("Arfa", "arfa@example.com", "phone-001", db_path=db_path, products=products)
    create_lead("Bilal", "bilal@example.com", "laptop-001", db_path=db_path, products=products)
    assert get_lead(first.id, db_path=db_path).email == "arfa@example.com"
    assert len(list_leads(db_path=db_path)) == 2
    assert len(list_leads(status="new", db_path=db_path)) == 2


def test_status_update(db_path, products):
    lead = create_lead("Arfa", "arfa@example.com", "phone-001", db_path=db_path, products=products)
    updated = update_lead_status(lead.id, "contacted", db_path=db_path)
    assert updated.status == "contacted"
    assert list_leads(status="contacted", db_path=db_path) == [updated]
