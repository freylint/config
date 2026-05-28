# Features:
# - NixOS VM config for testing the virtual-display module
# - Enables services.virtualDisplay with a placeholder PCI address (no AMD GPU in QEMU)
# - SSH on host port 2222: root / root  (ssh -p 2222 root@localhost)
# - virtual-display-manager will fail at runtime (no AMD GPU or KDE in QEMU)
# - verifies module evaluation, kernel param propagation, and unit file generation
{ ... }:
{
  networking.hostName = "vdisp-test";

  services.virtualDisplay = {
    enable = true;
    amdgpuPciAddress = "0000:00:02.0";
  };

  virtualisation.vmVariant.virtualisation = {
    cores = 2;
    memorySize = 1024;
    graphics = false;
    forwardPorts = [ { from = "host"; host.port = 2222; guest.port = 22; } ];
  };

  services.openssh = {
    enable = true;
    settings.PermitRootLogin = "yes";
  };
  users.users.root.initialPassword = "root";

  system.stateVersion = "25.11";
}
