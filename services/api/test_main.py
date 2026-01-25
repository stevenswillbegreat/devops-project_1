from fastapi.testclient import TestClient
from main import app

client = TestClient(app)

def test_read_main():
    # This expects 404 because "/" isn't defined, but proves the app loads
    response = client.get("/")
    assert response.status_code == 404