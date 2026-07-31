{ config, lib, pkgs, ... }:

{
    environment.systemPackages = with pkgs; [
        libreoffice
        onlyoffice-desktopeditors
        kdePackages.okular
    ]
}