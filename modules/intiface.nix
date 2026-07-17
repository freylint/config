# Features:
# - Intiface Central: Buttplug.io device server (Bluetooth LE + USB toy control)
{ pkgs, ... }: {
  environment.systemPackages = [ pkgs.intiface-central ];
}
