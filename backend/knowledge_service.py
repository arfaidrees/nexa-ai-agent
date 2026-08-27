"""Small local retrieval service for Nexa's company knowledge."""

from __future__ import annotations

import re
from dataclasses import asdict, dataclass
from pathlib import Path


KNOWLEDGE_DIR = Path(__file__).with_name("data") / "knowledge"
_WORD_PATTERN = re.compile(r"[a-z0-9]+")
_STOP_WORDS = {
    "a",
    "an",
    "and",
    "are",
    "be",
    "can",
    "do",
    "does",
    "for",
    "how",
    "i",
    "is",
    "me",
    "of",
    "offer",
    "the",
    "to",
    "what",
    "when",
    "your",
    "you",
}


@dataclass(frozen=True)
class KnowledgeChunk:
    """A searchable piece of a source document."""

    chunk_id: str
    source: str
    title: str
    content: str


def _tokens(text: str) -> set[str]:
    return {
        token[:-1] if token.endswith("s") and len(token) > 4 else token
        for token in _WORD_PATTERN.findall(text.lower())
        if token not in _STOP_WORDS
    }


def load_knowledge_documents(knowledge_dir: Path | str = KNOWLEDGE_DIR) -> list[tuple[str, str, str]]:
    """Load Markdown documents as (source filename, title, content)."""

    directory = Path(knowledge_dir)
    documents: list[tuple[str, str, str]] = []
    for path in sorted(directory.glob("*.md")):
        content = path.read_text(encoding="utf-8").strip()
        if not content:
            continue
        title = path.stem.replace("_", " ").title()
        heading = re.search(r"^#\s+(.+)$", content, flags=re.MULTILINE)
        if heading:
            title = heading.group(1).strip()
        documents.append((path.name, title, content))
    return documents


def chunk_documents(
    documents: list[tuple[str, str, str]],
    *,
    chunk_size: int = 120,
    overlap: int = 25,
) -> list[KnowledgeChunk]:
    """Split documents into readable, overlapping word chunks."""

    if chunk_size <= 0 or overlap < 0 or overlap >= chunk_size:
        raise ValueError("chunk_size must be positive and overlap must be smaller than chunk_size")

    chunks: list[KnowledgeChunk] = []
    for source, title, content in documents:
        words = content.split()
        step = chunk_size - overlap
        for start in range(0, len(words), step):
            chunk_words = words[start : start + chunk_size]
            if not chunk_words:
                break
            chunks.append(
                KnowledgeChunk(
                    chunk_id=f"{Path(source).stem}-{len(chunks) + 1}",
                    source=source,
                    title=title,
                    content=" ".join(chunk_words),
                )
            )
            if start + chunk_size >= len(words):
                break
    return chunks


class KnowledgeBase:
    """In-memory retrieval index backed by local Markdown files."""

    def __init__(self, knowledge_dir: Path | str = KNOWLEDGE_DIR) -> None:
        self.knowledge_dir = Path(knowledge_dir)
        self.documents = load_knowledge_documents(self.knowledge_dir)
        self.chunks = chunk_documents(self.documents)
        self._chunk_tokens = [_tokens(chunk.content) for chunk in self.chunks]

    def search_knowledge(self, query: str, top_k: int = 3) -> list[KnowledgeChunk]:
        """Return relevant chunks, or [] when the local knowledge has no answer."""

        if not query.strip() or top_k <= 0:
            return []

        query_tokens = _tokens(query)
        if not query_tokens:
            return []

        scored: list[tuple[float, int, KnowledgeChunk]] = []
        query_lower = query.lower()
        for index, chunk in enumerate(self.chunks):
            overlap = query_tokens & self._chunk_tokens[index]
            if not overlap:
                continue
            if len(query_tokens) > 1 and len(overlap) < 2:
                continue
            score = len(overlap) / len(query_tokens)
            if query_tokens & _tokens(chunk.title):
                score += 0.15
            if query_lower in chunk.content.lower():
                score += 0.25
            scored.append((score, index, chunk))

        scored.sort(key=lambda item: (-item[0], item[1]))
        # One matching generic word is not enough to claim a policy answer.
        return [chunk for score, _, chunk in scored if score >= 0.20][:top_k]


def search_knowledge(query: str, top_k: int = 3) -> list[dict[str, str]]:
    """Convenience function for callers that do not need to retain an index."""

    return [asdict(chunk) for chunk in KnowledgeBase().search_knowledge(query, top_k)]
