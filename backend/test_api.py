from pathlib import Path

from fastapi.testclient import TestClient

import api
from lead_service import create_lead
from product_service import load_products


class FakeAgent:
    def __init__(self):
        self.messages = []
        self.last_response_type = "text"
        self.last_response_data = None

    def send_message(self, message: str) -> str:
        self.messages.append(message)
        return f"Echo: {message}"


def test_health():
    client = TestClient(api.app)
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json() == {"status": "ok"}


def test_product_listing():
    response = TestClient(api.app).get("/products", params={"category": "phone", "max_price": 80000})
    assert response.status_code == 200
    body = response.json()
    assert body["count"] > 0
    assert all(product["category"] == "phone" and product["price"] <= 80000 for product in body["products"])


def test_product_lookup_and_invalid_product():
    client = TestClient(api.app)
    assert client.get("/products/phone-001").status_code == 200
    response = client.get("/products/not-a-product")
    assert response.status_code == 404
    assert response.json() == {"detail": "Product not found"}


def test_lead_listing_and_status_update(monkeypatch, tmp_path: Path):
    db_path = tmp_path / "api.db"
    monkeypatch.setattr(api, "DATABASE_PATH", db_path)
    lead = create_lead("Arfa", "arfa@example.com", "phone-001", db_path=db_path, products=load_products())
    client = TestClient(api.app)

    response = client.get("/leads")
    assert response.status_code == 200
    assert response.json()["leads"][0]["id"] == lead.id

    response = client.patch(f"/leads/{lead.id}/status", json={"status": "contacted"})
    assert response.status_code == 200
    assert response.json()["lead"]["status"] == "contacted"


def test_dashboard_summary(monkeypatch, tmp_path: Path):
    db_path = tmp_path / "dashboard.db"
    monkeypatch.setattr(api, "DATABASE_PATH", db_path)
    catalog = load_products()
    create_lead("Arfa", "arfa@example.com", "phone-001", db_path=db_path, products=catalog)
    create_lead("Bilal", "bilal@example.com", "phone-001", db_path=db_path, products=catalog)
    contacted = create_lead("Sana", "sana@example.com", "laptop-001", db_path=db_path, products=catalog)
    from lead_service import update_lead_status
    update_lead_status(contacted.id, "contacted", db_path=db_path)

    response = TestClient(api.app).get("/dashboard/summary")
    assert response.status_code == 200
    assert response.json() == {
        "total_leads": 3,
        "new_leads": 2,
        "contacted_leads": 1,
        "total_products": 30,
        "top_interested_products": [
            {"product_id": "phone-001", "name": "Nexa Photon X1", "lead_count": 2},
            {"product_id": "laptop-001", "name": "Nexa AirBook 13", "lead_count": 1},
        ],
    }


def test_chat_with_mocked_gemini(monkeypatch):
    api.sessions.clear()
    monkeypatch.setattr(api, "NexaAgent", FakeAgent)
    client = TestClient(api.app)
    response = client.post("/chat", json={"session_id": "demo", "message": "Hello"})
    assert response.status_code == 200
    assert response.json() == {
        "session_id": "demo",
        "reply": "Echo: Hello",
        "type": "text",
        "data": None,
    }


def test_chat_returns_catalog_backed_product_results(monkeypatch):
    class ProductAgent(FakeAgent):
        def send_message(self, message: str) -> str:
            self.last_response_type = "product_results"
            self.last_response_data = {
                "products": [{
                    "id": "phone-001",
                    "name": "Nexa Photon X1",
                    "brand": "Nexa",
                    "category": "phone",
                    "price": 69999,
                    "rating": 4.6,
                    "stock": 12,
                    "attributes": {"camera": "50MP"},
                }]
            }
            return "I found one good option."

    api.sessions.clear()
    monkeypatch.setattr(api, "NexaAgent", ProductAgent)
    response = TestClient(api.app).post("/chat", json={"message": "Find a phone"})
    body = response.json()
    assert body["type"] == "product_results"
    assert body["data"]["products"][0]["id"] == "phone-001"
    assert body["data"]["products"][0]["price"] == 69999


def test_chat_returns_product_comparison(monkeypatch):
    class ComparisonAgent(FakeAgent):
        def send_message(self, message: str) -> str:
            self.last_response_type = "product_comparison"
            self.last_response_data = {
                "products": [
                    {"id": "phone-001", "name": "Nexa Photon X1", "price": 69999, "rating": 4.6, "stock": 12, "attributes": {}},
                    {"id": "phone-003", "name": "Nexa Photon X3", "price": 89999, "rating": 4.8, "stock": 8, "attributes": {}},
                ]
            }
            return "Here is the comparison."

    api.sessions.clear()
    monkeypatch.setattr(api, "NexaAgent", ComparisonAgent)
    response = TestClient(api.app).post("/chat", json={"message": "Compare these"})
    body = response.json()
    assert body["type"] == "product_comparison"
    assert len(body["data"]["products"]) == 2


def test_chat_error_is_clean(monkeypatch):
    class BrokenAgent:
        def send_message(self, message: str) -> str:
            raise RuntimeError("secret traceback details")

    api.sessions.clear()
    monkeypatch.setattr(api, "NexaAgent", BrokenAgent)
    response = TestClient(api.app).post("/chat", json={"message": "Hello"})
    assert response.status_code == 500
    assert response.json() == {"detail": "Nexa could not process the request."}
