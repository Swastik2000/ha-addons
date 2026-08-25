# CUPS + HPLIP Print Server

A CUPS print server for Home Assistant that can drive **host-based HP LaserJets**
— the M1132, M1136, M1212, P1102, P1005 family — which no other CUPS add-on can,
and shares them to iPhone, iPad, Android, Mac, Windows and Linux.

Optional scanning for MFP models, through a scan page that costs 124 kB of RAM.

## Why this add-on exists

Host-based (ZjStream) LaserJets have **no PCL or PostScript interpreter**. The
computer must generate the printer's raw raster language. That needs two things
a normal CUPS install doesn't have:

1. `hpcups` — HPLIP's filter (open source, in Debian)
2. `lj-<arch>.so` — HP's **proprietary plug-in** (not in any distribution)

Without both, the model never appears in the CUPS driver list, and a PPD alone
cannot help — a PPD only *describes* the printer. HP even says so in the
driver's own name:

    HP LaserJet Professional m1136 MFP, hpcups 3.22.10, requires proprietary plugin

This add-on ships `hpcups` and downloads the plug-in onto **your** machine at
first start (exactly what `hp-plugin` does), caching it on `/share` so restarts
and updates never re-download it. The image itself contains no proprietary code.

## Installation

1. **Settings → Add-ons → Add-on Store → ⋮ → Repositories**, add:
   `https://github.com/Swastik2000/ha-addons`
2. Install **CUPS + HPLIP Print Server**.
   The first build takes **15–25 minutes** on a Raspberry Pi — Supervisor
   compiles it locally and downloads ~300 MB of packages. Needs >2 GB free disk.
3. **Uninstall or stop any other CUPS add-on first.** They both bind port 631
   with host networking and cannot run together.
4. Start it, then open `http://<home-assistant-ip>:631`

## Adding your printer

**Administration → Add Printer**

1. Choose your printer under *Local Printers* (e.g.
   `HP LaserJet Professional M1136 MFP (USB)`).
   The plain `usb://` device is fine — the `hp:/usb/...` backend is not required.
2. Tick **Share This Printer** — required for AirPrint.
3. Make: **HP**
4. Model: pick the entry ending **`requires proprietary plugin`**, e.g.
   `HP LaserJet Professional m1136 MFP, hpcups 3.22.10, requires proprietary plugin`

   Do **not** pick "HP LaserJet Series PCL 4/5" or "PCL 6" — those are CUPS'
   generic entries and produce blank or garbage pages on host-based models.
5. **Maintenance → Print Test Page**

## Connecting your devices

Below, `<ha-host>` means `homeassistant.local` (preferred — it survives the Pi
getting a new DHCP address) or your HA IP.

### iPhone / iPad — nothing to set up

AirPrint discovers the printer automatically once the queue is **shared**.
Open anything → Share → **Print** → pick the printer.

CUPS 2.4 advertises the `_universal` DNS-SD subtype and synthesises the `URF`
record iOS requires, so no `.service` files or `airprint-generate` scripts are
needed. If it does not appear, see Troubleshooting.

### Android — nothing to install

Android's built-in **Mopria** print service finds it automatically
(CUPS advertises `mopria-certified=1.3`). Print → select the printer.
If your phone lacks Mopria, install "Mopria Print Service" from Play Store.

### macOS

**System Settings → Printers & Scanners → Add Printer**, *Default* tab, pick the
entry marked **Bonjour Shared**, and set **Use: Auto Select** (it resolves to
AirPrint / IPP Everywhere).

Do **not** choose "Generic PostScript Printer" — it works but adds a pointless
conversion and weaker media handling.

Command line equivalent:

    lpadmin -p HP_M1136 -E \
      -v ipp://<ha-host>:631/printers/<QUEUE_NAME> \
      -m everywhere -D "HP LaserJet (Home Assistant)"

Use the **hostname, not the IP** — the name is re-resolved per job, so a new
DHCP lease can't break printing.

Your Mac installs no HP driver: it sends PDF untouched and the Pi rasterises.

### Windows

**Settings → Bluetooth & devices → Printers → Add device → Add manually →
Select a shared printer by name**:

    http://<ha-host>:631/printers/<QUEUE_NAME>

Driver: **Microsoft IPP Class Driver**.

### Linux

It is discovered automatically by any CUPS desktop. Otherwise add
`ipp://<ha-host>:631/printers/<QUEUE_NAME>` with the *driverless* / IPP
Everywhere option.

