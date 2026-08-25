# Home Assistant Add-on Repository

**Add to Home Assistant:** Settings → Add-ons → Add-on Store → ⋮ → **Repositories**
→ paste `https://github.com/Swastik2000/ha-addons`

---

## CUPS + HPLIP Print Server

Turn a Home Assistant box with a USB printer into a network print server for
every device in the house — including **host-based HP LaserJets that no other
CUPS add-on can drive**.

### The problem it solves

The HP LaserJet **M1132 / M1136 / M1212 / P1102 / P1005** family are
*host-based*: they contain **no PCL or PostScript interpreter**. The computer
has to generate the raw ZjStream raster itself, which needs HPLIP's `hpcups`
filter **plus HP's proprietary `lj-<arch>.so` plug-in** that no Linux
distribution ships.

Install a stock CUPS add-on and your model simply never appears in the driver
list — only generic "HP LaserJet Series PCL" entries that produce blank pages.
Supplying a PPD by hand doesn't help either: a PPD only *describes* a printer.

This add-on ships the driver and fetches the plug-in onto your own machine at
first start, so the printer works — and then shares it to everything:

| Device | Setup required |
|---|---|
| iPhone / iPad | **None** — AirPrint discovers it |
| Android | **None** — Mopria discovers it |
| macOS | Pick it from Bonjour, driverless |
| Windows | Add by URL, Microsoft IPP Class Driver |
| Linux | Auto-discovered |

Scanning for MFP models is optional, and the scan page costs **124 kB** of RAM.

### Deliberately small

`cupsd` + `dbus` + `avahi`, and nothing else. No Python, no Node, no scanner
GUI stack. On a Raspberry Pi 4 it idles at **6.6 MB**.

### Verified

Built and tested end to end on Home Assistant OS / Raspberry Pi (aarch64) with a
real HP LaserJet Professional M1136 MFP: driver offered, plug-in loaded, page
printed, AirPrint broadcast confirmed, scanner detected.

📖 **[Full documentation →](cups-hplip/DOCS.md)**

### Credits

The `/etc/cups` persistence approach is adapted from
[arest/cups-addon](https://github.com/arest/cups-addon).
