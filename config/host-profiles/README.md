# Host profiles

Per-machine overlay for `config/*.list` files. Optional — when absent, base
lists are used unchanged.

## Layout

```
config/
├─ apt-packages.list             # base (shared across hosts)
├─ snap-packages.list
└─ host-profiles/
   └─ <hostname>/                # one directory per machine
      ├─ apt-packages.list       # overlay: add/remove vs base
      ├─ snap-packages.list
      └─ …
```

## Overlay syntax

Same format as base `.list` files, with one extra rule:

- `pkgname` — adds to effective list (deduplicated against base).
- `-pkgname` — removes from effective list (allows host to opt out).
- `# comment` — ignored.

Example `config/host-profiles/laptop-01/apt-packages.list`:

```
# Add gaming-related packages on this host
steam
lutris
# Remove enterprise-specific packages from base
-remotedesktopmanager
```

## Resolution from phase scripts

```bash
source lib/host_profile.sh
mapfile -t pkgs < <(host_profile_resolve apt-packages.list)
for p in "${pkgs[@]}"; do
    apt_installed "$p" || ...
done
```

When no overlay file exists for the current host, `host_profile_resolve`
returns the base list verbatim (still parsed/cleaned of comments).

## Inspection

```bash
source lib/host_profile.sh && host_profile_describe
# Host overlay: /…/config/host-profiles/laptop-01
#   apt-packages.list: 3 entries
```
