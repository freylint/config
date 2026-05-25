{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    python3
    neovim
    sops
    age
    ssh-to-age
    claude-code
    git
    gh
    gnumake
    gcc
    kicad
    openscad
    yosys
    wezterm
    colmena
    catppuccin-kde
    catppuccin-papirus-folders
    discord
    heroic
    gnome-disk-utility
    gparted
    vkquake
    (rust-bin.beta.latest.default.override {
      extensions = [
        "rust-src"
        "rust-analyzer"
      ];
    })
  ];
}
