{ pkgs, ... }:

{
  services.xserver.excludePackages = [ pkgs.xterm ];
  environment.plasma6.excludePackages = with pkgs.kdePackages; [ konsole ];
}
