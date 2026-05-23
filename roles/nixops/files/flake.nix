{
  description = "NixOS configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-vscode-extensions = {
      url = "github:nix-community/nix-vscode-extensions";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    plasma-manager = {
      url = "github:nix-community/plasma-manager";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };
    nur = {
      url = "github:nix-community/NUR";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixos-vscode-server = {
      url = "github:nix-community/nixos-vscode-server";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    fireplace-wallpaper = {
      url = "path:./pkg/fireplace-wallpaper";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    users = {
      url = "path:./pkg/users";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.nix-vscode-extensions.follows = "nix-vscode-extensions";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      home-manager,
      plasma-manager,
      nur,
      rust-overlay,
      nixos-vscode-server,
      fireplace-wallpaper,
      users,
    }:
    let
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
      commonConfig =
        { config, pkgs, ... }:
        {
          nixpkgs.system = "x86_64-linux";
          nixpkgs.overlays = [
            nur.overlays.default
            rust-overlay.overlays.default
          ];
          nixpkgs.config.allowUnfree = true;

          boot.loader.systemd-boot.enable = true;
          boot.loader.efi.canTouchEfiVariables = true;
          boot.kernelPackages = pkgs.linuxPackages_latest;

          networking.domain = "freyground.com";
          networking.networkmanager.enable = true;

          time.timeZone = "America/New_York";

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

          services.xserver.enable = true;

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

          services.xserver.xkb = {
            layout = "us";
            variant = "";
          };

          services.xserver.excludePackages = [ pkgs.xterm ];
          environment.plasma6.excludePackages = with pkgs.kdePackages; [
            konsole
            elisa
            oxygen
            khelpcenter
            krdp
          ];

          services.openssh.enable = true;

          hardware.bluetooth.enable = true;
          services.blueman.enable = true;

          services.printing.enable = true;

          services.pulseaudio.enable = false;
          security.rtkit.enable = true;
          services.pipewire = {
            enable = true;
            alsa.enable = true;
            alsa.support32Bit = true;
            pulse.enable = true;
          };

          programs.steam.enable = true;
          programs.alvr.enable = true;
          programs.zsh.enable = true;

          programs.ssh.askPassword = "${pkgs.kdePackages.ksshaskpass}/bin/ksshaskpass";

          environment.sessionVariables = {
            SSH_ASKPASS_REQUIRE = "prefer";
            SUDO_ASKPASS = "${pkgs.kdePackages.ksshaskpass}/bin/ksshaskpass";
          };

          fonts.packages = with pkgs; [
            nerd-fonts.fira-code
          ];

          environment.systemPackages = with pkgs; [
            ansible
            neovim
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
            vkquake
            (rust-bin.beta.latest.default.override {
              extensions = [
                "rust-src"
                "rust-analyzer"
              ];
            })
          ];

          home-manager = {
            useGlobalPkgs = true;
            useUserPackages = true;
            backupFileExtension = "backup";
            backupCommand = "mv -f \"$1\" \"$1.backup\"";
            sharedModules = [
              plasma-manager.homeModules.plasma-manager
              nixos-vscode-server.homeModules.default
            ];
          };

          nix.settings.experimental-features = [
            "nix-command"
            "flakes"
          ];

          system.stateVersion = "25.11";
        };

    in
    {
      packages.x86_64-linux.colmena = pkgs.colmena;

      colmena = {
        meta = {
          nixpkgs = import nixpkgs { system = "x86_64-linux"; };
        };

        defaults =
          { ... }:
          {
            deployment.buildOnTarget = true;
          };

        glw =
          { config, pkgs, ... }:
          {
            deployment = {
              allowLocalDeployment = true;
              targetHost = null;
            };
            imports = [
              ./pkg/hwconfig/glw.nix
              home-manager.nixosModules.home-manager
              commonConfig
              users.nixosModules.default
            ];
            networking.hostName = "glw";
            environment.systemPackages = [ pkgs.moonlight-qt ];
          };

        homebase =
          { config, pkgs, ... }:
          {
            deployment = {
              allowLocalDeployment = true;
              targetHost = null;
            };
            imports = [
              ./pkg/hwconfig/homebase.nix
              home-manager.nixosModules.home-manager
              commonConfig
              users.nixosModules.default
              fireplace-wallpaper.nixosModules.default
            ];
            networking.hostName = "homebase";
            services.fwupd.enable = false;
            services.sunshine = {
              enable = true;
              autoStart = true;
              capSysAdmin = true;
              openFirewall = true;
            };
            systemd.sleep.settings.Sleep = {
              AllowSuspend = false;
              AllowHibernation = false;
            };

            home-manager.users.gen =
              { ... }:
              {
                programs.plasma.kscreenlocker = {
                  autoLock = true;
                  lockOnResume = false;
                  appearance.alwaysShowClock = false;
                };

                programs.plasma.configFile."kscreenlockerrc" = {
                  "Greeter"."WallpaperPlugin" = "io.lmpriestley.fireplace";
                  "Daemon"."Timeout" = "10";
                  # Large grace period so screensaver dismisses without password
                  "Daemon"."LockGrace" = "999999";
                };

                programs.plasma.powerdevil.AC.turnOffDisplay = {
                  idleTimeout = 600000;
                  idleTimeoutWhenLocked = 600000;
                };
              };
          };
      };

      formatter.x86_64-linux = pkgs.nixfmt-tree;
    };
}
