{ nur, rust-overlay, nix-vscode-extensions, ... }:
{
  nixpkgs.overlays = [
    nur.overlays.default
    rust-overlay.overlays.default
    nix-vscode-extensions.overlays.default
  ];
  nixpkgs.config.allowUnfree = true;
}
