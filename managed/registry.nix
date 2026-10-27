# The settings Shell Settings may own: one entry per setting, with its NixOS
# option path. `id` is its key in settings.json; `page` is the Settings page
# that shows it (about, general, services, power, apps, storage, update);
# `control` is how:
#   switch                a boolean
#   int (min, max)        a slider over the range
#   choice (choices)      one of `choices = [ { label; value; } … ]`
#   timezone / text       a field; `check` names what Settings checks it
#                         against: hostname, xkbLayout, xkbVariant
#   packages              a list of nixpkgs attribute paths (Apps draws it)
# `tier` says when it takes effect (rebuild, restart). A service entry may
# name its systemd `unit` (and `scope = "user"` for a user unit) so Settings
# shows whether it's running, and `onDemand`, the id of its "only when
# needed" switch. modules/managed.nix turns each into an option definition,
# and the flake's `amaneSettings` output gives Settings the same list with
# each option's value, type, which file sets it and on which line (so
# "Move to Settings" can take a hand-written line over). The amane.* paths
# are declared in modules/options.nix.
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
  # languages the General page offers; glibc knows many more, and a hand
  # edit of settings.json may name any of them
  locale = label: code: { inherit label; value = "${code}.UTF-8"; };
  locales = [
    (locale "English (United States)" "en_US")
    (locale "English (United Kingdom)" "en_GB")
    (locale "English (Australia)" "en_AU")
    (locale "English (Canada)" "en_CA")
    (locale "Norsk bokmål" "nb_NO")
    (locale "Norsk nynorsk" "nn_NO")
    (locale "Svenska" "sv_SE")
    (locale "Dansk" "da_DK")
    (locale "Suomi" "fi_FI")
    (locale "Íslenska" "is_IS")
    (locale "Deutsch" "de_DE")
    (locale "Nederlands" "nl_NL")
    (locale "Français" "fr_FR")
    (locale "Español" "es_ES")
    (locale "Italiano" "it_IT")
    (locale "Português (Brasil)" "pt_BR")
    (locale "Português (Portugal)" "pt_PT")
    (locale "Polski" "pl_PL")
    (locale "Čeština" "cs_CZ")
    (locale "Русский" "ru_RU")
    (locale "Українська" "uk_UA")
    (locale "Türkçe" "tr_TR")
    (locale "日本語" "ja_JP")
    (locale "中文（简体）" "zh_CN")
    (locale "中文（繁體）" "zh_TW")
    (locale "한국어" "ko_KR")
    { label = "None (C.UTF-8)"; value = "C.UTF-8"; }
  ];
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

  # --- General ---
  {
    id = "hostName";
    path = [ "networking" "hostName" ];
    page = "general";
    label = "Computer name";
    control = "text";
    check = "hostname";
    tier = "rebuild";
  }
  {
    id = "locale";
    path = [ "i18n" "defaultLocale" ];
    page = "general";
    label = "Language";
    control = "choice";
    choices = locales;
    tier = "restart";
  }
  {
    id = "keyboardLayout";
    path = [ "services" "xserver" "xkb" "layout" ];
    page = "general";
    label = "Keyboard layout";
    control = "text";
    check = "xkbLayout";
    tier = "rebuild";
  }
  {
    id = "keyboardVariant";
    path = [ "services" "xserver" "xkb" "variant" ];
    page = "general";
    label = "Keyboard variant";
    control = "text";
    check = "xkbVariant";
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

  # --- Software Update ---
  {
    id = "updateCheck";
    path = [ "amane" "updates" "check" ];
    page = "update";
    label = "Check automatically";
    control = "choice";
    choices = [
      { label = "Daily"; value = "daily"; }
      { label = "Weekly"; value = "weekly"; }
      { label = "Never"; value = "never"; }
    ];
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
