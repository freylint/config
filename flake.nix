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
  };

  outputs = { self, nixpkgs, home-manager, nix-vscode-extensions, plasma-manager, nur, rust-overlay, nixos-vscode-server }:
  let
    pkgs = nixpkgs.legacyPackages.x86_64-linux;
    vscodeExtensions = nix-vscode-extensions.extensions.x86_64-linux;
    commonConfig = { config, pkgs, ... }: {
      nixpkgs.system = "x86_64-linux";
      nixpkgs.overlays = [ nur.overlays.default rust-overlay.overlays.default ];
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

      users.users.gen = {
        isNormalUser = true;
        description = "gen";
        extraGroups = [ "networkmanager" "wheel" ];
        shell = pkgs.zsh;
        packages = with pkgs; [
          kdePackages.kate
        ];
      };

      fonts.packages = with pkgs; [
        nerd-fonts.fira-code
      ];

      environment.systemPackages = with pkgs; [
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
        gnome-disk-utility
        vkquake
        (rust-bin.beta.latest.default.override {
          extensions = [ "rust-src" "rust-analyzer" ];
        })
      ];

      home-manager = {
        useGlobalPkgs = true;
        useUserPackages = true;
        backupFileExtension = "backup";
        sharedModules = [ plasma-manager.homeModules.plasma-manager nixos-vscode-server.homeModules.default ];
        users.gen = { pkgs, ... }: {
          home.stateVersion = "25.11";
          services.vscode-server.enable = true;

          programs.firefox = {
            enable = true;
            profiles.gen = {
              search.default = "DuckDuckGo";
              settings = {
                "sidebar.verticalTabs" = true;
"browser.newtabpage.activity-stream.feeds.section.topstories" = false;
                "browser.newtabpage.activity-stream.showSponsored" = false;
              };
              extensions.packages = [
                pkgs.nur.repos.rycee.firefox-addons.ublock-origin
                (pkgs.nur.repos.rycee.firefox-addons.buildFirefoxXpiAddon {
                  pname = "dark-reader";
                  version = "4.9.125";
                  addonId = "addon@darkreader.org";
                  url = "https://addons.mozilla.org/firefox/downloads/file/4783321/darkreader-4.9.125.xpi";
                  sha256 = "0a5g7rkc0fgnp7fpwk37703yksbwh1csahgq22drpq3kr25s3a91";
                  meta = {};
                })
                (pkgs.nur.repos.rycee.firefox-addons.buildFirefoxXpiAddon {
                  pname = "sponsorblock";
                  version = "6.1.5";
                  addonId = "sponsorBlocker@ajay.app";
                  url = "https://addons.mozilla.org/firefox/downloads/file/4773757/sponsorblock-6.1.5.xpi";
                  sha256 = "051f3gypy72m4irhyk62fkw5bdwid14kdm46g8q8xdxhxjd25v6q";
                  meta = {};
                })
                (pkgs.nur.repos.rycee.firefox-addons.buildFirefoxXpiAddon {
                  pname = "bitwarden";
                  version = "2026.4.0";
                  addonId = "{446900e4-71c2-419f-a6a7-df9c091e268b}";
                  url = "https://addons.mozilla.org/firefox/downloads/file/4796063/bitwarden_password_manager-2026.4.0.xpi";
                  sha256 = "045ffhr158lnafwdpyijhwnzzjf42rgwzpwvzva5b1hwl71zdgfc";
                  meta = {};
                })
                (pkgs.nur.repos.rycee.firefox-addons.buildFirefoxXpiAddon {
                  pname = "catppuccin-mocha-mauve";
                  version = "old";
                  addonId = "{76aabc99-c1a8-4c1e-832b-d4f2941d5a7a}";
                  url = "https://github.com/catppuccin/firefox/releases/download/old/catppuccin_mocha_mauve.xpi";
                  sha256 = "1gkv12034d2dbbvr2fmxbqifmgmfv0lh58my1gmkcvfpxrap6ad5";
                  meta = {};
                })
              ];
            };
          };

          programs.plasma = {
            enable = true;
            workspace.colorScheme = "CatppuccinMochaMauve";
            workspace.iconTheme = "Catppuccin-Mocha-Mauve-Papirus-Dark";
            workspace.splashScreen.theme = "None";
            workspace.wallpaperPictureOfTheDay.provider = "apod";
          };

          xdg.configFile."baloofilerc".text = ''
            [Basic Settings]
            Indexing-Enabled=false
          '';

          programs.vscode = {
            enable = true;
            extensions = [
              vscodeExtensions.vscode-marketplace.anthropic.claude-code
              vscodeExtensions.vscode-marketplace.jnoortheen.nix-ide
              vscodeExtensions.vscode-marketplace.catppuccin.catppuccin-vsc
              vscodeExtensions.vscode-marketplace.mshr-h.veriloghdl
              vscodeExtensions.vscode-marketplace.antyos.openscad
            ];
            userSettings = {
              "editor.fontFamily" = "'FiraCode Nerd Font', monospace";
              "editor.fontLigatures" = true;
              "terminal.integrated.fontFamily" = "'FiraCode Nerd Font'";
              "workbench.colorTheme" = "Catppuccin Mocha";
              "extensions.ignoreRecommendations" = true;
            };
          };

          programs.wezterm = {
            enable = true;
            extraConfig = ''
              local wezterm = require("wezterm")
              return {
                font = wezterm.font("FiraCode Nerd Font", { weight = "Regular" }),
                font_size = 12.0,
                harfbuzz_features = { "calt=1", "clig=1", "liga=1" },
                color_scheme = "Catppuccin Mocha",
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

  in {
    packages.x86_64-linux.colmena = pkgs.colmena;

    colmena = {
      meta = {
        nixpkgs = import nixpkgs { system = "x86_64-linux"; };
      };

      defaults = { ... }: {
        deployment.buildOnTarget = true;
      };

      glw = { config, pkgs, ... }: {
        deployment = {
          allowLocalDeployment = true;
          targetHost = null;
        };
        imports = [
          ./hwconfig/glw.nix
          home-manager.nixosModules.home-manager
          commonConfig
        ];
        networking.hostName = "glw";
        environment.systemPackages = [ pkgs.moonlight-qt ];
      };

      homebase = { config, pkgs, ... }: {
        deployment = {
          allowLocalDeployment = false;
          targetHost = "homebase.lan";
          targetUser = "root";
          buildOnTarget = true;
        };
        imports = [
          ./hwconfig/homebase.nix
          home-manager.nixosModules.home-manager
          commonConfig
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
      };
    };

    formatter.x86_64-linux = pkgs.nixfmt-rfc-style;
  };
}
