#!/usr/bin/env bash
# Fetch the newest ArtCraft releases and regenerate artcraft-sources.json with
# their latest versions + SHA256 hashes. Then run `sudo nixos-rebuild switch`.
#
# Needs: curl, python3, openssl (all in the system config). Uses the public
# GitHub API (unauthenticated: 60 requests/hour, plenty for 4 apps).
set -euo pipefail

apps=(vectorcraft figcraft photocraft designcraft)
dir="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
out="$dir/artcraft-sources.json"
tmp="$(mktemp)"

printf '{\n' > "$tmp"
first=1
for app in "${apps[@]}"; do
  echo "==> $app: querying latest release..." >&2
  json="$(curl -fsSL -H 'Accept: application/vnd.github+json' \
    "https://api.github.com/repos/storytold/$app/releases/latest")"

  # Extract version (tag without leading 'v') and the x86_64 AppImage URL.
  read -r version url < <(printf '%s' "$json" | python3 -c '
import sys, json
d = json.load(sys.stdin)
ver = d["tag_name"].lstrip("v")
asset = next(a for a in d["assets"] if a["name"].endswith("linux-x86_64.AppImage"))
print(ver, asset["browser_download_url"])
')

  echo "    version $version -> hashing..." >&2
  hash="sha256-$(curl -fsSL "$url" | openssl dgst -sha256 -binary | base64 -w0)"

  [ "$first" -eq 1 ] || printf ',\n' >> "$tmp"
  first=0
  printf '  "%s": { "version": "%s", "hash": "%s" }' "$app" "$version" "$hash" >> "$tmp"
done
printf '\n}\n' >> "$tmp"

mv "$tmp" "$out"
echo "Updated $out" >&2
