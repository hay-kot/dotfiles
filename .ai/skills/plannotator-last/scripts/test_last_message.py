import importlib.util
import json
import tempfile
import unittest
from pathlib import Path


SCRIPT = Path(__file__).with_name("last-message.py")
SPEC = importlib.util.spec_from_file_location("last_message", SCRIPT)
last_message = importlib.util.module_from_spec(SPEC)
assert SPEC.loader
SPEC.loader.exec_module(last_message)


class LastMessageTest(unittest.TestCase):
    def write_jsonl(self, entries: list[dict]) -> Path:
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        path = Path(directory.name) / "session.jsonl"
        path.write_text("\n".join(json.dumps(entry) for entry in entries))
        return path

    def test_pi_follows_active_branch_past_current_user(self):
        path = self.write_jsonl(
            [
                {
                    "id": "user-1",
                    "parentId": None,
                    "message": {"role": "user", "content": "question"},
                },
                {
                    "id": "answer",
                    "parentId": "user-1",
                    "message": {
                        "role": "assistant",
                        "content": [{"type": "text", "text": "Pi answer"}],
                    },
                },
                {
                    "id": "unused-branch",
                    "parentId": "user-1",
                    "message": {
                        "role": "assistant",
                        "content": [{"type": "text", "text": "Wrong branch"}],
                    },
                },
                {
                    "id": "user-2",
                    "parentId": "answer",
                    "message": {"role": "user", "content": "run skill"},
                },
                {
                    "id": "tool-call",
                    "parentId": "user-2",
                    "message": {
                        "role": "assistant",
                        "content": [{"type": "toolCall", "name": "bash"}],
                    },
                },
            ]
        )

        self.assertEqual(last_message.pi_message(path), "Pi answer")

    def test_claude_combines_streamed_text_and_ignores_tool_results(self):
        path = self.write_jsonl(
            [
                {
                    "type": "user",
                    "uuid": "user-1",
                    "parentUuid": None,
                    "message": {"role": "user", "content": "question"},
                },
                {
                    "type": "assistant",
                    "uuid": "answer-1",
                    "parentUuid": "user-1",
                    "message": {
                        "id": "message-1",
                        "role": "assistant",
                        "content": [{"type": "text", "text": "First part."}],
                    },
                },
                {
                    "type": "assistant",
                    "uuid": "answer-2",
                    "parentUuid": "answer-1",
                    "message": {
                        "id": "message-1",
                        "role": "assistant",
                        "content": [{"type": "text", "text": "Second part."}],
                    },
                },
                {
                    "type": "user",
                    "uuid": "user-2",
                    "parentUuid": "answer-2",
                    "message": {"role": "user", "content": "run skill"},
                },
                {
                    "type": "assistant",
                    "uuid": "tool-call",
                    "parentUuid": "user-2",
                    "message": {
                        "id": "message-2",
                        "role": "assistant",
                        "content": [{"type": "tool_use", "name": "Bash"}],
                    },
                },
                {
                    "type": "user",
                    "uuid": "tool-result",
                    "parentUuid": "tool-call",
                    "message": {
                        "role": "user",
                        "content": [{"type": "tool_result", "content": "done"}],
                    },
                },
            ]
        )

        self.assertEqual(
            last_message.claude_message(path), "First part.\n\nSecond part."
        )

    def test_codex_skips_current_turn_function_calls(self):
        path = self.write_jsonl(
            [
                {
                    "type": "response_item",
                    "payload": {
                        "type": "message",
                        "id": "user-1",
                        "role": "user",
                        "content": [{"type": "input_text", "text": "question"}],
                    },
                },
                {
                    "type": "response_item",
                    "payload": {
                        "type": "message",
                        "id": "answer",
                        "role": "assistant",
                        "content": [
                            {"type": "output_text", "text": "Codex answer"}
                        ],
                    },
                },
                {
                    "type": "response_item",
                    "payload": {
                        "type": "message",
                        "id": "user-2",
                        "role": "user",
                        "content": [{"type": "input_text", "text": "run skill"}],
                    },
                },
                {
                    "type": "response_item",
                    "payload": {"type": "function_call", "name": "exec_command"},
                },
            ]
        )

        self.assertEqual(last_message.codex_message(path), "Codex answer")


if __name__ == "__main__":
    unittest.main()
