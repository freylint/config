{
  description = "NixOS configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager }:
  let
    hostname = "glw.freyground.com";
    pkgs = nixpkgs.legacyPackages.x86_64-linux;
  in {
    packages.x86_64-linux.colmena = pkgs.colmena;

    colmena = {
      meta = {
        nixpkgs = import nixpkgs { system = "x86_64-linux"; };
      };

      "${hostname}" = { config, pkgs, ... }: {
        deployment = {
          allowLocalDeployment = true;
          targetHost = null;
        };

        imports = [
          (./hwconfig + "/${hostname}.nix")
          home-manager.nixosModules.home-manager
        ];

        nixpkgs.system = "x86_64-linux";

        # Bootloader.
        boot.loader.systemd-boot.enable = true;
        boot.loader.efi.canTouchEfiVariables = true;

        # Use latest kernel.
        boot.kernelPackages = pkgs.linuxPackages_latest;

        networking.hostName = "glw";
        networking.domain = "freyground.com";
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
        services.displayManager.sddm = {
          enable = true;
          wayland.enable = true;
          settings = {
            General.Numlock = "on";
            Theme.EnableAvatars = false;
          };
        };
        services.displayManager.defaultSession = "plasma";
        services.desktopManager.plasma6.enable = true;

        # Configure keymap in X11
        services.xserver.xkb = {
          layout = "us";
          variant = "";
        };

        services.xserver.excludePackages = [ pkgs.xterm ];
        environment.plasma6.excludePackages = with pkgs.kdePackages; [
          konsole
          elisa        # music player
          oxygen       # legacy theme, Plasma 6 uses Breeze
          khelpcenter  # offline help browser
          dragonplayer # video player
          krdp         # remote desktop server
        ];

        services.printing.enable = true;

        services.pulseaudio.enable = false;
        security.rtkit.enable = true;
        services.pipewire = {
          enable = true;
          alsa.enable = true;
          alsa.support32Bit = true;
          pulse.enable = true;
        };

        # Required for zsh to be a valid login shell.
        programs.zsh.enable = true;

        programs.ssh.askPassword = "${pkgs.kdePackages.ksshaskpass}/bin/ksshaskpass";

        environment.sessionVariables = {
          SSH_ASKPASS_REQUIRE = "prefer";
          SUDO_ASKPASS = "${pkgs.kdePackages.ksshaskpass}/bin/ksshaskpass";
        };

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
          colmena
        ];

        home-manager = {
          useGlobalPkgs = true;
          useUserPackages = true;
          users.gen = { pkgs, ... }: {
            home.stateVersion = "25.11";

            xdg.configFile."baloofilerc".text = ''
              [Basic Settings]
              Indexing-Enabled=false
            '';

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
