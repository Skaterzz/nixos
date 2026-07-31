{ config, lib, pkgs, ... }:

{
    environment.systemPackages = with pkgs; [
        kdePackages.kdenlive
        audacity
    ]
}