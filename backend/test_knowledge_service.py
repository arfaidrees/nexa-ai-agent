from pathlib import Path

import pytest

from knowledge_service import KnowledgeBase, chunk_documents, load_knowledge_documents


KNOWLEDGE_DIR = Path(__file__).parent / "data" / "knowledge"


@pytest.fixture(scope="module")
def knowledge_base():
    return KnowledgeBase(KNOWLEDGE_DIR)


def test_load_knowledge_documents():
    documents = load_knowledge_documents(KNOWLEDGE_DIR)
    assert len(documents) == 5
    assert {source for source, _, _ in documents} == {
        "faq.md",
        "payment_policy.md",
        "return_policy.md",
        "shipping.md",
        "warranty_policy.md",
    }


def test_chunking_creates_indexed_chunks():
    chunks = chunk_documents([("example.md", "Example", "one two three four five six")], chunk_size=4, overlap=1)
    assert len(chunks) == 2
    assert chunks[0].chunk_id
    assert chunks[0].source == "example.md"
    assert "four" in chunks[0].content
    assert "four" in chunks[1].content


def test_retrieval_finds_relevant_policy(knowledge_base):
    results = knowledge_base.search_knowledge("Can opened products be returned?")
    assert results
    assert results[0].source == "return_policy.md"
    assert "14 calendar days" in results[0].content


def test_retrieval_finds_installment_answer(knowledge_base):
    results = knowledge_base.search_knowledge("Do you offer installment plans?")
    assert results
    assert results[0].source == "payment_policy.md"
    assert "not currently offered" in results[0].content


def test_retrieval_prefers_dedicated_policy_source(knowledge_base):
    result = knowledge_base.search_knowledge("warranty")[0]
    assert result.source == "warranty_policy.md"


def test_irrelevant_query_returns_no_match(knowledge_base):
    assert knowledge_base.search_knowledge("Do you repair bicycles?") == []


def test_source_metadata_is_returned(knowledge_base):
    result = knowledge_base.search_knowledge("How long does delivery take?")[0]
    assert result.source == "shipping.md"
    assert result.title == "Shipping and Delivery"
