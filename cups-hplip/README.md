# CUPS + HPLIP Print Server (Home Assistant add-on)

CUPS print server for Home Assistant OS, with the pieces the stock CUPS add-ons
are missing:

* **HPLIP + the HP proprietary binary plug-in**, baked into the image at build
  time. Host-based (ZjStream) HP LaserJets — **M1132 / M1136 / P1102 / P1005** —
  have no PCL interpreter in firmware and physically cannot print without
  `lj-<arch>.so`. Because it is installed during the build, it survives add-on
  restarts and Home Assistant updates; `hp-plugin` run by hand inside a
  container does not.
* **Avahi/mDNS**, so iPhones and iPads discover the queue as **AirPrint**.
* `foo2zjs`, `gutenprint` and the standard `openprinting` PPDs for everything else.

## Install (local add-on)

1. Copy this whole folder to `/addons/cups-hplip/` on the Home Assistant host.
   Easiest routes:
   * **Samba share** add-on → the `addons` share → create `cups-hplip`.
   * **Advanced SSH & Web Terminal** add-on → `/addons/` is visible directly.
2. Settings → Add-ons → Add-on Store → ⋮ → **Check for updates**, then reload
   the page. "CUPS + HPLIP Print Server" appears under *Local add-ons*.
3. Install. The first build takes a while on a Pi — it compiles nothing, but it
   pulls ~400 MB of Debian packages and the 11 MB HP plug-in.
4. Start, then open the web UI on `http://<ha-ip>:631`.

## Adding the M1136

1. **Administration -> Add Printer.**
2. Pick the USB entry for the printer. The plain
   `usb://HP/LaserJet%20Professional%20M1136%20MFP?serial=...` is fine - the
   `hp:/usb/...` backend is *not* required (hpcups never parses the URI, and
   the M1136 is a raw-bulk device, not IEEE-1284.4). Use `hp:` only if you
   also want HP Device Manager / scanner pairing.
3. Tick **Share This Printer** - required for AirPrint.
4. Make: **HP**. Model - this exact entry:

   > **HP LaserJet Professional m1136 MFP, hpcups 3.22.10, requires proprietary plugin**

   HP put "requires proprietary plugin" in the driver name itself. Debian does
   not ship per-model .ppd files for hpcups; CUPS generates this PPD on demand
   from `/usr/share/cups/drv/hpcups.drv`, so it appears in the list only once
   `printer-driver-hpcups` is installed.

   Do **not** pick "HP LaserJet Series PCL 4/5" or "PCL 6" - those are CUPS'
   generic `sample.drv` entries and the M1136 has no PCL interpreter at all.
5. Print the CUPS test page.

## If the test page fails

```sh
# in the add-on's Log tab, or via the terminal add-on:
docker exec -it addon_local_cups_hplip bash
lpstat -p -d
tail -50 /share/cups/logs/error_log
ls -l /usr/share/hplip/prnt/plugins/     # lj.so -> lj-arm64.so must exist
```

`hpcups: plugin not found` in the error log means the plug-in layer did not
install — check the build log for the `hplip-*-plugin.run` step.

## Configuration is persistent

`/etc/cups` is a directory-level symlink to `/share/cups/config`, so printers,
PPDs and SSL certs live on the HA share and survive rebuilds. (Directory-level,
not per-file: CUPS rewrites `printers.conf` with an atomic
write-then-rename, which silently replaces a *file* symlink with a real file in
the ephemeral container layer and loses your printer on restart.)

## Print path proven end to end (arm64 build, file device)

A real job was pushed through the full chain — PDF/text -> ghostscript ->
CUPS raster -> hpcups -> ZjStream — with the queue pointed at a file:

    $ lp -d M1136 /usr/share/cups/data/testprint
    $ head -c 40 out.prn
    \033E\033%-12345X@PJL ENTER LANGUAGE=ZJS
    JZJZ...                       # ZjStream magic at offset 35
    $ ls -l out.prn
    -rw------- 1 root root 98151   # real rasterised page data

Control test with the plug-in removed (`mv lj.so lj.so.bak`):

    -rw------- 1 root root 107     # PJL header only, no raster
    $ lpstat -l -p M1136
        Alerts: hplip.plugin-error

**Diagnostic:** if the printer accepts jobs but nothing comes out, run
`lpstat -l -p <queue>`. `hplip.plugin-error` means `lj.so` is missing or its
version disagrees with `/etc/hp/hplip.conf` — check
`/share/cups/hplip-plugin/` and the add-on log.

The only link not verified here is USB transport to the physical printer.

## If an iPhone prints the same document over and over

Symptom: one tap on Print produces job after job, each a few seconds apart,
with distinct job IDs in `page_log` — CUPS is not retrying, the phone is
resubmitting.

Cause: avahi advertising the queue on every interface in the container,
including the `hassio` bridge and each docker `veth`. AirPrint clients try
those `172.30.x.x` addresses, fail, and resubmit the whole job.

Since v1.0.3 the add-on binds avahi to the interface holding the default
route automatically. Override with the `mdns_interface` option (`end0` for
wired, `wlan0` for Wi-Fi) if auto-detection picks the wrong one. Verify with:

    ha addons logs <slug> | grep "avahi: interfaces"
    # want exactly one "Joining mDNS multicast group on interface ..."

To stop a runaway immediately:

    cancel -a -h <ha-ip>:631 <queue>
    cupsdisable -h <ha-ip>:631 <queue>

Then clear the phone's own queue in **Print Center** (App Switcher) before
re-enabling, or it will simply flood again.

### Root cause of the iOS reprint loop (fixed in v1.0.4)

`access_log` shows the signature clearly:

    Create-Job     successful-ok
    Send-Document  successful-ok
    Cancel-Job     client-error-not-found   <- here
    Create-Job     successful-ok            <- resubmits

iOS issues `Cancel-Job` as cleanup once a job completes. With
`PreserveJobHistory No` the job record is destroyed the moment it finishes,
so CUPS answers `client-error-not-found`; iOS treats that as a failed job and
resends the document, forever. Never set `PreserveJobHistory No` on a queue
that serves AirPrint clients - use a timeout (`300`) instead.
