# Features:
# - Firefox: DuckDuckGo, vertical tabs, uBlock Origin, Dark Reader, SponsorBlock, Bitwarden, Catppuccin
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
}
