from __future__ import annotations

import os
from dataclasses import asdict
from typing import Any

from dotenv import load_dotenv
from google import genai

from product_service import Product, compare_products, get_product_details, load_products, search_products
from knowledge_service import KnowledgeBase
from lead_service import (
    DATABASE_PATH,
    create_lead,
    get_lead,
    initialize_database,
    lead_to_dict,
    list_leads,
    update_lead_status,
)


def _product_to_dict(product: Product) -> dict[str, Any]:
    return asdict(product)


def _product_summary(product: Product) -> dict[str, Any]:
    """Expose only catalog-backed fields needed by a customer product card."""

    return {
        "id": product.id,
        "name": product.name,
        "brand": product.brand,
        "category": product.category,
        "price": product.price,
        "rating": product.rating,
        "stock": product.stock,
        "attributes": dict(list(product.attributes.items())[:5]),
    }


class NexaAgent:
    def __init__(self, model: str = "gemini-3.6-flash") -> None:
        load_dotenv()
        api_key = os.getenv("GEMINI_API_KEY")
        if not api_key:
            raise RuntimeError("GEMINI_API_KEY is not set in the environment.")

        self.products = load_products()
        self.knowledge_base = KnowledgeBase()
        initialize_database(DATABASE_PATH)
        self.last_response_type = "text"
        self.last_response_data: dict[str, Any] | None = None
        self.client = genai.Client(api_key=api_key)
        self.chat = self.client.chats.create(
            model=model,
            config={
                "system_instruction": (
                    "You are Nexa, a concise and helpful sales and customer support advisor. "
                    "Use product tools for catalog facts and search_knowledge for company policies. "
                    "Never invent product or policy information. If search_knowledge returns no results, "
                    "say the local knowledge base does not contain the answer. For policy answers, mention "
                    "the source document when useful. Preserve conversation context and respect budgets. "
                    "When a customer wants contact, collect the missing name, email, and product details "
                    "across the conversation before calling create_lead. Only confirm a lead after the tool "
                    "returns success=true."
                ),
                "tools": [
                    self.search_products,
                    self.get_product_details,
                    self.compare_products,
                    self.search_knowledge,
                    self.create_lead,
                    self.get_lead,
                    self.list_leads,
                    self.update_lead_status,
                ],
            },
        )

    def search_products(
        self,
        query: str | None = None,
        category: str | None = None,
        brand: str | None = None,
        min_price: int | None = None,
        max_price: int | None = None,
        min_rating: float | None = None,
        in_stock: bool | None = None,
        features: list[str] | None = None,
    ) -> dict[str, Any]:
        results = search_products(
            self.products,
            query=query,
            category=category,
            brand=brand,
            min_price=min_price,
            max_price=max_price,
            min_rating=min_rating,
            in_stock=in_stock,
            features=features,
        )
        self.last_response_type = "product_results"
        self.last_response_data = {"products": [_product_summary(product) for product in results]}
        return {"count": len(results), "products": [_product_to_dict(product) for product in results]}

    def get_product_details(self, product_id: str) -> dict[str, Any]:
        product = get_product_details(self.products, product_id)
        self.last_response_type = "product_results"
        self.last_response_data = {"products": [_product_summary(product)]}
        return {"product": _product_to_dict(product)}

    def compare_products(self, product_ids: list[str]) -> dict[str, Any]:
        products = compare_products(self.products, product_ids)
        self.last_response_type = "product_comparison"
        self.last_response_data = {"products": [_product_summary(product) for product in products]}
        return {"products": [_product_to_dict(product) for product in products]}

    def search_knowledge(self, query: str, top_k: int = 3) -> dict[str, Any]:
        results = self.knowledge_base.search_knowledge(query, top_k=top_k)
        return {
            "count": len(results),
            "results": [
                {
                    "source": result.source,
                    "title": result.title,
                    "content": result.content,
                }
                for result in results
            ],
        }

    def create_lead(
        self,
        name: str,
        email: str,
        interested_product: str,
        phone: str | None = None,
        budget: int | None = None,
        notes: str | None = None,
    ) -> dict[str, Any]:
        try:
            lead = create_lead(
                name,
                email,
                interested_product,
                phone=phone,
                budget=budget,
                notes=notes,
                db_path=DATABASE_PATH,
                products=self.products,
            )
        except (ValueError, OSError) as exc:
            return {"success": False, "error": str(exc)}
        return {"success": True, "lead": lead_to_dict(lead)}

    def get_lead(self, lead_id: int) -> dict[str, Any]:
        try:
            lead = get_lead(lead_id, db_path=DATABASE_PATH)
        except (ValueError, OSError) as exc:
            return {"success": False, "error": str(exc)}
        return {"success": True, "lead": lead_to_dict(lead)}

    def list_leads(self, status: str | None = None) -> dict[str, Any]:
        try:
            leads = list_leads(status=status, db_path=DATABASE_PATH)
        except (ValueError, OSError) as exc:
            return {"success": False, "error": str(exc)}
        return {
            "success": True,
            "count": len(leads),
            "leads": [lead_to_dict(lead) for lead in leads],
        }

    def update_lead_status(self, lead_id: int, status: str) -> dict[str, Any]:
        try:
            lead = update_lead_status(lead_id, status, db_path=DATABASE_PATH)
        except (ValueError, OSError) as exc:
            return {"success": False, "error": str(exc)}
        return {"success": True, "lead": lead_to_dict(lead)}

    def send_message(self, message: str) -> str:
        self.last_response_type = "text"
        self.last_response_data = None
        response = self.chat.send_message(message)
        return getattr(response, "text", "") or ""
