FROM python:3.12-slim

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends gcc && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

RUN python manage.py collectstatic --noinput 2>/dev/null || true

EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=5s --retries=3 CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/api/stats')" || exit 1

CMD ["gunicorn", "holdco.wsgi:application", "--bind", "0.0.0.0:8000", "--workers", "2"]
