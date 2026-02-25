from django.contrib.auth import get_user_model
from django.core.management.base import BaseCommand, CommandError

from core.models import UserRole

VALID_ROLES = {r[0] for r in UserRole.ROLE_CHOICES}


class Command(BaseCommand):
    help = "Set the role for a user: python manage.py set_role <username> <role>"

    def add_arguments(self, parser):
        parser.add_argument("username", type=str)
        parser.add_argument("role", type=str, choices=sorted(VALID_ROLES))

    def handle(self, *args, **options):
        username = options["username"]
        role = options["role"]

        User = get_user_model()
        try:
            user = User.objects.get(username=username)
        except User.DoesNotExist:
            raise CommandError(f"User '{username}' does not exist.")

        obj, created = UserRole.objects.update_or_create(
            user=user, defaults={"role": role}
        )
        action = "Created" if created else "Updated"
        self.stdout.write(self.style.SUCCESS(f"{action} role for {username}: {role}"))
