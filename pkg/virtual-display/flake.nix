# Features:
# - NixOS module: services.virtualDisplay — AMD virtual display for Sunshine streaming sessions
# - Options: enable, amdgpuPciAddress, resolution (default 1920x1080), refreshRate (default 60)
# - Systemd user service: polls Sunshine streaming ports (47998-48000); enables Virtual-1 on connect, disables on disconnect
# - Physical display and its manager are never modified
# - Screensaver inhibition while a streaming session is active
{
  description = "AMD virtual display NixOS module for Sunshine streaming sessions";
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
          getExe
          getExe'
          mkEnableOption
          mkIf
          mkOption
          types
          ;
        kscreen-doctor = getExe' pkgs.kdePackages.kscreen "kscreen-doctor";
        dbus-send = getExe' pkgs.dbus "dbus-send";
        ss = getExe' pkgs.iproute2 "ss";
        jq = getExe pkgs.jq;
        monitorScript = pkgs.writeShellScript "virtual-display-monitor" ''
          COOKIE=""
          STREAMING=false

          virtual_active() {
            ${kscreen-doctor} -j 2>/dev/null \
              | ${jq} -e '.outputs[] | select(.name=="Virtual-1" and .enabled)' >/dev/null 2>&1
          }

          # Sunshine streams on 47998 (video), 47999 (audio), 48000 (control)
          streaming_active() {
            ${ss} -H -n state established \
              'sport = :47998 or sport = :47999 or sport = :48000' 2>/dev/null | grep -q .
          }

          inhibit() {
            [[ -n "$COOKIE" ]] && return
            COOKIE=$(${dbus-send} --session --print-reply \
              --dest=org.freedesktop.ScreenSaver /ScreenSaver \
              org.freedesktop.ScreenSaver.Inhibit \
              string:"virtual-display-manager" string:"Sunshine streaming active" 2>/dev/null \
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
              output.Virtual-1.mode.${cfg.resolution}@${toString cfg.refreshRate} 2>/dev/null || true
            inhibit
            STREAMING=true
          }

          # Retries up to 3× with verification; uninhibits only after confirmed success
          # to preserve the invariant: COOKIE is set iff virtual display is active.
          disable_virtual() {
            local attempt
            for attempt in 1 2 3; do
              ${kscreen-doctor} output.Virtual-1.disable 2>/dev/null || true
              sleep "$attempt"
              virtual_active || { uninhibit; STREAMING=false; return 0; }
            done
            uninhibit
            STREAMING=false
          }

          trap 'disable_virtual; exit 0' INT TERM

          while true; do
            if streaming_active; then
              $STREAMING || enable_virtual
            else
              $STREAMING && disable_virtual
            fi
            sleep 3
          done
        '';
      in
      {
        options.services.virtualDisplay = {
          enable = mkEnableOption "virtual display for Sunshine streaming sessions";
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
            description = "Manage virtual display for Sunshine streaming sessions";
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
