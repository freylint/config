# Tests module: shared BDD utilities imported by each module's *.test.nix
# - eval: evaluate a NixOS module list against the flake's nixpkgs/system (no VM)
# - evalHome: evaluate a home-manager module list (programs.*, home.*)
# - homePkgs: pkgs with allowUnfree + nix-vscode-extensions overlay (use for evalHome assertions)
# - scenario: failing derivation if a Nix boolean assertion doesn't hold at eval time
# - vmBase: NixOS module suppressing GPU options that are invalid in QEMU
{
  pkgs,
  nixpkgs,
  system,
  home-manager,
  nix-vscode-extensions,
}:
let
  homePkgs = import nixpkgs {
    inherit system;
    config.allowUnfree = true;
    overlays = [ nix-vscode-extensions.overlays.default ];
  };
in
{
  eval =
    modules:
    (nixpkgs.lib.nixosSystem {
      modules = [
        {
          nixpkgs.hostPlatform = system;
          system.stateVersion = "26.05";
        }
      ]
      ++ modules;
    }).config;

  evalHome =
    modules:
    (home-manager.lib.homeManagerConfiguration {
      pkgs = homePkgs;
      modules = [
        {
          home = {
            username = "test";
            homeDirectory = "/home/test";
            stateVersion = "26.05";
          };
        }
      ]
      ++ modules;
    }).config;

  inherit homePkgs;

  scenario =
    name: cond:
    pkgs.runCommand name { } (if cond then "touch $out" else ''echo "FAIL: ${name}" >&2; exit 1'');

  vmBase = { lib, ... }: { hardware.graphics.enable32Bit = lib.mkForce false; };
}
