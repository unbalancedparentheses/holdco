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
          pydantic
          yfinance
          streamlit
          fastapi
          uvicorn
          pytest
          httpx
        ]);
      in
      {
        devShells.default = pkgs.mkShell {
          buildInputs = [ pythonEnv ];
          shellHook = ''
            echo "Holdco dev shell — Python ${python.version}"
            echo "  streamlit run app.py    # dashboard"
            echo "  uvicorn api:app         # API"
            echo "  python seed.py          # seed demo data"
          '';
        };

        packages.default = pkgs.writeShellScriptBin "holdco" ''
          export PATH="${pythonEnv}/bin:$PATH"
          exec ${pythonEnv}/bin/streamlit run ${./app.py} --server.address 0.0.0.0 "$@"
        '';
      }
    );
}
