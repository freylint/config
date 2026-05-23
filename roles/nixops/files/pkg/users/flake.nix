{
  description = "User configurations";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nix-vscode-extensions = {
      url = "github:nix-community/nix-vscode-extensions";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    { self, nixpkgs, nix-vscode-extensions }:
    let
      vscodeExtensions = nix-vscode-extensions.extensions.x86_64-linux;

      mkUser = pkgs: name: {
        isNormalUser = true;
        description = name;
        extraGroups = [
          "networkmanager"
          "wheel"
        ];
        shell = pkgs.zsh;
        packages = with pkgs; [
          kdePackages.kate
        ];
      };

      homeConfig =
        { pkgs, ... }:
        {
          home.stateVersion = "25.11";
          services.vscode-server.enable = true;

          programs.firefox = {
            enable = true;
            profiles.default = {
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
                  meta = { };
                })
                (pkgs.nur.repos.rycee.firefox-addons.buildFirefoxXpiAddon {
                  pname = "sponsorblock";
                  version = "6.1.5";
                  addonId = "sponsorBlocker@ajay.app";
                  url = "https://addons.mozilla.org/firefox/downloads/file/4773757/sponsorblock-6.1.5.xpi";
                  sha256 = "051f3gypy72m4irhyk62fkw5bdwid14kdm46g8q8xdxhxjd25v6q";
                  meta = { };
                })
                (pkgs.nur.repos.rycee.firefox-addons.buildFirefoxXpiAddon {
                  pname = "bitwarden";
                  version = "2026.4.0";
                  addonId = "{446900e4-71c2-419f-a6a7-df9c091e268b}";
                  url = "https://addons.mozilla.org/firefox/downloads/file/4796063/bitwarden_password_manager-2026.4.0.xpi";
                  sha256 = "045ffhr158lnafwdpyijhwnzzjf42rgwzpwvzva5b1hwl71zdgfc";
                  meta = { };
                })
                (pkgs.nur.repos.rycee.firefox-addons.buildFirefoxXpiAddon {
                  pname = "catppuccin-mocha-mauve";
                  version = "old";
                  addonId = "{76aabc99-c1a8-4c1e-832b-d4f2941d5a7a}";
                  url = "https://github.com/catppuccin/firefox/releases/download/old/catppuccin_mocha_mauve.xpi";
                  sha256 = "1gkv12034d2dbbvr2fmxbqifmgmfv0lh58my1gmkcvfpxrap6ad5";
                  meta = { };
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

          xdg.desktopEntries.vkquake = {
            name = "vkQuake";
            comment = "Vulkan Quake port based on QuakeSpasm";
            exec = "vkquake -basedir /home/gen/Games/Heroic/Quake";
            icon = "vkquake";
            categories = [ "Game" ];
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
              vscodeExtensions.vscode-marketplace.ms-vscode-remote.remote-ssh
              vscodeExtensions.vscode-marketplace.slevesque.shader
              vscodeExtensions.vscode-marketplace.timgjones.hlsltools
              vscodeExtensions.vscode-marketplace.raczzalan.webgl-glsl-editor
            ];
            userSettings = {
              "editor.fontFamily" = "'FiraCode Nerd Font', monospace";
              "editor.fontLigatures" = true;
              "terminal.integrated.fontFamily" = "'FiraCode Nerd Font'";
              "workbench.colorTheme" = "Catppuccin Mocha";
              "extensions.ignoreRecommendations" = true;
              "git.autofetch" = true;
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
            shellAliases = {
              wanip = "curl -s ifconfig.me && echo";
            };
          };
        };
    in
    {
      nixosModules.default =
        { pkgs, ... }:
        {
          users.users.gen = mkUser pkgs "gen";
          users.users.bat = mkUser pkgs "bat";

          home-manager.users.gen = homeConfig;
          home-manager.users.bat = homeConfig;
        };
    };
}
