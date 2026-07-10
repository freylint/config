# Features:
# - Dev tools: python3, neovim, git, gh, gnumake, gcc, rust (beta + rust-src + rust-analyzer), elm + elm-format, claude-code
# - Infra tools: awscli2, lightsailctl (bundled binary derivation), jq, nil LSP, sops, age, ssh-to-age
# - EDA / CAD tools: kicad, openscad, yosys
# - Desktop: wezterm, signal-desktop, discord
# - Games (wrapped per-host by flake overlay): heroic, vkquake, runelite, bolt-launcher
# - Desktop utilities: gnome-disk-utility, gparted
# - Hardware diagnostics: pciutils
{ pkgs, ... }:
let
  lightsailctl = pkgs.stdenvNoCC.mkDerivation {
    pname = "lightsailctl";
    version = "latest";
    src = pkgs.fetchurl {
      url = "https://lightsailctl.s3-us-west-2.amazonaws.com/latest/linux-amd64/lightsailctl";
      sha256 = "1vasazl643dmk4kqq22rg3i9nvg6g0pdnvg3lvay4cl8ijdnbdyh";
    };
    dontUnpack = true;
    installPhase = "install -Dm755 $src $out/bin/lightsailctl";
  };
in
{
  environment.systemPackages = with pkgs; [
    python3
    neovim
    git
    gh
    gnumake
    gcc
    (rust-bin.beta.latest.default.override {
      extensions = [
        "rust-src"
        "rust-analyzer"
      ];
    })
    elmPackages.elm
    elmPackages.elm-format
    claude-code
    awscli2
    lightsailctl
    jq
    nil
    sops
    age
    ssh-to-age
    kicad
    openscad
    yosys
    wezterm
    discord
    signal-desktop
    heroic
    vkquake
    runelite
    bolt-launcher
    gnome-disk-utility
    gparted
    pciutils
  ];
}
