import json
import logging

from observability_lab.observability.logs import JsonFormatter, request_id_var


def test_json_formatter_includes_extras_and_request_id() -> None:
    record = logging.makeLogRecord(
        {"name": "test", "levelname": "INFO", "msg": "hello", "route": "/api/login"}
    )
    token = request_id_var.set("abc123")
    try:
        line = JsonFormatter().format(record)
    finally:
        request_id_var.reset(token)

    payload = json.loads(line)
    assert payload["message"] == "hello"
    assert payload["level"] == "info"
    assert payload["route"] == "/api/login"
    assert payload["request_id"] == "abc123"
