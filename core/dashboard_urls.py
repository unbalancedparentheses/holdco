from django.urls import path

from core import views

urlpatterns = [
    path("", views.dashboard, name="dashboard"),
    path("company/<int:company_id>/", views.company_page, name="company_detail"),
]
