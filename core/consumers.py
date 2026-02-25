"""WebSocket consumers for real-time updates."""

import json

try:
    from channels.generic.websocket import AsyncWebsocketConsumer
except ImportError:
    # Channels not installed — provide stub so imports don't break
    class AsyncWebsocketConsumer:
        pass


class AuditLogConsumer(AsyncWebsocketConsumer):
    """Broadcasts new audit log entries to connected clients."""

    async def connect(self):
        self.group_name = "audit_log"
        await self.channel_layer.group_add(self.group_name, self.channel_name)
        await self.accept()

    async def disconnect(self, close_code):
        await self.channel_layer.group_discard(self.group_name, self.channel_name)

    async def audit_log_entry(self, event):
        await self.send(text_data=json.dumps(event["data"]))


class PortfolioConsumer(AsyncWebsocketConsumer):
    """Broadcasts portfolio NAV updates to connected clients."""

    async def connect(self):
        self.group_name = "portfolio"
        await self.channel_layer.group_add(self.group_name, self.channel_name)
        await self.accept()

    async def disconnect(self, close_code):
        await self.channel_layer.group_discard(self.group_name, self.channel_name)

    async def portfolio_update(self, event):
        await self.send(text_data=json.dumps(event["data"]))
