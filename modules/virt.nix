# Features:
# - KVM/QEMU virtualisation via libvirtd + virt-manager
# - Software TPM for VMs (OVMF UEFI firmware bundled with QEMU in 26.05)
# - SPICE USB redirection for USB passthrough to guests
{ ... }: {
  virtualisation.libvirtd = {
    enable = true;
    qemu.swtpm.enable = true;
  };
  virtualisation.spiceUSBRedirection.enable = true;
  programs.virt-manager.enable = true;
}
