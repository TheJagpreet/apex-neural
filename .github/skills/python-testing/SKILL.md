---
name: python-testing
description: "Provides Python backend testing patterns, frameworks, and best practices. Use when writing or running tests for Python projects including Django, Flask, and FastAPI."
---

# Python Testing Skill

When testing Python backends, follow this structured approach to discover, write, and run tests.

## Framework Detection

Detect the test framework by checking these files in order:

| File / Indicator | Framework |
|------------------|-----------|
| `conftest.py` / `pytest.ini` / `pyproject.toml [tool.pytest]` / `setup.cfg [tool:pytest]` | pytest |
| `manage.py` + `settings.py` with `django.test` | Django test (usually with pytest-django) |
| `unittest` imports in test files | unittest (stdlib) |
| `nose2.cfg` / `"nose2"` in dependencies | nose2 |

Always check the project configuration first:
```bash
# Check for pytest configuration
cat pyproject.toml 2>/dev/null | grep -A 5 "\[tool.pytest"
cat setup.cfg 2>/dev/null | grep -A 5 "\[tool:pytest\]"
cat pytest.ini 2>/dev/null

# Check installed test dependencies
pip list 2>/dev/null | grep -iE "pytest|django|flask|fastapi|unittest|nose"

# Check for test scripts
cat pyproject.toml 2>/dev/null | grep -A 5 "\[tool.poetry.scripts\]"
```

## Framework-Specific Patterns

### pytest (recommended, most common)

**Test file naming:** `test_*.py`, `*_test.py`

**Structure:**
```python
import pytest
from myapp.services import UserService
from myapp.exceptions import ValidationError


class TestUserService:
    """Tests for UserService."""

    @pytest.fixture
    def service(self):
        """Create a fresh UserService for each test."""
        return UserService()

    @pytest.fixture
    def sample_user_data(self):
        """Standard test user data."""
        return {"name": "Alice", "email": "alice@example.com"}

    def test_create_user_with_valid_input(self, service, sample_user_data):
        """Should create a user when input is valid."""
        # Act
        user = service.create_user(sample_user_data)

        # Assert
        assert user.name == "Alice"
        assert user.email == "alice@example.com"
        assert user.id is not None

    def test_create_user_raises_on_invalid_email(self, service):
        """Should raise ValidationError for invalid email."""
        # Arrange
        data = {"name": "Alice", "email": "not-an-email"}

        # Act & Assert
        with pytest.raises(ValidationError, match="invalid email"):
            service.create_user(data)

    @pytest.mark.parametrize("email", [
        "",
        "no-at-sign",
        "@missing-local",
        "missing-domain@",
        "spaces in@email.com",
    ])
    def test_create_user_rejects_invalid_emails(self, service, email):
        """Should reject various invalid email formats."""
        with pytest.raises(ValidationError):
            service.create_user({"name": "Test", "email": email})
```

**Fixtures and Conftest:**
```python
# conftest.py -- shared fixtures across test files
import pytest
from myapp import create_app
from myapp.database import db as _db


@pytest.fixture(scope="session")
def app():
    """Create application for testing."""
    app = create_app(testing=True)
    return app


@pytest.fixture(scope="function")
def db(app):
    """Provide a clean database for each test."""
    with app.app_context():
        _db.create_all()
        yield _db
        _db.session.rollback()
        _db.drop_all()


@pytest.fixture
def client(app):
    """Provide a test client."""
    return app.test_client()
```

**Mocking:**
```python
from unittest.mock import patch, MagicMock, AsyncMock


def test_send_email_on_registration(service):
    """Should send welcome email after registration."""
    with patch("myapp.services.email_client.send") as mock_send:
        mock_send.return_value = True

        service.register_user({"name": "Alice", "email": "a@b.com"})

        mock_send.assert_called_once_with(
            to="a@b.com",
            subject="Welcome!",
        )


# Async mock
async def test_async_fetch(service):
    """Should fetch data asynchronously."""
    with patch("myapp.services.http_client.get", new_callable=AsyncMock) as mock_get:
        mock_get.return_value = {"data": "test"}

        result = await service.fetch_data("/api/users")

        assert result == {"data": "test"}
```

**Run commands:**
```bash
pytest -v                              # Verbose output
pytest -v -x                           # Stop on first failure
pytest --tb=short                      # Short tracebacks
pytest -k "test_create"                # Filter by name pattern
pytest tests/test_users.py             # Run specific file
pytest --cov=myapp --cov-report=term   # With coverage
pytest --cov=myapp --cov-report=html   # HTML coverage report
pytest -n auto                         # Parallel execution (pytest-xdist)
```

### Django Test Framework

**Test file naming:** `test_*.py` in each app's `tests/` directory or `tests.py`

