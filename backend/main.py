from __future__ import annotations

from google.genai.errors import ClientError, ServerError

from agent import NexaAgent


def _friendly_error_message(exc: Exception) -> str:
    """Convert Gemini API errors into readable messages."""

    message = str(exc)

    if isinstance(exc, ClientError):
        if getattr(exc, "code", None) == 429 or "quota" in message.lower():
            return (
                "Gemini quota or rate limit reached. "
                "Please wait a bit and try again."
            )

        if getattr(exc, "code", None) in {401, 403}:
            return (
                "Gemini authentication failed. "
                "Please check your API key."
            )

        return f"Gemini request failed: {message}"

    if isinstance(exc, ServerError):
        return (
            "Gemini is temporarily unavailable. "
            "Please try again later."
        )

    return (
        "Something went wrong while processing your request. "
        "Please try again."
    )


def main() -> None:
    try:
        agent = NexaAgent()
    except Exception as exc:
        print(f"Agent init error: {_friendly_error_message(exc)}")
        return

    print("Nexa AI Sales Agent")
    print("Type your message, or 'exit'/'quit' to leave.\n")

    while True:
        try:
            user_message = input("You: ").strip()

        except (EOFError, KeyboardInterrupt):
            print("\nAgent: Goodbye!")
            break

        if user_message.lower() in {"exit", "quit"}:
            print("Agent: Goodbye!")
            break

        if not user_message:
            continue

        try:
            reply = agent.send_message(user_message)
            print(f"\nNexa: {reply}\n")

        except (ClientError, ServerError) as exc:
            print(f"\nNexa: {_friendly_error_message(exc)}\n")

        except Exception as exc:
            print(f"\nNexa: {_friendly_error_message(exc)}\n")


if __name__ == "__main__":
    main()