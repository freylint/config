# Features:
# - Windows compatibility: Bottles GUI (managed Wine environments), Wine Staging (WoW64), Winetricks
# - GE-Proton runner linked into ~/.local/share/bottles/runners/ for all home-manager users
# - 32-bit graphics support (required for DirectX / 32-bit Windows apps)
{ pkgs, ... }: {
  environment.systemPackages = with pkgs; [
    bottles
    wineWow64Packages.staging
    winetricks
  ];
  hardware.graphics.enable32Bit = true;
  home-manager.sharedModules = [
    { xdg.dataFile."bottles/runners/GE-Proton".source = pkgs.proton-ge-bin.steamcompattool; }
  ];
}
