# Tests module: shared BDD utilities imported by each module's *.test.nix
# - eval: evaluate a NixOS module list against the flake's nixpkgs/system (no VM)
# - scenario: failing derivation if a Nix boolean assertion doesn't hold at eval time
# - vmBase: NixOS module suppressing GPU options that are invalid in QEMU
{ pkgs, nixpkgs, system }:
{
  eval = modules: (nixpkgs.lib.nixosSystem {
    modules = [
      { nixpkgs.hostPlatform = system; system.stateVersion = "26.05"; }
    ] ++ modules;
  }).config;

  scenario = name: cond: pkgs.runCommand name {}
    (if cond then "touch $out" else ''echo "FAIL: ${name}" >&2; exit 1'');

  vmBase = { lib, ... }: { hardware.graphics.enable32Bit = lib.mkForce false; };
}
