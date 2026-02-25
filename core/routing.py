"""WebSocket URL routing for real-time updates."""

from django.urls import re_path

from core import consumers

websocket_urlpatterns = [
    re_path(r"ws/audit-log/$", consumers.AuditLogConsumer.as_asgi()),
    re_path(r"ws/portfolio/$", consumers.PortfolioConsumer.as_asgi()),
]
