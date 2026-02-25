"""ASGI config for holdco project with Channels WebSocket support."""

import os

from django.core.asgi import get_asgi_application

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "holdco.settings")

django_asgi_app = get_asgi_application()

# Only set up channels routing if WebSocket is enabled
if os.environ.get("HOLDCO_WEBSOCKET", "0") == "1":
    from channels.routing import ProtocolTypeRouter, URLRouter
    from channels.auth import AuthMiddlewareStack
    from core.routing import websocket_urlpatterns

    application = ProtocolTypeRouter({
        "http": django_asgi_app,
        "websocket": AuthMiddlewareStack(
            URLRouter(websocket_urlpatterns)
        ),
    })
else:
    application = django_asgi_app
