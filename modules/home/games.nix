{ ... }:
{
  xdg.desktopEntries.vkquake = {
    name = "vkQuake";
    comment = "Vulkan Quake port based on QuakeSpasm";
    exec = "vkquake -basedir /home/gen/Games/Heroic/Quake";
    icon = "vkquake";
    categories = [ "Game" ];
  };
}
