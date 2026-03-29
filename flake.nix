{
  description = "zeroclaw - agentic LLM gateway";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    fenix = {
      url = "github:nix-community/fenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, flake-utils, fenix, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ fenix.overlays.default ];
        };

        rustToolchain = pkgs.fenix.stable.withComponents [
          "cargo"
          "clippy"
          "rust-src"
          "rustc"
          "rustfmt"
        ];

        # Build the actual zeroclaw binary
        zeroclaw = pkgs.rustPlatform.buildRustPackage {
          pname = "zeroclaw";
          version = "0.1.0"; # update to match Cargo.toml

          src = pkgs.fetchFromGitHub {
            owner = "zeroclaw-labs";
            repo = "zeroclaw";
            rev = "master";
            # Run `nix-prefetch-url --unpack https://github.com/zeroclaw-labs/zeroclaw/archive/master.tar.gz`
            # to get the correct hash, then replace the placeholder below.
            hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
          };

          cargoHash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";

          # Add any native build dependencies here if the crate needs them
          # (e.g. openssl, pkg-config, etc.)
          nativeBuildInputs = with pkgs; [
            pkg-config
          ];

          buildInputs = with pkgs; [
            openssl
          ] ++ pkgs.lib.optionals pkgs.stdenv.isDarwin [
            pkgs.darwin.apple_sdk.frameworks.Security
            pkgs.darwin.apple_sdk.frameworks.SystemConfiguration
          ];

          meta = with pkgs.lib; {
            description = "Agentic LLM gateway";
            homepage = "https://github.com/zeroclaw-labs/zeroclaw";
            license = licenses.mit; # adjust if different
            maintainers = [];
            mainProgram = "zeroclaw";
          };
        };
      in {
        # `nix build` / `nix run`
        packages.default = zeroclaw;
        packages.zeroclaw = zeroclaw;

        # `nix develop` — for hacking on zeroclaw itself
        devShells.default = pkgs.mkShell {
          packages = [
            rustToolchain
            pkgs.rust-analyzer
            pkgs.pkg-config
            pkgs.openssl
          ];
        };
      }
    ) // {
      # NixOS module — add to your configuration.nix imports
      nixosModules.default = { pkgs, lib, config, ... }: {
        options.programs.zeroclaw = {
          enable = lib.mkEnableOption "zeroclaw agentic LLM gateway";
        };

        config = lib.mkIf config.programs.zeroclaw.enable {
          environment.systemPackages = [
            self.packages.${pkgs.stdenv.hostPlatform.system}.zeroclaw
          ];
        };
      };
    };
}
