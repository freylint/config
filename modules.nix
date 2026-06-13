# Features:
# - overlays: NUR, rust-overlay, nix-vscode-extensions overlays; unfree allowed
# - desktop: KDE Plasma 6, SDDM Wayland, ksshaskpass, excluded KDE packages, catppuccin-kde
# - sway_desktop: greetd/tuigreet login, Sway WM, XDG portals (wlr+gtk), wofi/grim/slurp/wl-clipboard
# - packages: system packages — dev (elm, rust), infra (nil LSP, awscli2), eda, desktop groups (incl. Signal)
# - wake_on_lan: WoL (magic packet) on all physical Ethernet interfaces at boot
# - controllers: udev + Steam Input — steam-hardware, xone, xpadneo, gamescope session,
#                game-devices-udev-rules, antimicrox/jstest-gtk/linuxConsoleTools/evtest
# - users: normal users with wheel/networkmanager/docker/input groups, admin SSH keys, kate
# - firefox: DuckDuckGo, vertical tabs, uBlock Origin, Dark Reader, SponsorBlock, Bitwarden, Catppuccin
# - gtk: Catppuccin Mocha Mauve GTK theme, Papirus-Dark icons
# - home_sops: SOPS age key derived from SSH ed25519 key on activation
# - flatpak_profile: ~/.profile exporting Flatpak XDG_DATA_DIRS paths
# - vscode: extensions, FiraCode, Catppuccin Mocha, SOPS integration, nil Nix LSP, vscodevim, elm-ls, test-adapter-converter
# - home: home-manager module — Firefox, GTK, VS Code, plasma, WezTerm, Zsh, Baloo, games
# - sway_home: home-manager module — Firefox, GTK, VS Code, Sway WM, waybar (Nerd Font + Catppuccin Mocha), mako, swaylock/swayidle, WezTerm, Zsh
# - base_workstation: shared NixOS config — audio, Docker, Bluetooth, SSH, ntsync, gamemode, Flatpak (nix-flatpak, com.jagex.Launcher), common packages
let
  overlays =
    {
      nur,
      rust-overlay,
      nix-vscode-extensions,
      ...
    }:
    {
      nixpkgs.overlays = [
        nur.overlays.default
        rust-overlay.overlays.default
        nix-vscode-extensions.overlays.default
      ];
      nixpkgs.config.allowUnfree = true;
    };

  desktop =
    { pkgs, ... }:
    let
      ksshaskpass = "${pkgs.kdePackages.ksshaskpass}/bin/ksshaskpass";
    in
    {
      services = {
        xserver = {
          enable = true;
          xkb.layout = "us";
          excludePackages = [ pkgs.xterm ];
        };
        displayManager = {
          sddm = {
            enable = true;
            wayland.enable = true;
            settings = {
              General.Numlock = "on";
              Theme.EnableAvatars = false;
            };
          };
          defaultSession = "plasma";
        };
        desktopManager.plasma6.enable = true;
      };
      environment = {
        plasma6.excludePackages = with pkgs.kdePackages; [ konsole elisa oxygen khelpcenter krdp ];
        sessionVariables = {
          SSH_ASKPASS_REQUIRE = "prefer";
          SUDO_ASKPASS = ksshaskpass;
        };
        systemPackages = [ pkgs.catppuccin-kde ];
      };
      programs.ssh.askPassword = ksshaskpass;
    };

  sway_desktop =
    { pkgs, ... }:
    {
      services.greetd = {
        enable = true;
        settings.default_session = {
          command = "${pkgs.tuigreet}/bin/tuigreet --time --cmd sway";
          user = "greeter";
        };
      };
      programs.sway = {
        enable = true;
        wrapperFeatures.gtk = true;
      };
      xdg.portal = {
        enable = true;
        wlr.enable = true;
        extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
      };
      environment = {
        sessionVariables = {
          MOZ_ENABLE_WAYLAND = "1";
          NIXOS_OZONE_WL = "1";
          XDG_CURRENT_DESKTOP = "sway";
        };
        systemPackages = with pkgs; [ wofi grim slurp wl-clipboard ];
      };
      security.polkit.enable = true;
    };

  packages =
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
          extensions = [ "rust-src" "rust-analyzer" ];
        })
        elmPackages.elm
        elmPackages.elm-format
        colmena
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
        catppuccin-papirus-folders
        gnome-disk-utility
        gparted
      ];
    };

  wake_on_lan =
    { pkgs, ... }:
    {
      systemd.services.wake-on-lan = {
        description = "Enable Wake-on-LAN on all ethernet interfaces";
        wantedBy = [ "multi-user.target" ];
        after = [ "network-pre.target" ];
        wants = [ "network-pre.target" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = pkgs.writeShellScript "enable-wol" ''
            for iface in $(ls /sys/class/net); do
              # type=1 is Ethernet; skip virtual interfaces without a device dir
              if [ -d "/sys/class/net/$iface/device" ] && \
                 [ "$(cat /sys/class/net/$iface/type 2>/dev/null)" = "1" ]; then
                ${pkgs.ethtool}/bin/ethtool -s "$iface" wol g || true
              fi
            done
          '';
        };
      };
    };

  controllers =
    { pkgs, ... }:
    {
      # Built-in udev + kmod stack: steam-hardware covers Valve, DualShock 4/5,
      # DualSense, Switch Pro, Wii, and generic HID gamepads via uaccess.
      hardware = {
        steam-hardware.enable = true;
        xone.enable = true; # wired Xbox One / Series + dongle (out-of-tree kmod)
        xpadneo.enable = true; # Bluetooth Xbox controllers
      };
      # extest exposes Steam Input as XInput so non-Steam apps see remapped controllers.
      # gamescopeSession adds a dedicated compositor session for handheld-style play.
      programs.steam = {
        extest.enable = true;
        gamescopeSession.enable = true;
      };
      # Extra vendor rules: 8BitDo, Stadia, Razer, Switch joycond, evhz, etc.
      services.udev.packages = [ pkgs.game-devices-udev-rules ];
      environment.systemPackages = with pkgs; [ antimicrox jstest-gtk linuxConsoleTools evtest ];
    };

  mkUsers =
    getExtraPkgs:
    {
      lib,
      pkgs,
      adminKeys,
      userNames,
      ...
    }:
    let
      mkUser = name: {
        isNormalUser = true;
        description = name;
        extraGroups = [ "networkmanager" "wheel" "docker" "input" ];
        shell = pkgs.zsh;
        openssh.authorizedKeys.keys = adminKeys;
        packages = getExtraPkgs pkgs;
      };
    in
    {
      users.users =
        lib.genAttrs userNames mkUser
        // { root.openssh.authorizedKeys.keys = adminKeys; };
    };

  users = mkUsers (pkgs: [ pkgs.kdePackages.kate ]);

  firefox =
    { pkgs, ... }:
    let
      mkAddon =
        attrs: pkgs.nur.repos.rycee.firefox-addons.buildFirefoxXpiAddon (attrs // { meta = { }; });
    in
    {
      programs.firefox = {
        enable = true;
        configPath = ".mozilla/firefox";
        profiles.default = {
          search.default = "ddg";
          settings = {
            "sidebar.verticalTabs" = true;
            "browser.newtabpage.activity-stream.feeds.section.topstories" = false;
            "browser.newtabpage.activity-stream.showSponsored" = false;
          };
          extensions.packages = [
            pkgs.nur.repos.rycee.firefox-addons.ublock-origin
            (mkAddon {
              pname = "dark-reader";
              version = "4.9.125";
              addonId = "addon@darkreader.org";
              url = "https://addons.mozilla.org/firefox/downloads/file/4783321/darkreader-4.9.125.xpi";
              sha256 = "0a5g7rkc0fgnp7fpwk37703yksbwh1csahgq22drpq3kr25s3a91";
            })
            (mkAddon {
              pname = "sponsorblock";
              version = "6.1.5";
              addonId = "sponsorBlocker@ajay.app";
              url = "https://addons.mozilla.org/firefox/downloads/file/4773757/sponsorblock-6.1.5.xpi";
              sha256 = "051f3gypy72m4irhyk62fkw5bdwid14kdm46g8q8xdxhxjd25v6q";
            })
            (mkAddon {
              pname = "bitwarden";
              version = "2026.4.0";
              addonId = "{446900e4-71c2-419f-a6a7-df9c091e268b}";
              url = "https://addons.mozilla.org/firefox/downloads/file/4796063/bitwarden_password_manager-2026.4.0.xpi";
              sha256 = "045ffhr158lnafwdpyijhwnzzjf42rgwzpwvzva5b1hwl71zdgfc";
            })
            (mkAddon {
              pname = "catppuccin-mocha-mauve";
              version = "old";
              addonId = "{76aabc99-c1a8-4c1e-832b-d4f2941d5a7a}";
              url = "https://github.com/catppuccin/firefox/releases/download/old/catppuccin_mocha_mauve.xpi";
              sha256 = "1gkv12034d2dbbvr2fmxbqifmgmfv0lh58my1gmkcvfpxrap6ad5";
            })
          ];
        };
      };
    };

  gtk =
    { pkgs, config, ... }:
    {
      gtk = {
        enable = true;
        theme = {
          name = "Catppuccin-Mocha-Standard-Mauve-Dark";
          package = pkgs.catppuccin-gtk.override {
            accents = [ "mauve" ];
            size = "standard";
            variant = "mocha";
          };
        };
        gtk4.theme = config.gtk.theme;
        iconTheme = {
          name = "Papirus-Dark";
          package = pkgs.papirus-icon-theme;
        };
      };
    };

  home_sops =
    { pkgs, lib, ... }:
    {
      home.activation.sopsAgeKey = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        KEY_FILE="$HOME/.config/sops/age/keys.txt"
        SSH_KEY="$HOME/.ssh/id_ed25519"
        if [ ! -f "$SSH_KEY" ]; then
          echo "sops-age: $SSH_KEY not found; age key not derived" >&2
        elif [ ! -f "$KEY_FILE" ]; then
          mkdir -p "$(dirname "$KEY_FILE")"
          ${pkgs.ssh-to-age}/bin/ssh-to-age -private-key -i "$SSH_KEY" > "$KEY_FILE"
          chmod 600 "$KEY_FILE"
        fi
      '';
    };

  vscode =
    { pkgs, lib, ... }:
    {
      # VS Code marks nix-managed extension versions as obsolete when the symlink
      # layout changes between home-manager generations. Clear .obsolete on each
      # activation so VS Code starts with a clean slate.
      home.activation.clearVscodeExtensionsObsolete = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        $DRY_RUN_CMD rm -f "$HOME/.vscode/extensions/.obsolete"
      '';
      programs.vscode = {
        enable = true;
        profiles.default = {
          extensions =
            (with pkgs.vscode-extensions; [
              anthropic.claude-code
              jnoortheen.nix-ide
              catppuccin.catppuccin-vsc
              mshr-h.veriloghdl
              antyos.openscad
              ms-vscode-remote.remote-ssh
              signageos.signageos-vscode-sops
              vscodevim.vim
              hbenl.vscode-test-explorer
              ms-vscode.test-adapter-converter
              elmtooling.elm-ls-vscode
            ])
            ++ (with pkgs.vscode-marketplace; [
              slevesque.shader
              timgjones.hlsltools
              raczzalan.webgl-glsl-editor
            ]);
          userSettings = {
            "editor.fontFamily" = "'FiraCode Nerd Font', monospace";
            "editor.fontLigatures" = true;
            "terminal.integrated.fontFamily" = "'FiraCode Nerd Font'";
            "workbench.colorTheme" = "Catppuccin Mocha";
            "extensions.ignoreRecommendations" = true;
            "git.autofetch" = true;
            "git.confirmSync" = false;
            "nix.enableLanguageServer" = true;
            "nix.serverPath" = "nil";
            "elmLS.elmPath" = "elm";
            "elmLS.elmFormatPath" = "elm-format";
            "sops.enabled" = true;
            "sops.creationEnabled" = false;
            "files.associations"."secrets/**/*.yaml" = "yaml";
          };
        };
      };
    };

  wezterm_cfg = {
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

  zsh_cfg = {
    enable = true;
    syntaxHighlighting.enable = true;
    autosuggestion.enable = true;
    oh-my-zsh = {
      enable = true;
      theme = "robbyrussell";
      plugins = [ "git" ];
    };
    shellAliases.wanip = "curl -s ifconfig.me && echo";
  };

  flatpak_profile = {
    home.file.".profile".text = ''
      export XDG_DATA_DIRS=$XDG_DATA_DIRS:/usr/share:/var/lib/flatpak/exports/share:$HOME/.local/share/flatpak/exports/share
    '';
  };

  homeImports = [ firefox gtk home_sops vscode flatpak_profile ];

  vkquakeEntry =
    config:
    {
      name = "vkQuake";
      comment = "Vulkan Quake port based on QuakeSpasm";
      exec = "vkquake -basedir ${config.home.homeDirectory}/Games/Heroic/Quake";
      icon = "vkquake";
      categories = [ "Game" ];
    };

  home =
    { config, ... }:
    {
      imports = homeImports;
      programs = {
        plasma = {
          enable = true;
          workspace = {
            colorScheme = "CatppuccinMochaMauve";
            iconTheme = "Papirus-Dark";
            splashScreen.theme = "None";
            wallpaperPictureOfTheDay.provider = "apod";
          };
        };
        wezterm = wezterm_cfg;
        zsh = zsh_cfg;
      };
      xdg = {
        configFile."baloofilerc".text = ''
          [Basic Settings]
          Indexing-Enabled=false
        '';
        desktopEntries.vkquake = vkquakeEntry config;
      };
      services.vscode-server.enable = true;
      home.stateVersion = "26.05";
    };

  sway_home =
    { pkgs, config, ... }:
    let
      swaylockCmd = "${pkgs.swaylock}/bin/swaylock -f";
    in
    {
      imports = homeImports;
      wayland.windowManager.sway = {
        enable = true;
        config = {
          modifier = "Mod4";
          terminal = "wezterm";
          menu = "wofi --show drun";
          bars = [ { command = "waybar"; } ];
          startup = [ { command = "mako"; } ];
        };
      };
      programs = {
        waybar = {
          enable = true;
          settings = [{
            layer = "top";
            position = "top";
            modules-left = [ "sway/workspaces" "sway/mode" ];
            modules-center = [ "clock" ];
            modules-right = [ "pulseaudio" "network" "cpu" "memory" "battery" "tray" ];
            "sway/workspaces".format = "{icon}";
            clock = { format = " {:%H:%M}"; format-alt = " {:%Y-%m-%d}"; };
            cpu.format = " {usage}%";
            memory.format = " {}%";
            battery = {
              format = "{icon} {capacity}%";
              format-charging = " {capacity}%";
              format-icons = [ "" "" "" "" "" ];
            };
            network = {
              format-wifi = " {essid}";
              format-ethernet = " {ipaddr}";
              format-disconnected = " Disconnected";
            };
            pulseaudio = {
              format = "{icon} {volume}%";
              format-muted = " Muted";
              format-icons.default = [ "" "" "" ];
            };
          }];
          style = ''
            * {
              font-family: "FiraCode Nerd Font", monospace;
              font-size: 13px;
              border: none;
              border-radius: 0;
              min-height: 0;
              color: #cdd6f4;
              background: transparent;
            }
            window#waybar {
              background-color: #1e1e2e;
            }
            #workspaces button {
              color: #cdd6f4;
              background: transparent;
              padding: 0 6px;
            }
            #workspaces button.active { color: #cba6f7; }
            #workspaces button.urgent { color: #f38ba8; }
            #clock, #cpu, #memory, #network, #pulseaudio, #battery, #tray {
              padding: 0 10px;
              color: #cdd6f4;
            }
            #battery.charging { color: #a6e3a1; }
            #battery.warning:not(.charging) { color: #f9e2af; }
            #battery.critical:not(.charging) { color: #f38ba8; }
          '';
        };
        swaylock.settings.color = "1e1e2e";
        wezterm = wezterm_cfg;
        zsh = zsh_cfg;
      };
      services = {
        mako.enable = true;
        swayidle = {
          enable = true;
          events = { before-sleep = swaylockCmd; };
          timeouts = [ { timeout = 600; command = swaylockCmd; } ];
        };
        vscode-server.enable = true;
      };
      xdg.desktopEntries.vkquake = vkquakeEntry config;
      home.stateVersion = "26.05";
    };

  base_workstation =
    { pkgs, ... }:
    {
      imports = [
        overlays
        packages
        wake_on_lan
        controllers
        # virtual-display moved to pkg/virtual-display/ (standalone flake, imported by flake.nix)
      ];
      security.rtkit.enable = true;
      virtualisation.docker.enable = true;
      services = {
        flatpak = {
          enable = true;
          packages = [ "com.jagex.Launcher" ];
        };
        pulseaudio.enable = false;
        pipewire = {
          enable = true;
          alsa = {
            enable = true;
            support32Bit = true;
          };
          pulse.enable = true;
        };
        blueman.enable = true;
        printing.enable = true;
        openssh.enable = true;
        udev.extraRules = ''KERNEL=="ntsync", TAG+="uaccess"'';
      };
      hardware.bluetooth.enable = true;
      boot = {
        loader = {
          systemd-boot.enable = true;
          efi.canTouchEfiVariables = true;
        };
        kernelModules = [ "ntsync" ]; # requires Linux 6.14+
      };
      time.timeZone = "America/New_York";
      i18n.defaultLocale = "en_US.UTF-8";
      networking = {
        domain = "freyground.com";
        networkmanager.enable = true;
      };
      nix.settings.experimental-features = [ "nix-command" "flakes" ];
      sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
      fonts.packages = [ pkgs.nerd-fonts.fira-code ];
      programs = {
        alvr.enable = true;
        gamemode.enable = true;
        steam.enable = true;
        zsh.enable = true;
      };
      home-manager = {
        useGlobalPkgs = true;
        useUserPackages = true;
        backupCommand = "mv \"$1\" \"$1.$(date +%Y%m%dT%H%M%S).bak\"";
      };
      system.stateVersion = "26.05";
    };

in
{
  inherit
    base_workstation
    desktop
    sway_desktop
    users
    home
    sway_home
    ;
}
