# Features:
# - udev + Steam Input: steam-hardware, xone, xpadneo, gamescope session,
#   game-devices-udev-rules, antimicrox/jstest-gtk/linuxConsoleTools/evtest
{ pkgs, ... }: {
  hardware = {
    steam-hardware.enable = true;
    xone.enable = true; # wired Xbox One / Series + dongle (out-of-tree kmod)
    xpadneo.enable = true; # Bluetooth Xbox controllers
  };
  programs.steam = {
    extest.enable = true; # exposes Steam Input as XInput for non-Steam apps
    gamescopeSession.enable = true; # dedicated compositor session for handheld-style play
  };
  services.udev.packages = [ pkgs.game-devices-udev-rules ];
  environment.systemPackages = with pkgs; [
    antimicrox
    jstest-gtk
    linuxConsoleTools
    evtest
  ];
}
