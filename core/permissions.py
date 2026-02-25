from rest_framework.permissions import BasePermission

from core.models import get_user_role


class RolePermission(BasePermission):
    def has_permission(self, request, view):
        if request.method in ("GET", "HEAD", "OPTIONS"):
            return True
        role = get_user_role(request.user)
        if request.method == "DELETE":
            return role == "admin"
        # POST, PUT, PATCH
        return role in ("editor", "admin")
