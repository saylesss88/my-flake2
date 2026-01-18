{
  lib,
  ...
}:
{
  # Change your-user
  home.username = "your-user";
  # Change your-user
  home.homeDirectory = lib.mkDefault "/home/your-user";
  home.stateVersion = "25.05";

  imports = [
  ];
  programs.home-manager.enable = true;

  # xdg.portal = {
  #   enable = true;
  #   extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
  #   config.common.default = [ "gtk" ];
  # };
  xdg.userDirs.enable = true;
  xdg.userDirs.createDirectories = true;
}
