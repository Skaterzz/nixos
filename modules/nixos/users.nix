{ config, lib, pkgs, ... }:

{
  users.users.joshr = {
    isNormalUser = true;
    description = "Josh Randall";
    shell = pkgs.fish;
    extraGroups = [ "wheel" "networkmanager" "video" "input" "docker" ];
  };
}
