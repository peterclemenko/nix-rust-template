{
  description = "nix-rust-template";

  nixConfig = {
    bash-prompt = "[nix]λ ";
    warn-dirty = false;
  };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    naersk = {
      url = "github:nmattia/naersk";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    flake-utils = {
      url = "github:numtide/flake-utils";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, flake-utils, naersk, nixpkgs, rust-overlay }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        overlays = [
          rust-overlay.overlays.default
          naersk.overlays.default
        ];
        pkgs = import nixpkgs {
          inherit system overlays;
        };
        rust = pkgs.rust-bin.stable.latest.default;
        naersk-lib = pkgs.naersk.override {
          cargo = pkgs.rust-bin.nightly.latest.cargo;
          rustc = rust;
        };
        rust-dev = rust.override {
          extensions = [
            "clippy"
            "rust-src"
            "rustc-dev"
            "rustfmt"
          ];
        };
        cargoToml = builtins.fromTOML (builtins.readFile ./Cargo.toml);
        packageName = cargoToml.package.name;
      in
      {
        # `nix build`
        packages.default = naersk-lib.buildPackage {
          pname = packageName;
          root = ./.;
        };

        packages.${packageName} = self.packages.${system}.default;

        # `nix run` or `nix run .#app`
        apps.default = flake-utils.lib.mkApp {
          drv = self.packages.${system}.default;
        };

        apps.app = self.apps.${system}.default;

        # `nix run .#watch`
        apps.watch = flake-utils.lib.mkApp {
          drv = pkgs.writeShellApplication {
            name = "watch";
            runtimeInputs = [
              pkgs.cargo-watch
              pkgs.gcc
              rust
            ];
            text = ''
              cargo-watch -w "./src/" -x "run"
            '';
          };
        };

        # `nix develop`
        devShells.default = pkgs.mkShell {
          name = packageName;
          buildInputs = [
            pkgs.cargo-edit
            pkgs.cargo-watch
            pkgs.rust-analyzer
            pkgs.pkg-config
            pkgs.clang
            pkgs.llvmPackages.bintools
          ];
          nativeBuildInputs = [ rust-dev ];

          LIBCLANG_PATH = pkgs.lib.makeLibraryPath [ pkgs.llvmPackages_latest.libclang.lib ];

          shellHook = ''
            echo "Welcome to $(cargo --version | cut -d' ' -f2)"
          '';
        };
      }
    );
}