**Structure:**
```python
from django.test import TestCase, Client
from django.urls import reverse
from myapp.models import User


class UserViewTests(TestCase):
    """Tests for user views."""

    @classmethod
    def setUpTestData(cls):
        """Set up data shared across all tests in this class."""
        cls.user = User.objects.create_user(
            username="testuser",
            email="test@example.com",
            password="testpass123",
        )

    def setUp(self):
        """Set up per-test state."""
        self.client = Client()

    def test_user_list_requires_auth(self):
        """GET /users/ should require authentication."""
        response = self.client.get(reverse("user-list"))
        self.assertEqual(response.status_code, 302)  # Redirect to login

    def test_user_list_authenticated(self):
        """GET /users/ should return 200 for authenticated users."""
        self.client.login(username="testuser", password="testpass123")
        response = self.client.get(reverse("user-list"))
        self.assertEqual(response.status_code, 200)
        self.assertContains(response, "testuser")

    def test_create_user_api(self):
        """POST /api/users/ should create a new user."""
        self.client.login(username="testuser", password="testpass123")
        response = self.client.post(
            reverse("user-create"),
            data={"username": "newuser", "email": "new@example.com"},
            content_type="application/json",
        )
        self.assertEqual(response.status_code, 201)
        self.assertTrue(User.objects.filter(username="newuser").exists())
```

**Run commands:**
```bash
python manage.py test                          # All tests
python manage.py test myapp                    # Single app
python manage.py test myapp.tests.TestUserView # Single class
pytest --ds=myproject.settings                 # With pytest-django
```

### Flask Testing

**Structure:**
```python
import pytest
from myapp import create_app


@pytest.fixture
def app():
    app = create_app({"TESTING": True, "DATABASE_URI": "sqlite:///:memory:"})
    yield app


@pytest.fixture
def client(app):
    return app.test_client()


@pytest.fixture
def runner(app):
    return app.test_cli_runner()


def test_health_check(client):
    """GET /health should return 200."""
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json == {"status": "ok"}


def test_create_item_requires_auth(client):
    """POST /api/items should require auth."""
    response = client.post("/api/items", json={"name": "test"})
    assert response.status_code == 401
```

### FastAPI Testing

**Structure:**
```python
import pytest
from httpx import AsyncClient, ASGITransport
from myapp.main import app


@pytest.fixture
async def client():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        yield ac


@pytest.mark.anyio
async def test_read_items(client):
    """GET /api/items should return a list."""
    response = await client.get("/api/items")
    assert response.status_code == 200
    assert isinstance(response.json(), list)


@pytest.mark.anyio
async def test_create_item(client):
    """POST /api/items should create and return item."""
    response = await client.post(
        "/api/items",
        json={"name": "Widget", "price": 9.99},
    )
    assert response.status_code == 201
    data = response.json()
    assert data["name"] == "Widget"
    assert data["price"] == 9.99
```

**Run commands:**
```bash
pytest -v --anyio-backend=asyncio      # Async tests with anyio
pytest -v -x --tb=short                # Standard pytest
```

## Common Patterns

### Parametrized Tests
```python
@pytest.mark.parametrize("input_val,expected", [
    (0, "zero"),
    (1, "one"),
    (-1, "negative"),
    (100, "positive"),
])
def test_classify_number(input_val, expected):
    assert classify(input_val) == expected
```

### Temporary Files and Directories
```python
def test_file_processing(tmp_path):
    """tmp_path is a pytest built-in fixture."""
    test_file = tmp_path / "data.csv"
    test_file.write_text("name,age\nAlice,30\n")

    result = process_csv(str(test_file))
    assert result == [{"name": "Alice", "age": "30"}]
```

### Environment Variables
```python
import os

def test_config_from_env(monkeypatch):
    """monkeypatch is a pytest built-in fixture."""
    monkeypatch.setenv("DATABASE_URL", "sqlite:///:memory:")
    monkeypatch.setenv("DEBUG", "false")

    config = load_config()
    assert config.database_url == "sqlite:///:memory:"
    assert config.debug is False
```

### Database Testing with Transactions
```python
@pytest.fixture
def db_session(engine):
    """Provide a transactional scope for each test."""
    connection = engine.connect()
    transaction = connection.begin()
    session = Session(bind=connection)

    yield session

    session.close()
    transaction.rollback()
    connection.close()
```

### Freezing Time
```python
from freezegun import freeze_time

@freeze_time("2026-01-15 12:00:00")
def test_report_generation():
    report = generate_daily_report()
    assert report.date.isoformat() == "2026-01-15"
```

## Coverage Configuration

```ini
# pyproject.toml
[tool.pytest.ini_options]
testpaths = ["tests"]
python_files = ["test_*.py"]
python_classes = ["Test*"]
python_functions = ["test_*"]
addopts = "-v --tb=short"

[tool.coverage.run]
source = ["myapp"]
omit = ["tests/*", "*/migrations/*"]

[tool.coverage.report]
fail_under = 80
show_missing = true
exclude_lines = [
    "pragma: no cover",
    "if TYPE_CHECKING:",
    "if __name__ == .__main__.:",
]
```

## Troubleshooting

| Issue | Solution |
|-------|----------|
| `ModuleNotFoundError` | Install package in editable mode: `pip install -e .` or set `PYTHONPATH` |
| `fixture not found` | Ensure `conftest.py` is in the correct directory (project root or test directory) |
| `async test not running` | Install `pytest-anyio` or `pytest-asyncio` and mark tests appropriately |
| Database state leaking | Use transaction rollback in fixtures, ensure proper teardown |
| Slow tests | Use `pytest-xdist` for parallel runs, minimize database fixtures |
| Import errors in Django | Set `DJANGO_SETTINGS_MODULE` environment variable or use `--ds` flag |
| `PermissionError` on temp files | Use `tmp_path` fixture instead of hardcoded paths |