## Scanning (MFP models)

Set **`enable_scanning: true`** in the add-on Configuration tab, restart, then
open `http://<ha-host>:8090`.

Pick resolution, mode and format, press **Scan**, and the image appears in the
page — save it like any other image. Works from a phone browser too.

The scanner uses HPLIP's `hpaio` backend plus the `bb_marvell` plug-in, which
the add-on already downloads. Check the add-on log for:

    [scan] device `hpaio:/usb/HP_LaserJet_..._MFP?serial=...' is a Hewlett-Packard ... all-in-one

With `enable_scanning: false` the scan service directory is deleted before s6
starts services, so **no process exists at all** — zero RAM, not even a parked
`sleep`.

### "Application transferred too few scanlines"

`hpaio` advertises a 381 mm scan height for this hardware, but the glass is
only A4 (297 mm). `scanimage` then requests more scanlines than the scanner can
physically deliver and SANE aborts. Fixed in v1.2.3 by constraining the scan
area (`-x 215.9 -y 297` by default); the **Page size** selector exposes A4,
Letter and unconstrained. Choosing "Full glass" reproduces the original error.

## Options

| Option | Default | Meaning |
|---|---|---|
| `enable_airprint` | `true` | Run avahi so iOS/Android discover the printer |
| `mdns_interface` | `""` | Bind avahi to one interface (`end0` wired, `wlan0` Wi-Fi). Empty = all |
| `enable_scanning` | `false` | Install the scan UI on port 8090 |

## Resource usage

Measured on a Raspberry Pi 4 (aarch64):

| | |
|---|---|
| Add-on RAM, printing only | **6.6 MB** |
| Scan UI running | **+124 kB** |
| During a scan | +8–15 MB, transient |
| Scanning disabled | 0 — the service is never created |
| Image on disk | ~330 MB |

No Python, no Node, no scanner GUI stack: `cupsd` + `dbus` + `avahi`, plus
`busybox httpd` when scanning is on.

## Updates

The add-on has an **Auto update** toggle. Leave it **off** if you'd rather not
have a 15–25 minute rebuild start unannounced on a Pi.

Every release also re-runs `apt-get upgrade` in a small final layer, so updating
the add-on pulls current Debian security patches for CUPS, ghostscript and
hpcups. Without that the cached apt layer would freeze those packages forever.

## Troubleshooting

**The printer prints the same document over and over (iPhone)**
Fixed in v1.0.4. AirPrint sends `Cancel-Job` as cleanup after a job; if CUPS has
already discarded the record it answers `client-error-not-found`, iOS treats it
as failure and resubmits. Never set `PreserveJobHistory No`.
Stop a runaway with:

    cancel -a -h <ha-host>:631 <QUEUE>
    cupsdisable -h <ha-host>:631 <QUEUE>

then clear the phone's own queue in **Print Center** (App Switcher) before
re-enabling.

**Add-on says "Running" but port 631 is dead**
`cupsd` exits *before* opening any log if its config is rejected, so the log is
silent. Both causes are fixed, but if you see it:
`cups-files.conf` must not be group/world writable (CUPS security check), and
must not contain unknown directives — inheriting one from another CUPS add-on
on `/share` is the usual cause. Diagnose with `cupsd -t`.

**Jobs show "Withheld" / "Unknown"**
Fixed in v1.1.1 — CUPS hides job owner and name from non-owners, and
`DefaultAuthType None` makes everyone anonymous.

**"Pages" count is higher than what printed**
A 1-page PDF at 3 copies prints 3 sheets but logs 9. `pdftopdf` expands copies
while the `copies` attribute still rides along, so each page reports 3 copies.
Printed output is correct; only accounting is inflated. This is cups-filters
behaviour.

**Nothing prints, queue shows `hplip.plugin-error`**
The proprietary plug-in is missing or version-mismatched. Check
`/share/cups/hplip-plugin/` and the add-on log. `lpstat -l -p <QUEUE>` tells you
this apart from a USB problem immediately.

**iPhone can't see the printer**
The queue must be **shared** and must have a **PPD** (a raw queue gets no `URF`
record, so iOS lists it but cannot print). If avahi is advertising on many
docker interfaces, set `mdns_interface`.

**Printer sleeps and jobs seem stuck**
Normal. These printers drop off the USB bus when idle and re-enumerate in ~10 s.
The queue's error policy is `retry-job`, so jobs wait and print on wake. CUPS
retries every 30 s, 5 times.
