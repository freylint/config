# Features:
# - Intiface Central: Bluetooth LE / USB peripheral device server
{ pkgs, ... }: {
  environment.systemPackages = [ pkgs.intiface-central ];
}
