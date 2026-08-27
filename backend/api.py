"""FastAPI HTTP interface for the Nexa sales and support agent."""

from __future__ import annotations

from dataclasses import asdict
from typing import Any, Literal
from uuid import uuid4

from fastapi import FastAPI, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field
from google.genai.errors import ClientError, ServerError

from agent import NexaAgent
from lead_service import DATABASE_PATH, Lead, get_dashboard_summary, list_leads, update_lead_status
from product_service import get_product_details, load_products


app = FastAPI(title="Nexa API", version="1.0.0")
app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost", "http://127.0.0.1", "http://localhost:3000"],
    allow_origin_regex=r"https?://(localhost|127\.0\.0\.1)(:\d+)?$",
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

products = load_products()
sessions: dict[str, NexaAgent] = {}


class ChatRequest(BaseModel):
    session_id: str | None = Field(default=None, min_length=1)
    message: str = Field(min_length=1, max_length=4000)


class ChatResponse(BaseModel):
    session_id: str
    reply: str
    type: Literal["text", "product_results", "product_comparison"] = "text"
    data: dict[str, Any] | None = None


class StatusUpdate(BaseModel):
    status: Literal["new", "contacted", "qualified", "converted", "lost"]


def _friendly_api_error(exc: Exception) -> tuple[int, str]:
    message = str(exc).lower()
    if isinstance(exc, ClientError):
        if getattr(exc, "code", None) == 429 or "quota" in message or "rate limit" in message:
            return 429, "Gemini quota or rate limit reached. Please try again later."
        if getattr(exc, "code", None) in {401, 403}:
            return 503, "Gemini authentication is not configured correctly."
        return 502, "Gemini could not process the request."
    if isinstance(exc, ServerError):
        return 503, "Gemini is temporarily unavailable. Please try again later."
    return 500, "Nexa could not process the request."


def _lead_response(lead: Lead) -> dict[str, Any]:
    return asdict(lead)


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}


@app.post("/chat", response_model=ChatResponse)
def chat(request: ChatRequest) -> ChatResponse:
    session_id = request.session_id or uuid4().hex
    try:
        if session_id not in sessions:
            sessions[session_id] = NexaAgent()
        agent = sessions[session_id]
        reply = agent.send_message(request.message.strip())
        response_type = getattr(agent, "last_response_type", "text")
        response_data = getattr(agent, "last_response_data", None)
        if response_type not in {"text", "product_results", "product_comparison"}:
            response_type = "text"
            response_data = None
    except Exception as exc:
        status_code, detail = _friendly_api_error(exc)
        raise HTTPException(status_code=status_code, detail=detail) from None
    return ChatResponse(session_id=session_id, reply=reply, type=response_type, data=response_data)


@app.get("/products")
def product_list(
    category: str | None = Query(default=None),
    brand: str | None = Query(default=None),
    max_price: int | None = Query(default=None, ge=0),
) -> dict[str, Any]:
    from product_service import search_products

    results = search_products(products, category=category, brand=brand, max_price=max_price)
    return {"count": len(results), "products": [asdict(product) for product in results]}


@app.get("/products/{product_id}")
def product_details(product_id: str) -> dict[str, Any]:
    try:
        product = get_product_details(products, product_id)
    except ValueError:
        raise HTTPException(status_code=404, detail="Product not found") from None
    return {"product": asdict(product)}


@app.get("/leads")
def lead_list(status: Literal["new", "contacted", "qualified", "converted", "lost"] | None = None) -> dict[str, Any]:
    leads = list_leads(status=status, db_path=DATABASE_PATH)
    return {"count": len(leads), "leads": [_lead_response(lead) for lead in leads]}


@app.get("/dashboard/summary")
def dashboard_summary() -> dict[str, Any]:
    return get_dashboard_summary(db_path=DATABASE_PATH, products=products)


@app.patch("/leads/{lead_id}/status")
def lead_status(lead_id: int, request: StatusUpdate) -> dict[str, Any]:
    try:
        lead = update_lead_status(lead_id, request.status, db_path=DATABASE_PATH)
    except ValueError:
        raise HTTPException(status_code=404, detail="Lead not found") from None
    return {"lead": _lead_response(lead)}
