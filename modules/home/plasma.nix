{ ... }:
{
  programs.plasma = {
    enable = true;
    workspace = {
      colorScheme = "CatppuccinMochaMauve";
      iconTheme = "Papirus-Dark";
      splashScreen.theme = "None";
      wallpaperPictureOfTheDay.provider = "apod";
    };
  };
}
