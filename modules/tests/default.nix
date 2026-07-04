# Collects self-tests from all modules — each module provides a *.test.nix companion
{ pkgs, nixpkgs, system, home-manager, nix-vscode-extensions }:
let args = { inherit pkgs nixpkgs system home-manager nix-vscode-extensions; };
in
  import ../wincompat.test.nix       args
  // import ../xfce_desktop.test.nix  args
  // import ../home/vscode.test.nix   args
