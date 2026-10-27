# The settings Shell Settings may own: one entry per setting, with its NixOS
# option path. `id` is its key in settings.json; `page` is the Settings page
# that shows it; `control` is how (switch, int with min/max, timezone, text);
# `tier` says when it takes effect (rebuild, restart). modules/managed.nix
# turns each into an option definition, and the flake's `amaneSettings`
# output gives Settings the same list with each option's value, type and
# which file sets it.
[
  {
    id = "timeZone";
    path = [ "time" "timeZone" ];
    page = "about";
    label = "Time zone";
    control = "timezone";
    tier = "rebuild";
  }
  {
    id = "tailscale";
    path = [ "services" "tailscale" "enable" ];
    page = "about";
    label = "Tailscale";
    control = "switch";
    tier = "rebuild";
  }
  {
    id = "bootEntries";
    path = [ "boot" "loader" "systemd-boot" "configurationLimit" ];
    page = "storage";
    label = "Boot entries kept";
    control = "int";
    min = 1;
    max = 50;
    tier = "restart";
  }
]
