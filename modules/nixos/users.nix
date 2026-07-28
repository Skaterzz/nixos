{ config, lib, pkgs, ... }:

{
  users.users.joshr = {
    isNormalUser = true;
    description = "Josh Randall";
    shell = pkgs.fish;
    extraGroups = [ "wheel" "networkmanager" "video" "input" "docker" ];

    # Only applied when the account is first created, so that a fresh install
    # can actually log in at SDDM. Change it immediately after first login:
    #   passwd
    # Once changed, the new password sticks (users.mutableUsers defaults to
    # true), and editing this line has no further effect.
    initialPassword = "changeme";
  };
}
