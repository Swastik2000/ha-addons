# Install — two options, no SSH needed for either

## Option A — GitHub repository (recommended; one-click updates)

1. Create a GitHub repo (public is fine — this add-on contains no proprietary
   HP code; the plug-in is downloaded onto your Pi at first start).
2. Push the contents of this folder to the repo root, so it looks like:
       repository.json
       cups-hplip/config.yaml
       cups-hplip/Dockerfile
       cups-hplip/rootfs/...
3. Edit `repository.json` and put your real GitHub URL in `url`.
4. In Home Assistant: **Settings → Add-ons → Add-on Store → ⋮ → Repositories**
   → paste the repo URL → Add.
5. The add-on appears in the store. **Install**, then **Start**.

**Updating later:** change the files, bump `version:` in `cups-hplip/config.yaml`,
push. Home Assistant shows an **Update** button on the add-on page. No SSH ever.

## Option B — local folder (no GitHub account needed)

1. Install the **Studio Code Server** or **Samba** add-on.
2. Copy the `cups-hplip` folder into `/addons/` (Samba: the `addons` /
   `local_apps` share).
3. **Settings → Add-ons → Add-on Store → ⋮ → Check for updates**, refresh the
   page. It appears under *Local add-ons*.
4. Install → Start.

**Updating later:** edit the files, then use **Rebuild** in the add-on's ⋮ menu.
(Rebuild only works if `version:` is unchanged — if you bumped the version, use
Check for updates → Update instead.)

Requires >2 GB free disk; Supervisor refuses to build otherwise.

## After it starts

Open `http://<home-assistant-ip>:631` → **Administration → Add Printer** →
pick the USB entry → tick **Share This Printer** → Make **HP** → Model:

> HP LaserJet Professional m1136 MFP, hpcups 3.22.10, requires proprietary plugin

Then print the CUPS test page. Your iPhone/iPad will find it under the normal
Print dialog automatically once the queue is shared.

## Verified on a real build (arm64)

    lpinfo -m | grep 1136
      drv:///hpcups.drv/hp-laserjet_professional_m1136_mfp.ppd
      HP LaserJet Professional m1136 MFP, hpcups 3.22.10, requires proprietary plugin

    avahi-browse -art
      URF=V1.4,CP1,W8,PQ3-4,SRGB24,RS300,FN3      <- AirPrint
      mopria-certified=1.3                        <- Android
      pdl=application/pdf,...,image/urf

Image size 307 MB. Runtime footprint is small: cupsd + dbus + avahi only
(no Python, no scanner stack, no hp-systray).

## mDNS / AirPrint notes

Home Assistant OS does **not** run Avahi — it uses systemd-resolved as its mDNS
responder, plus `hassio_multicast` (mdns-repeater). Avahi and systemd-resolved
both set `SO_REUSEADDR` on UDP 5353, so this add-on's Avahi binds without
conflict; you may see a harmless "Detected another IPv4 mDNS stack" warning.

**Never set `disallow-other-stacks=yes`.** systemd-resolved reacts by logging
"Another mDNS responder prohibits binding the socket to the same port. Turning
off mDNS support." and `homeassistant.local` stops resolving host-wide. The
add-on pins it to `no`.

**If the printer does not appear on your iPhone**, set the `mdns_interface`
option to your LAN interface (`end0` for wired, `wlan0` for Wi-Fi) and restart.
Without it Avahi publishes on every docker veth and the hassio bridge too,
which can trigger a `Host name conflict, retrying with <name>-2` loop that
hides the printer.

Other known AirPrint gotchas, already handled:
* the queue **must** be shared and **must** have a PPD — a raw queue gets no
  `URF` record and iOS lists it but cannot print;
* `ReadyPaperSizes A4,Letter` is set, otherwise iOS offers only A3/A4/A5;
* no `/etc/avahi/services` files are needed — CUPS 2.4 registers the
  `_universal` subtype and synthesizes `URF` itself. `airprint-generate.py` is
  obsolete and now causes duplicate entries.

## Still unproven

Everything above was verified on a real arm64 build except the interaction with
the live HA OS mDNS stack, which needs your Pi. There is one open upstream bug
in a comparable add-on where iOS shows the queue as "Printer is offline" while
the CUPS test page works; if you hit that, tell me and set `mdns_interface`
first.
