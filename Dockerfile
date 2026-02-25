FROM python:3.12-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

RUN mkdir -p /app/data
RUN python manage.py collectstatic --noinput 2>/dev/null || true

ENV HOLDCO_DB=/app/data/holdco.db

EXPOSE 8000

CMD ["python", "manage.py", "runserver", "0.0.0.0:8000"]
