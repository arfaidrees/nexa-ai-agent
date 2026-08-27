from __future__ import annotations

import json
from dataclasses import dataclass
from pathlib import Path
from typing import Any


CATALOG_PATH = Path(__file__).with_name("catalog.json")


@dataclass(frozen=True)
class Product:
    id: str
    name: str
    brand: str
    category: str
    price: int
    description: str
    stock: int
    rating: float
    attributes: dict[str, Any]


def load_products(path: Path | str = CATALOG_PATH) -> list[Product]:
    catalog_path = Path(path)
    with catalog_path.open("r", encoding="utf-8") as handle:
        raw_products = json.load(handle)
    return [Product(**item) for item in raw_products]


def _normalize_text(value: str) -> str:
    return value.strip().lower()


def _matches_feature(product: Product, feature: str) -> bool:
    feature_text = _normalize_text(feature)
    haystack = " ".join(
        [
            product.name,
            product.brand,
            product.category,
            product.description,
            " ".join(f"{key}:{value}" for key, value in product.attributes.items()),
        ]
    ).lower()
    return feature_text in haystack


def search_products(
    products: list[Product],
    *,
    query: str | None = None,
    category: str | None = None,
    brand: str | None = None,
    min_price: int | None = None,
    max_price: int | None = None,
    min_rating: float | None = None,
    in_stock: bool | None = None,
    features: list[str] | None = None,
) -> list[Product]:
    results = list(products)

    if query:
        query_value = _normalize_text(query)
        results = [
            product
            for product in results
            if query_value in " ".join(
                [
                    product.name,
                    product.brand,
                    product.category,
                    product.description,
                ]
            ).lower()
        ]

    if category:
        category_value = _normalize_text(category)
        results = [product for product in results if _normalize_text(product.category) == category_value]

    if brand:
        brand_value = _normalize_text(brand)
        results = [product for product in results if _normalize_text(product.brand) == brand_value]

    if min_price is not None:
        results = [product for product in results if product.price >= min_price]

    if max_price is not None:
        results = [product for product in results if product.price <= max_price]

    if min_rating is not None:
        results = [product for product in results if product.rating >= min_rating]

    if in_stock is True:
        results = [product for product in results if product.stock > 0]
    elif in_stock is False:
        results = [product for product in results if product.stock <= 0]

    if features:
        results = [
            product
            for product in results
            if all(_matches_feature(product, feature) for feature in features)
        ]

    return results


def get_product_details(products: list[Product], product_id: str) -> Product:
    for product in products:
        if product.id == product_id:
            return product
    raise ValueError(f"Unknown product id: {product_id}")


def compare_products(products: list[Product], product_ids: list[str]) -> list[Product]:
    if len(product_ids) < 2:
        raise ValueError("compare_products requires at least two product ids")

    compared: list[Product] = []
    seen: set[str] = set()
    for product_id in product_ids:
        if product_id in seen:
            continue
        compared.append(get_product_details(products, product_id))
        seen.add(product_id)
    return compared

