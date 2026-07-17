# Features:
# - Windows compatibility: Bottles GUI (managed Wine environments), Wine Staging (WoW64), Winetricks
# - 32-bit graphics support (required for DirectX / 32-bit Windows apps)
{ pkgs, ... }: {
  environment.systemPackages = with pkgs; [
    bottles
    wineWow64Packages.staging
    winetricks
  ];
  hardware.graphics.enable32Bit = true;
}
