{ ... }:

# The system-level half of the per-project dev environment story. The tools
# themselves are in home/joshr/dev.nix; these are settings only root can make,
# and each one exists because leaving it out breaks direnv shells in a way
# that's hard to diagnose from inside one.
{
  nix.settings = {
    # Keep the build-time dependencies of anything a GC root points at.
    #
    # A `nix develop` shell isn't a package — it's a derivation's *build*
    # environment, so what it needs is that derivation's inputs, not its
    # output. Without these two, `nix-collect-garbage` (which base.nix runs
    # weekly) is free to delete every compiler and header in a shell that
    # nothing has built recently, and the next `cd` into the project silently
    # re-downloads or rebuilds the lot.
    keep-outputs = true;
    keep-derivations = true;

    # Let joshr configure substituters — `cachix use <name>` writes to
    # nix.conf and is refused for an untrusted user, which is most of the
    # value of having cachix installed at all.
    #
    # This is a real grant: a trusted user can point the daemon at a binary
    # cache and have its contents accepted without further checking. It's the
    # same trust the single admin account on this machine already has by way
    # of sudo.
    trusted-users = [
      "root"
      "@wheel"
    ];

    # Show more of a failed builder's output than the default ten lines. Most
    # useful failure messages in a dev shell are longer than that.
    log-lines = 25;
  };
}
