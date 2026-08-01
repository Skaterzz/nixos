{ pkgs, ... }:

# Note vivaldi is deliberately not here: it is the default browser, so it is
# installed from home/joshr/browser.nix instead. Only gamestation-niri imports
# this module, and the browser has to exist on all four desktop hosts.
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
        haruna
        kdePackages.gwenview
        kdePackages.elisa
	termius
	kdePackages.kcalc
	thunderbird
    ];
}
