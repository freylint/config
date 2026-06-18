# Features:
# - NUR, rust-overlay, nix-vscode-extensions overlays; unfree allowed
{
  nur,
  rust-overlay,
  nix-vscode-extensions,
  ...
}:
{
  nixpkgs.overlays = [
    nur.overlays.default
    rust-overlay.overlays.default
    nix-vscode-extensions.overlays.default
  ];
  nixpkgs.config.allowUnfree = true;
}
