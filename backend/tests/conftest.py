import os
# Override DB to sqlite memory for tests to avoid needing Postgres
os.environ["DATABASE_URL"] = "sqlite:///:memory:"
os.environ["JWT_SECRET"] = "test-secret-for-ci-at-least-32-chars-long-123"
