# Features:
# - Firefox: DuckDuckGo, vertical tabs, uBlock Origin, Dark Reader, SponsorBlock, Bitwarden, Catppuccin, YouTube Shorts Block, Tampermonkey
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
        (mkAddon {
          pname = "youtube-shorts-block";
          version = "1.5.3";
          addonId = "{34daeb50-c2d2-4f14-886a-7160b24d66a4}";
          url = "https://addons.mozilla.org/firefox/downloads/file/4487339/youtube_shorts_block-1.5.3.xpi";
          sha256 = "0hr0xczsclrxnyx4ng3jcmipcqr9g1yk6alrg4nxp0n77cwrcj3p";
        })
        (mkAddon {
          pname = "tampermonkey";
          version = "5.5.0";
          addonId = "firefox@tampermonkey.net";
          url = "https://addons.mozilla.org/firefox/downloads/file/4797143/tampermonkey-5.5.0.xpi";
          sha256 = "022r0s61bz7qg3r5vprlw78mm1bbiqn1yq1m908rcmmwip3k200r";
        })
      ];
    };
  };
}
