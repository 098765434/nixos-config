# The settings Shell Settings may own: one entry per setting, with its NixOS
# option path. `id` is its key in settings.json; `page` is the Settings page
# that shows it (about, services, power, apps, storage); `control` is how:
#   switch                a boolean
#   int (min, max)        a slider over the range
#   choice (choices)      one of `choices = [ { label; value; } … ]`
#   timezone / text       a field
#   packages              a list of nixpkgs attribute paths (Apps draws it)
# `tier` says when it takes effect (rebuild, restart). A service entry may
# name its systemd `unit` (and `scope = "user"` for a user unit) so Settings
# shows whether it's running, and `onDemand`, the id of its "only when
# needed" switch. modules/managed.nix turns each into an option definition,
# and the flake's `amaneSettings` output gives Settings the same list with
# each option's value, type and which file sets it. The amane.* paths are
# declared in modules/options.nix.
let
  minutes = [
    { label = "1 minute"; value = 60; }
    { label = "2 minutes"; value = 120; }
    { label = "3 minutes"; value = 180; }
    { label = "4 minutes"; value = 240; }
    { label = "5 minutes"; value = 300; }
    { label = "10 minutes"; value = 600; }
    { label = "15 minutes"; value = 900; }
    { label = "30 minutes"; value = 1800; }
    { label = "Never"; value = 0; }
  ];
  service = id: path: label: extra: {
    inherit id path label;
    page = "services";
    control = "switch";
    tier = "rebuild";
  } // extra;
in
[
  # --- About This Computer ---
  {
    id = "timeZone";
    path = [ "time" "timeZone" ];
    page = "about";
    label = "Time zone";
    control = "timezone";
    tier = "rebuild";
  }

  # --- Services ---
  (service "tailscale" [ "services" "tailscale" "enable" ] "Tailscale" { unit = "tailscaled.service"; })
  (service "openssh" [ "services" "openssh" "enable" ] "SSH server" { unit = "sshd.service"; onDemand = "sshdOnDemand"; })
  (service "sshdOnDemand" [ "amane" "services" "sshd" "onDemand" ] "Only when needed" { })
  (service "avahi" [ "services" "avahi" "enable" ] "Avahi (network discovery)" { unit = "avahi-daemon.service"; onDemand = "avahiOnDemand"; })
  (service "avahiOnDemand" [ "amane" "services" "avahi-daemon" "onDemand" ] "Only when needed" { })
  (service "syncthing" [ "services" "syncthing" "enable" ] "Syncthing" { unit = "syncthing.service"; })
  (service "kdeconnect" [ "programs" "kdeconnect" "enable" ] "KDE Connect" { })
  (service "flatpak" [ "services" "flatpak" "enable" ] "Flatpak" { })
  (service "fprintd" [ "services" "fprintd" "enable" ] "Fingerprint reader" { unit = "fprintd.service"; })
  (service "fwupd" [ "services" "fwupd" "enable" ] "Firmware updates (fwupd)" { unit = "fwupd.service"; })
  (service "bluetooth" [ "hardware" "bluetooth" "enable" ] "Bluetooth" { unit = "bluetooth.service"; })
  (service "sunshine" [ "services" "sunshine" "enable" ] "Sunshine (game streaming)" { unit = "sunshine.service"; scope = "user"; })

  # --- Power & Lock ---
  {
    id = "dimAfter";
    path = [ "amane" "idle" "dimAfter" ];
    page = "power";
    label = "Dim the screen after";
    control = "choice";
    choices = minutes;
    tier = "rebuild";
  }
  {
    id = "lockAfter";
    path = [ "amane" "idle" "lockAfter" ];
    page = "power";
    label = "Lock the screen after";
    control = "choice";
    choices = minutes;
    tier = "rebuild";
  }
  {
    id = "screenOffAfter";
    path = [ "amane" "idle" "screenOffAfter" ];
    page = "power";
    label = "Turn the screen off after";
    control = "choice";
    choices = minutes;
    tier = "rebuild";
  }

  # --- Apps ---
  {
    id = "packages";
    path = [ "amane" "packages" ];
    page = "apps";
    label = "Added in Settings";
    control = "packages";
    tier = "rebuild";
  }

  # --- Storage ---
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
