# Features:
# - Rust embedded firmware package (thumbv7em-none-eabihf / ARM Cortex-M)
# - Dev shell with Rust beta toolchain and probe-rs debugger
{
  description = "collar";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      rust-overlay,
    }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        overlays = [ rust-overlay.overlays.default ];
      };
      rustToolchain = pkgs.rust-bin.beta.latest.default.override {
        extensions = [
          "rust-src"
          "rust-analyzer"
        ];
        targets = [ "thumbv7em-none-eabihf" ];
      };
      rustPlatform = pkgs.makeRustPlatform {
        cargo = rustToolchain;
        rustc = rustToolchain;
      };
    in
    {
      packages.${system}.default = rustPlatform.buildRustPackage {
        pname = "collar";
        version = "0.1.0";
        src = ./.;
        cargoLock.lockFile = ./Cargo.lock;

        CARGO_BUILD_TARGET = "thumbv7em-none-eabihf";

        buildPhase = "cargo build --release";
        installPhase = ''
          mkdir -p $out
          cp target/thumbv7em-none-eabihf/release/collar $out/collar.elf
        '';

        doCheck = false;
      };

      devShells.${system}.default = pkgs.mkShell {
        buildInputs = with pkgs; [
          rustToolchain
          gcc
          probe-rs-tools
        ];
      };
    };
}
