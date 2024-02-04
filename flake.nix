{
  description = "protohackers devshell";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";
    pre-commit-hooks.url = "github:cachix/pre-commit-hooks.nix";
  };

  outputs = {
    self,
    nixpkgs,
    pre-commit-hooks,
    ...
  }: let
    supportedSystems = [
      "aarch64-darwin"
      "aarch64-linux"
      "x86_64-darwin"
      "x86_64-linux"
    ];
    forEachSupportedSystem = f:
      nixpkgs.lib.genAttrs supportedSystems (system:
        f {
          inherit system;
          pkgs = import nixpkgs {
            inherit system;
            config.allowAliases = false;
          };
        });
  in {
    checks = forEachSupportedSystem ({
      pkgs,
      system,
    }: {
      pre-commit-check = pre-commit-hooks.lib.${system}.run {
        src = ./.;
        hooks = {
          alejandra.enable = true;
          credo.enable = true;
          deadnix.enable = true;
          dialyzer.enable = true;
          mix-format.enable = true;
          mix-test.enable = false;
          shellcheck.enable = true;
          statix.enable = true;
        };
        settings = {
          alejandra = {
            check = true;
          };
          deadnix = {
            noLambdaArg = true;
            noLambdaPatternNames = true;
          };
        };
      };
    });

    devShells = forEachSupportedSystem ({
      pkgs,
      system,
    }: {
      default = pkgs.mkShell {
        packages =
          builtins.attrValues
          {
            inherit
              (pkgs)
              alejandra
              deadnix
              erlang
              shellcheck
              sops
              ssh-to-age
              statix
              vulnix
              ;
          }
          ++ [
            pkgs.beam.packages.erlangR25.elixir_1_15
          ]
          # linux only
          ++ pkgs.lib.optionals pkgs.stdenv.isLinux [
            pkgs.inotify-tools
            pkgs.libnotify
          ]
          # darwin only
          ++ pkgs.lib.optionals pkgs.stdenv.isDarwin [pkgs.terminal-notifier]
          ++ pkgs.lib.optionals pkgs.stdenv.isDarwin [
            pkgs.darwin.apple_sdk.frameworks.CoreFoundation
            pkgs.darwin.apple_sdk.frameworks.CoreServices
          ];

        shellHook = ''
          export PATH="$PWD/bin:$PATH"
          ${self.checks.${system}.pre-commit-check.shellHook}
        '';
      };
    });

    packages = forEachSupportedSystem ({
      pkgs,
      system,
    }: let
      pname = "protohackers";
      version = "v0.1.0";
      elixir = pkgs.beam.packagesWith pkgs.beam.interpreters.erlangR25;
      src = builtins.path {
        path = ./.;
        name = "protohackers";
      };
    in {
      protohackers = elixir.mixRelease {
        inherit pname version src;

        mixFodDeps = elixir.fetchMixDeps {
          pname = "mix-deps-${pname}";
          inherit src version;
          hash = "sha256-pupw16g+mTtVnwG+EajltJH4guzNdQY8deCZEo739Eo=";
          mixEnv = "";
        };

        nativeBuildInputs = [];
      };
    });
  };
}
