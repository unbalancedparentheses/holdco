{
  description = "Holdco - Elixir/Phoenix holding company management";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };

        # Use the latest Erlang/OTP 27 and Elixir 1.18 from nixpkgs
        erlang = pkgs.beam.packages.erlang_27;
        elixir = erlang.elixir_1_18;

        # Common build inputs shared between devShell and package build
        buildDeps = [
          elixir
          erlang.erlang
          pkgs.sqlite
          pkgs.nodejs
        ];

        # Mix release built via Nix
        holdco = pkgs.stdenv.mkDerivation {
          pname = "holdco";
          version = "0.1.0";
          src = ./.;

          nativeBuildInputs = buildDeps ++ [ pkgs.makeWrapper ];
          buildInputs = [ pkgs.sqlite ];

          # Hex and Rebar need a writable home
          HOME = "/tmp/holdco-build";
          MIX_ENV = "prod";
          MIX_REBAR3 = "${erlang.rebar3}/bin/rebar3";

          configurePhase = ''
            export MIX_HOME=$TMPDIR/mix
            export HEX_HOME=$TMPDIR/hex
            mix local.hex --force
            mix local.rebar --force
          '';

          buildPhase = ''
            mix deps.get --only prod
            mix deps.compile
            mix assets.deploy
            mix compile
            mix release
          '';

          installPhase = ''
            mkdir -p $out
            cp -r _build/prod/rel/holdco/* $out/
            wrapProgram $out/bin/holdco \
              --prefix PATH : ${pkgs.lib.makeBinPath [ pkgs.sqlite ]}
          '';
        };

        # Docker image via dockerTools
        dockerImage = pkgs.dockerTools.buildLayeredImage {
          name = "holdco";
          tag = "latest";
          contents = [
            holdco
            pkgs.sqlite
            pkgs.busybox
            pkgs.cacert
          ];
          config = {
            Cmd = [ "${holdco}/bin/holdco" "start" ];
            Env = [
              "DATABASE_PATH=/data/holdco.db"
              "PHX_SERVER=true"
              "LANG=en_US.UTF-8"
            ];
            ExposedPorts = { "4000/tcp" = {}; };
            Volumes = { "/data" = {}; };
          };
        };
      in
      {
        packages = {
          default = holdco;
          docker = dockerImage;
        };

        devShells.default = pkgs.mkShell {
          buildInputs = buildDeps ++ pkgs.lib.optionals pkgs.stdenv.isLinux [
            pkgs.inotify-tools
          ];

          env = {
            MIX_ENV = "dev";
            ERL_AFLAGS = "-kernel shell_history enabled +pc unicode";
            LANG = "en_US.UTF-8";
            LC_ALL = "en_US.UTF-8";
          };

          shellHook = ''
            echo "Holdco dev shell"
            echo "  Elixir: $(elixir --version | tail -1)"
            echo "  Erlang: $(erl -eval 'io:format("~s", [erlang:system_info(otp_release)]), halt().' -noshell)"
            echo "  Node:   $(node --version)"
            echo "  SQLite: $(sqlite3 --version | cut -d' ' -f1)"
          '';
        };
      });
}
