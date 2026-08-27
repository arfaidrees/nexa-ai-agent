from pathlib import Path

import pytest

from product_service import compare_products, get_product_details, load_products, search_products


@pytest.fixture(scope="module")
def products():
    return load_products(Path(__file__).with_name("catalog.json"))


def test_load_products(products):
    assert len(products) >= 30
    assert all(product.id for product in products)


def test_search_by_price_and_category(products):
    results = search_products(products, category="phone", max_price=80000)
    assert results
    assert all(product.category == "phone" for product in results)
    assert all(product.price <= 80000 for product in results)


def test_search_by_brand(products):
    results = search_products(products, brand="Nexa")
    assert results
    assert all(product.brand == "Nexa" for product in results)


def test_search_by_features(products):
    results = search_products(products, category="headphones", features=["noise cancellation"])
    assert results
    assert all(product.category == "headphones" for product in results)
    assert all(product.attributes.get("noise_cancellation") is True for product in results)


def test_get_product_details(products):
    product = get_product_details(products, "phone-001")
    assert product.name == "Nexa Photon X1"


def test_compare_products(products):
    compared = compare_products(products, ["phone-001", "phone-003"])
    assert len(compared) == 2
    assert {product.id for product in compared} == {"phone-001", "phone-003"}


def test_compare_requires_two_products(products):
    with pytest.raises(ValueError):
        compare_products(products, ["phone-001"])

