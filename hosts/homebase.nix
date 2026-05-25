{ ... }:
{
  services.fwupd.enable = false;
  services.sunshine = {
    enable = true;
    autoStart = true;
    capSysAdmin = true;
    openFirewall = true;
  };

  systemd.sleep.settings.Sleep = {
    AllowSuspend = false;
    AllowHibernation = false;
  };

  home-manager.users.gen =
    { ... }:
    {
      programs.plasma.kscreenlocker = {
        autoLock = true;
        lockOnResume = false;
        appearance.alwaysShowClock = false;
      };

      programs.plasma.configFile."kscreenlockerrc" = {
        "Greeter"."WallpaperPlugin" = "io.lmpriestley.fireplace";
        "Daemon"."Timeout" = "10";
        # Large grace period so screensaver dismisses without password prompt
        "Daemon"."LockGrace" = "999999";
      };

      programs.plasma.powerdevil.AC.turnOffDisplay = {
        idleTimeout = 600000;
        idleTimeoutWhenLocked = 600000;
      };
    };
}
