NIX_SHELL = nix develop --command

.PHONY: setup dev test lint release docker-build docker-up docker-down seed reset precommit

setup:
	$(NIX_SHELL) mix setup

dev:
	$(NIX_SHELL) mix phx.server

test:
	$(NIX_SHELL) mix test

lint:
	$(NIX_SHELL) mix format --check-formatted
	$(NIX_SHELL) mix compile --warnings-as-errors

release:
	$(NIX_SHELL) sh -c "MIX_ENV=prod mix assets.deploy && MIX_ENV=prod mix release"

docker-build:
	docker build -t holdco .

docker-up:
	docker compose up -d

docker-down:
	docker compose down

seed:
	$(NIX_SHELL) mix run priv/repo/seeds.exs

reset:
	$(NIX_SHELL) mix ecto.reset

precommit:
	$(NIX_SHELL) mix precommit
