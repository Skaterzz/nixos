{ lib, pkgs, ... }:

{
    home.packages = with pkgs; [
        kdePackages.kdenlive
        audacity
    ];
}