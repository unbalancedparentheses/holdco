{
  description = "Holdco — holding company management";

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
      in {
        devShells.default = pkgs.mkShell {
          packages = [
            python
            pythonPkgs.pip
            pythonPkgs.django
            pythonPkgs.djangorestframework
            pythonPkgs.pytest
            pythonPkgs.pytest-django
            pythonPkgs.hypothesis
          ];
          shellHook = ''
            echo "Holdco dev shell ready"
            export PYTHONPATH="$PWD:$PYTHONPATH"
          '';
        };
      });
}
