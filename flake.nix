{
  description = "Holdco — open source holding company management";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        python = pkgs.python312;
        pythonPkgs = python.pkgs;

        pythonEnv = python.withPackages (ps: with ps; [
          django_5
          djangorestframework
          pydantic
          yfinance
          pytest
          pytest-django
        ]);
      in
      {
        devShells.default = pkgs.mkShell {
          buildInputs = [ pythonEnv ];
          shellHook = ''
            echo "Holdco dev shell — Python ${python.version}"
            echo "  python manage.py runserver    # web + API + admin"
            echo "  python manage.py seed         # seed demo data"
            echo "  pytest core/tests/ -v         # run tests"
          '';
        };

        packages.default = pkgs.writeShellScriptBin "holdco" ''
          export PATH="${pythonEnv}/bin:$PATH"
          exec ${pythonEnv}/bin/python ${./manage.py} runserver 0.0.0.0:8000 "$@"
        '';
      }
    );
}
