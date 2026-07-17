# Features:
# - udev + Steam Input: steam-hardware, xone, xpadneo, gamescope session,
#   game-devices-udev-rules, antimicrox/jstest-gtk/linuxConsoleTools/evtest
# - pedalctl: Ikkegol foot pedal configurator (custom derivation + udev rule)
{ pkgs, ... }:
let
  pedalctl = pkgs.stdenv.mkDerivation {
    pname = "pedalctl";
    version = "unstable-2022-03-09";
    src = pkgs.fetchFromGitHub {
      owner = "Schmoller";
      repo = "pedalctl";
      rev = "502d0600e21f48d23dabc696a67ca82c343b0128";
      hash = "sha256-9fN1zwm/IE7L0yyyTQh8pTYWGcMk5FB9qbwZEqR3rUw=";
    };
    postPatch = ''
      for f in src/devices/ikkegol_protocol.hpp src/devices/ikkegol_capabilities.hpp src/utils/usb_scancodes.hpp; do
        substituteInPlace $f --replace-fail "#pragma once" $'#pragma once\n#include <cstdint>'
      done
    '';
    nativeBuildInputs = [ pkgs.cmake ];
    buildInputs = [ pkgs.libusb1 ];
    cmakeFlags = [ "-DINSTALL_UDEV_RULES=OFF" "-DCMAKE_POLICY_VERSION_MINIMUM=3.5" ];
  };
in
{
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
  services.udev.extraRules = ''SUBSYSTEMS=="usb", ATTRS{idVendor}=="1a86", ATTRS{idProduct}=="e026", ACTION=="add", MODE="0666", GROUP="usb"'';
  environment.systemPackages = with pkgs; [
    antimicrox
    jstest-gtk
    linuxConsoleTools
    evtest
    pedalctl
  ];
}
