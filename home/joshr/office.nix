{ lib, pkgs, ... }:

{
    home.packages = with pkgs; [
        libreoffice
        onlyoffice-desktopeditors
        kdePackages.okular
    ];
}