# Collects self-tests from all modules — each module provides a *.test.nix companion
{ pkgs, nixpkgs, system }:
let args = { inherit pkgs nixpkgs system; };
in
  import ../wincompat.test.nix     args
  // import ../xfce_desktop.test.nix  args
