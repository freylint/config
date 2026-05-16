{
  description = "NixOS configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixops.url = "github:NixOS/nixops";
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, nixops, disko }: {
    nixopsConfigurations.default = {
      inherit nixpkgs;
      network.description = "nixos deployment";

      nixos = { config, pkgs, ... }: {
        imports = [
          ./hwconfig/${builtins.substring 0 8 (builtins.readFile "/etc/machine-id")}.nix
          ./mod/exclusions.nix
          ./mod/printing.nix
          ./mod/sound.nix
          ./mod/disko.nix
          home-manager.nixosModules.home-manager
          disko.nixosModules.disko
        ];

        nixpkgs.system = "x86_64-linux";

        # Bootloader.
        boot.loader.systemd-boot.enable = true;
        boot.loader.efi.canTouchEfiVariables = true;

        boot.supportedFilesystems = [ "zfs" ];
        boot.zfs.forceImportRoot = false;

        # Use latest kernel.
        boot.kernelPackages = pkgs.linuxPackages_latest;

        networking.hostName = "nixos";
        networking.hostId = builtins.substring 0 8 (builtins.readFile "/etc/machine-id");
        networking.networkmanager.enable = true;

        # Set your time zone.
        time.timeZone = "America/New_York";

        # Select internationalisation properties.
        i18n.defaultLocale = "en_US.UTF-8";
        i18n.extraLocaleSettings = {
          LC_ADDRESS = "en_US.UTF-8";
          LC_IDENTIFICATION = "en_US.UTF-8";
          LC_MEASUREMENT = "en_US.UTF-8";
          LC_MONETARY = "en_US.UTF-8";
          LC_NAME = "en_US.UTF-8";
          LC_NUMERIC = "en_US.UTF-8";
          LC_PAPER = "en_US.UTF-8";
          LC_TELEPHONE = "en_US.UTF-8";
          LC_TIME = "en_US.UTF-8";
        };

        # Enable the X11 windowing system.
        services.xserver.enable = true;

        # Enable the KDE Plasma Desktop Environment.
        services.displayManager.sddm.enable = true;
        services.desktopManager.plasma6.enable = true;

        # Configure keymap in X11
        services.xserver.xkb = {
          layout = "us";
          variant = "";
        };

        # Required for zsh to be a valid login shell.
        programs.zsh.enable = true;

        # Define a user account.
        users.users.gen = {
          isNormalUser = true;
          description = "gen";
          extraGroups = [ "networkmanager" "wheel" ];
          shell = pkgs.zsh;
          packages = with pkgs; [
            kdePackages.kate
          ];
        };

        # Allow unfree packages
        nixpkgs.config.allowUnfree = true;

        fonts.packages = with pkgs; [
          nerd-fonts.fira-code
        ];

        environment.systemPackages = with pkgs; [
          neovim
          claude-code
          git
          gh
          gnumake
          firefox
          wezterm
          nixops
        ];

        home-manager = {
          useGlobalPkgs = true;
          useUserPackages = true;
          users.gen = { pkgs, ... }: {
            home.stateVersion = "25.11";

            programs.wezterm = {
              enable = true;
              extraConfig = ''
                local wezterm = require("wezterm")
                return {
                  font = wezterm.font("FiraCode Nerd Font", { weight = "Regular" }),
                  font_size = 12.0,
                  harfbuzz_features = { "calt=1", "clig=1", "liga=1" },
                }
              '';
            };

            programs.zsh = {
              enable = true;
              syntaxHighlighting.enable = true;
              autosuggestion.enable = true;
              oh-my-zsh = {
                enable = true;
                theme = "robbyrussell";
                plugins = [ "git" ];
              };
            };
          };
        };

        nix.settings.experimental-features = [ "nix-command" "flakes" ];

        system.stateVersion = "25.11";
      };
    };
  };
}
