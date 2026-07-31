{ pkgs, ... }:

{
    environment.systemPackages = with pkgs; [
        discord
        papirus-icon-theme
        signal-desktop
        joplin-desktop
        bitwarden-desktop
        nextcloud-client
        obs-studio
        lutris
        localsend
        playerctl
        cava
        cmatrix
        yt-dlp
        vivaldi
        haruna
        kdePackages.gwenview
        kdePackages.elisa
    ];
}
