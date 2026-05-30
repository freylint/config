# Features:
# - NixOS module: services.virtualDisplay — AMD virtual display for headless Wayland sessions
# - Options: enable, amdgpuPciAddress, resolution (default 1920x1080), refreshRate (default 60)
# - Systemd user service: watches DRM hotplug, toggles Virtual-1, inhibits screensaver
{
  description = "AMD virtual display NixOS module for headless Wayland sessions";
  outputs = _: {
    nixosModules.default =
      {
        config,
        pkgs,
        lib,
        ...
      }:
      let
        cfg = config.services.virtualDisplay;
        inherit (lib)
          getExe'
          mkEnableOption
          mkIf
          mkOption
          types
          ;
        kscreen-doctor = getExe' pkgs.kdePackages.kscreen "kscreen-doctor";
        dbus-send = getExe' pkgs.dbus "dbus-send";
        udevadm = getExe' pkgs.systemd "udevadm";
        monitorScript = pkgs.writeShellScript "virtual-display-monitor" ''
          COOKIE=""

          physical_connected() {
            for f in /sys/class/drm/*/status; do
              [[ "$f" == *Virtual* ]] && continue
              [[ "$(<"$f")" == "connected" ]] && return 0
            done
            return 1
          }
          inhibit() {
            [[ -n "$COOKIE" ]] && return
            COOKIE=$(${dbus-send} --session --print-reply \
              --dest=org.freedesktop.ScreenSaver /ScreenSaver \
              org.freedesktop.ScreenSaver.Inhibit \
              string:"virtual-display-manager" string:"Virtual display active" 2>/dev/null \
              | awk '/uint32/{print $2}') || true
          }
          uninhibit() {
            [[ -z "$COOKIE" ]] && return
            ${dbus-send} --session \
              --dest=org.freedesktop.ScreenSaver /ScreenSaver \
              org.freedesktop.ScreenSaver.UnInhibit \
              uint32:"$COOKIE" 2>/dev/null || true
            COOKIE=""
          }
          enable_virtual() {
            ${kscreen-doctor} \
              output.Virtual-1.enable \
              output.Virtual-1.mode.${cfg.resolution}@${toString cfg.refreshRate} || true
            inhibit
          }
          disable_virtual() {
            ${kscreen-doctor} output.Virtual-1.disable || true
            uninhibit
          }
          update_state() {
            if physical_connected; then disable_virtual; else enable_virtual; fi
          }
          trap 'disable_virtual; exit 0' INT TERM

          while true; do
            update_state
            # Process substitution keeps while-read in the parent shell so COOKIE
            # mutations (inhibit/uninhibit) propagate correctly across hotplug events.
            while read -r line; do
              [[ "$line" == *"HOTPLUG=1"* ]] && { sleep 1; update_state; }
            done < <(${udevadm} monitor --subsystem-match=drm --property 2>/dev/null)
            sleep 2
          done
        '';
      in
      {
        options.services.virtualDisplay = {
          enable = mkEnableOption "virtual display for headless Wayland sessions";
          amdgpuPciAddress = mkOption {
            type = types.str;
            description = "AMD GPU PCI address for amdgpu.virtual_display (e.g. 0000:03:00.0)";
          };
          resolution = mkOption {
            type = types.str;
            default = "1920x1080";
            description = "Virtual display resolution (WIDTHxHEIGHT)";
          };
          refreshRate = mkOption {
            type = types.int;
            default = 60;
            description = "Virtual display refresh rate in Hz";
          };
        };

        config = mkIf cfg.enable {
          # amdgpu.virtual_display=ADDR,N creates N virtual DRM connectors at boot.
          boot.kernelParams = [ "amdgpu.virtual_display=${cfg.amdgpuPciAddress},1" ];
          systemd.user.services.virtual-display-manager = {
            description = "Manage virtual display for headless Wayland sessions";
            wantedBy = [ "graphical-session.target" ];
            partOf = [ "graphical-session.target" ];
            after = [ "graphical-session.target" ];
            serviceConfig = {
              Type = "simple";
              ExecStart = monitorScript;
              Restart = "on-failure";
              RestartSec = "5s";
            };
          };
        };
      };
  };
}
