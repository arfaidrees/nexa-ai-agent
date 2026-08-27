"""Deterministic SQLite persistence and validation for sales leads."""

from __future__ import annotations

import re
import sqlite3
from dataclasses import asdict, dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Iterable

from product_service import Product


DATABASE_PATH = Path(__file__).with_name("data") / "nexa.db"
VALID_STATUSES = {"new", "contacted", "qualified", "converted", "lost"}
_EMAIL_PATTERN = re.compile(r"^[^\s@]+@[^\s@]+\.[^\s@]+$")


@dataclass(frozen=True)
class Lead:
    id: int
    name: str
    email: str
    phone: str | None
    interested_product: str
    budget: int | None
    notes: str | None
    status: str
    created_at: str


def initialize_database(db_path: Path | str = DATABASE_PATH) -> None:
    """Create the local database and leads table if they do not exist."""

    path = Path(db_path)
    path.parent.mkdir(parents=True, exist_ok=True)
    with sqlite3.connect(path) as connection:
        connection.execute(
            """
            CREATE TABLE IF NOT EXISTS leads (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                name TEXT NOT NULL,
                email TEXT NOT NULL,
                phone TEXT,
                interested_product TEXT NOT NULL,
                budget INTEGER,
                notes TEXT,
                status TEXT NOT NULL DEFAULT 'new',
                created_at TEXT NOT NULL
            )
            """
        )


def _row_to_lead(row: sqlite3.Row) -> Lead:
    return Lead(**dict(row))


def _validate_email(email: str) -> str:
    value = email.strip()
    if not _EMAIL_PATTERN.match(value):
        raise ValueError("Please provide a valid email address")
    return value


def _resolve_product(product_reference: str, products: Iterable[Product] | None) -> str:
    reference = product_reference.strip()
    if not reference:
        raise ValueError("interested_product is required")
    if products is None:
        return reference

    reference_lower = reference.lower()
    for product in products:
        if product.id.lower() == reference_lower or product.name.lower() == reference_lower:
            return product.id
    raise ValueError(f"Unknown product: {product_reference}")


def create_lead(
    name: str,
    email: str,
    interested_product: str,
    *,
    phone: str | None = None,
    budget: int | None = None,
    notes: str | None = None,
    status: str = "new",
    db_path: Path | str = DATABASE_PATH,
    products: Iterable[Product] | None = None,
) -> Lead:
    """Validate and persist one lead, returning the stored record."""

    clean_name = name.strip()
    if not clean_name:
        raise ValueError("name is required")
    clean_email = _validate_email(email)
    clean_product = _resolve_product(interested_product, products)
    if budget is not None and budget < 0:
        raise ValueError("budget cannot be negative")
    if status not in VALID_STATUSES:
        raise ValueError(f"Invalid status: {status}")

    initialize_database(db_path)
    created_at = datetime.now(timezone.utc).isoformat()
    with sqlite3.connect(db_path) as connection:
        cursor = connection.execute(
            """
            INSERT INTO leads (name, email, phone, interested_product, budget, notes, status, created_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (clean_name, clean_email, phone, clean_product, budget, notes, status, created_at),
        )
        lead_id = cursor.lastrowid
    return get_lead(lead_id, db_path=db_path)


def get_lead(lead_id: int, *, db_path: Path | str = DATABASE_PATH) -> Lead:
    initialize_database(db_path)
    with sqlite3.connect(db_path) as connection:
        connection.row_factory = sqlite3.Row
        row = connection.execute("SELECT * FROM leads WHERE id = ?", (lead_id,)).fetchone()
    if row is None:
        raise ValueError(f"Unknown lead id: {lead_id}")
    return _row_to_lead(row)


def list_leads(*, status: str | None = None, db_path: Path | str = DATABASE_PATH) -> list[Lead]:
    initialize_database(db_path)
    if status is not None and status not in VALID_STATUSES:
        raise ValueError(f"Invalid status: {status}")
    with sqlite3.connect(db_path) as connection:
        connection.row_factory = sqlite3.Row
        if status is None:
            rows = connection.execute("SELECT * FROM leads ORDER BY id").fetchall()
        else:
            rows = connection.execute(
                "SELECT * FROM leads WHERE status = ? ORDER BY id", (status,)
            ).fetchall()
    return [_row_to_lead(row) for row in rows]


def get_dashboard_summary(
    *,
    db_path: Path | str = DATABASE_PATH,
    products: Iterable[Product] = (),
) -> dict[str, Any]:
    """Return small, deterministic aggregates for the read-only dashboard."""

    initialize_database(db_path)
    with sqlite3.connect(db_path) as connection:
        total_leads = connection.execute("SELECT COUNT(*) FROM leads").fetchone()[0]
        status_counts = dict(
            connection.execute("SELECT status, COUNT(*) FROM leads GROUP BY status").fetchall()
        )
        product_counts = connection.execute(
            "SELECT interested_product, COUNT(*) AS lead_count "
            "FROM leads GROUP BY interested_product ORDER BY lead_count DESC, interested_product LIMIT 5"
        ).fetchall()

    product_names = {product.id: product.name for product in products}
    top_products = [
        {
            "product_id": product_id,
            "name": product_names.get(product_id, product_id),
            "lead_count": lead_count,
        }
        for product_id, lead_count in product_counts
    ]
    return {
        "total_leads": total_leads,
        "new_leads": status_counts.get("new", 0),
        "contacted_leads": status_counts.get("contacted", 0),
        "total_products": sum(1 for _ in products),
        "top_interested_products": top_products,
    }


def update_lead_status(
    lead_id: int,
    status: str,
    *,
    db_path: Path | str = DATABASE_PATH,
) -> Lead:
    if status not in VALID_STATUSES:
        raise ValueError(f"Invalid status: {status}")
    initialize_database(db_path)
    with sqlite3.connect(db_path) as connection:
        cursor = connection.execute("UPDATE leads SET status = ? WHERE id = ?", (status, lead_id))
        if cursor.rowcount == 0:
            raise ValueError(f"Unknown lead id: {lead_id}")
    return get_lead(lead_id, db_path=db_path)


def lead_to_dict(lead: Lead) -> dict[str, Any]:
    return asdict(lead)
