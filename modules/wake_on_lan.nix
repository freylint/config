# Features:
# - WoL (magic packet) on all physical Ethernet interfaces at boot
{ pkgs, ... }: {
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
}
