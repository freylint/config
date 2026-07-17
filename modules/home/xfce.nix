# Features:
# - XFCE home-manager config: WezTerm, Zsh, vkQuake desktop entry, vscode-server
# - XFWM4 window decoration: Catppuccin Mocha Mauve (written as XML, no xfconfd dep)
# - Panel: Whisker Menu, tasklist, expanding separator, systray, battery, clock, show desktop (declarative XML)
# - Battery plugin: icon+percentage+time, no bar, always visible, Catppuccin Mocha colours
# - Whisker Menu / show desktop icons: recoloured to Catppuccin Mocha Mauve via user hicolor overrides
# - Wallpaper: Julia set fractal generated in Catppuccin Mocha Mauve palette
let
  inherit (import ./common.nix)
    homeImports
    wezterm_cfg
    zsh_cfg
    vkquakeEntry
    ;
in
{ config, pkgs, lib, ... }:
let
  nixosSnowflakeCatppuccin = pkgs.runCommand "nix-snowflake-catppuccin-mauve.svg" { } ''
    sed \
      -e 's/#415e9a/#6a4fc7/g' \
      -e 's/#4a6baf/#7a5fd4/g' \
      -e 's/#5277c3/#9173e6/g' \
      -e 's/#699ad7/#a88cf3/g' \
      -e 's/#7eb1dd/#b698f5/g' \
      -e 's/#7ebae4/#cba6f7/g' \
      ${pkgs.nixos-icons}/share/icons/hicolor/scalable/apps/nix-snowflake.svg \
      > $out
  '';

  fractalScript = pkgs.writeText "fractal.py" ''
    import numpy as np, sys
    from PIL import Image

    W, H, MAX_ITER = 1920, 1080, 300
    c = complex(-0.7269, 0.1889)

    x = np.linspace(-1.6, 1.6, W)
    y = np.linspace(-0.9, 0.9, H)
    Z = (x[None, :] + 1j * y[:, None]).astype(np.complex128)

    smooth = np.zeros((H, W), dtype=np.float64)
    active = np.ones((H, W), dtype=bool)

    for i in range(MAX_ITER):
        Z[active] = Z[active] ** 2 + c
        esc = active & (np.abs(Z) >= 2.0)
        if esc.any():
            mu = i + 1.0 - np.log2(np.log2(np.abs(Z[esc]).clip(1.0 + 1e-10)) + 1e-10)
            smooth[esc] = np.maximum(0.0, mu)
            active &= ~esc

    t = np.sqrt(smooth / MAX_ITER).clip(0.0, 1.0)

    palette = np.array([
        [0x11, 0x11, 0x1b],
        [0x1e, 0x1e, 0x2e],
        [0x31, 0x32, 0x44],
        [0x6a, 0x4f, 0xc7],
        [0xcb, 0xa6, 0xf7],
        [0xb4, 0xbe, 0xfe],
        [0x89, 0xb4, 0xfa],
        [0xcb, 0xa6, 0xf7],
        [0x11, 0x11, 0x1b],
    ], dtype=np.float64)

    N = len(palette) - 1
    idx = t * N
    i0 = np.clip(np.floor(idx).astype(int), 0, N - 1)
    frac = (idx - i0)[..., None]
    pix = (palette[i0] * (1.0 - frac) + palette[i0 + 1] * frac).clip(0, 255).astype(np.uint8)
    Image.fromarray(pix, "RGB").save(sys.argv[1])
  '';

  wallpaper = pkgs.runCommand "catppuccin-mocha-mauve-fractal.png" {
    buildInputs = [ (pkgs.python3.withPackages (ps: [ ps.numpy ps.pillow ])) ];
  } "python3 ${fractalScript} \"$out\"";

  showdesktopCatppuccin = pkgs.runCommand "org.xfce.panel.showdesktop.svg" { } ''
    sed \
      -e 's/#070c0f/#1e1e2e/g' \
      -e 's/#263742/#313244/g' \
      -e 's/#485e6b/#45475a/g' \
      -e 's/#006888/#7c55e8/g' \
      -e 's/#00aade/#cba6f7/g' \
      ${pkgs.xfce4-panel}/share/icons/hicolor/scalable/apps/org.xfce.panel.showdesktop.svg \
      > $out
  '';
