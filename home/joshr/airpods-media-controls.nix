{ ... }:

# AirPods expose their stem presses as Bluetooth AVRCP media commands. BlueZ's
# mpris-proxy forwards those commands to MPRIS players in the user session:
# one press toggles play/pause, two presses skip, and three presses go back.
#
# Home Manager owns the user service and starts it with Bluetooth, so there is
# no AUR package or session startup script to maintain.
{
  services.mpris-proxy.enable = true;
}
