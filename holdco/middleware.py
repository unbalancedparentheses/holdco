from django.http import HttpResponseForbidden

from core.models import get_user_role


class AdminRoleMiddleware:
    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        if request.path.startswith("/admin/"):
            if not request.user.is_authenticated:
                from django.shortcuts import redirect
                from django.conf import settings

                return redirect(settings.LOGIN_URL)
            if get_user_role(request.user) != "admin":
                return HttpResponseForbidden("Admin role required.")
        return self.get_response(request)