in
{
  imports = homeImports;
  programs = {
    wezterm = wezterm_cfg;
    zsh = zsh_cfg;
  };
  services.vscode-server.enable = true;
  xdg.desktopEntries.vkquake = vkquakeEntry config;

  home.file = {
    ".local/share/icons/hicolor/scalable/apps/org.xfce.panel.whiskermenu.svg".source = nixosSnowflakeCatppuccin;
    ".local/share/icons/hicolor/scalable/apps/org.xfce.panel.showdesktop.svg".source = showdesktopCatppuccin;
  };

  xdg.configFile = {
    "xfce4/xfconf/xfce-perchannel-xml/xfce4-desktop.xml" = {
      force = true;
      text = ''
        <?xml version="1.0" encoding="UTF-8"?>
        <channel name="xfce4-desktop" version="1.0">
          <property name="last-settings-migration-version" type="uint" value="1"/>
          <property name="backdrop" type="empty">
            <property name="screen0" type="empty">
              <property name="monitoreDP-1" type="empty">
                <property name="workspace0" type="empty">
                  <property name="last-image" type="string" value="${wallpaper}"/>
                  <property name="image-style" type="int" value="5"/>
                </property>
              </property>
            </property>
          </property>
        </channel>
      '';
    };

    "xfce4/xfconf/xfce-perchannel-xml/xfwm4.xml" = {
      force = true;
      text = ''
      <?xml version="1.0" encoding="UTF-8"?>
      <channel name="xfwm4" version="1.0">
        <property name="general" type="empty">
          <property name="theme" type="string" value="catppuccin-mocha-mauve-standard"/>
        </property>
      </channel>
    '';
    };

    "xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml" = {
      force = true;
      text = ''
      <?xml version="1.0" encoding="UTF-8"?>
      <channel name="xfce4-panel" version="1.0">
        <property name="configver" type="int" value="2"/>
        <property name="panels" type="array">
          <value type="int" value="1"/>
          <property name="panel-1" type="empty">
            <property name="position" type="string" value="p=1;x=9999;y=540"/>
            <property name="length" type="uint" value="100"/>
            <property name="position-locked" type="bool" value="true"/>
            <property name="mode" type="uint" value="1"/>
            <property name="size" type="uint" value="48"/>
            <property name="background-style" type="uint" value="1"/>
            <property name="background-rgba" type="string" value="#1e1e2eff"/>
            <property name="plugin-ids" type="array">
              <value type="int" value="1"/>
              <value type="int" value="2"/>
              <value type="int" value="3"/>
              <value type="int" value="4"/>
              <value type="int" value="7"/>
              <value type="int" value="5"/>
              <value type="int" value="6"/>
            </property>
          </property>
        </property>
        <property name="plugins" type="empty">
          <property name="plugin-1" type="string" value="whiskermenu"/>
          <property name="plugin-2" type="string" value="tasklist">
            <property name="grouping" type="uint" value="1"/>
            <property name="show-labels" type="bool" value="false"/>
          </property>
          <property name="plugin-3" type="string" value="separator">
            <property name="expand" type="bool" value="true"/>
            <property name="style" type="uint" value="0"/>
          </property>
          <property name="plugin-4" type="string" value="systray">
            <property name="square-icons" type="bool" value="true"/>
          </property>
          <property name="plugin-5" type="string" value="clock">
            <property name="mode" type="uint" value="2"/>
            <property name="digital-layout" type="uint" value="1"/>
            <property name="digital-time-format" type="string" value="%H:%M"/>
            <property name="digital-date-format" type="string" value="%m/%d"/>
            <property name="rotate-vertically" type="bool" value="false"/>
          </property>
          <property name="plugin-7" type="string" value="battery"/>
          <property name="plugin-6" type="string" value="showdesktop"/>
        </property>
      </channel>
    '';
    };
  };

  home.activation.xfceSetup = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    ${pkgs.gtk3}/bin/gtk-update-icon-cache -qft \
      ${config.home.homeDirectory}/.local/share/icons/hicolor 2>/dev/null || true
    mkdir -p "${config.home.homeDirectory}/.config/xfce4/panel"
    cat > "${config.home.homeDirectory}/.config/xfce4/panel/battery-7.rc" << 'EOF'
display_label=false
display_icon=true
display_power=false
display_percentage=true
display_bar=false
display_time=true
tooltip_display_percentage=true
tooltip_display_time=true
low_percentage=10
critical_percentage=5
action_on_low=1
action_on_critical=1
hide_when_full=0
colorA=rgb(203,166,247)
colorH=rgb(166,227,161)
colorL=rgb(249,226,175)
colorC=rgb(243,139,168)
command_on_low=
command_on_critical=
EOF
    xfce4-panel --restart 2>/dev/null || true
  '';

  home.stateVersion = "26.05";
}
