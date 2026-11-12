from fastapi.testclient import TestClient

from tests.conftest import ClientFactory


def test_health(client: TestClient) -> None:
    response = client.get("/api/health")

    assert response.status_code == 200
    assert response.json() == {"status": "ok"}


def test_login_succeeds(client: TestClient) -> None:
    assert client.post("/api/login").status_code == 200


def test_login_fails_at_configured_rate(make_client: ClientFactory) -> None:
    client = make_client(login_failure_rate=1)

    assert client.post("/api/login").status_code == 401


def test_checkout_succeeds(client: TestClient) -> None:
    body = client.post("/api/checkout").json()

    assert body["status"] == "order_placed"
    assert body["order_id"]


def test_checkout_fails_at_configured_rate(make_client: ClientFactory) -> None:
    client = make_client(checkout_error_rate=1)
    response = client.post("/api/checkout")

    assert response.status_code == 500
    assert response.json() == {"detail": "Payment provider unavailable"}


def test_search_echoes_query(client: TestClient) -> None:
    body = client.get("/api/search", params={"q": "shoes"}).json()

    assert body["query"] == "shoes"
    assert len(body["results"]) == 3


def test_trigger_error_returns_500(client: TestClient) -> None:
    assert client.post("/api/error").status_code == 500


def test_responses_carry_request_id(client: TestClient) -> None:
    assert client.post("/api/login").headers["X-Request-ID"]


def test_unhandled_errors_return_json(client: TestClient) -> None:
    response = client.post("/api/error")

    assert response.json() == {"detail": "Internal Server Error"}
    assert response.headers["X-Request-ID"]
