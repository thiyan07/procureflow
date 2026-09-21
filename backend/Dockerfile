FROM python:3.11-slim

WORKDIR /app

# System deps
RUN apt-get update && apt-get install -y --no-install-recommends gcc libpq-dev && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

# Run migrations and start
CMD ["sh", "-c", "python -m alembic upgrade head || python -c \"from app.db.session import engine; from app.db.base import Base; Base.metadata.create_all(bind=engine); print('create_all done')\"; uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8000}"]

EXPOSE 8000
