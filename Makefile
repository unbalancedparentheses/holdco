.PHONY: test seed migrate run clean createsuperuser

test:
	pytest core/tests/ -v

seed:
	python manage.py seed

migrate:
	python manage.py makemigrations core
	python manage.py migrate

run:
	python manage.py runserver

createsuperuser:
	python manage.py createsuperuser

clean:
	rm -f holdco.db
	find . -type d -name __pycache__ -exec rm -rf {} +
