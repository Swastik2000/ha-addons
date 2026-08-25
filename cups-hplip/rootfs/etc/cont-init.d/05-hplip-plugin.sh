#!/usr/bin/with-contenv bash
# ---------------------------------------------------------------------------
# HP's binary plug-in for host-based LaserJets (M1132/M1136/P1102/P1005...).
# These printers have no PCL interpreter; hpcups cannot rasterise for them
# without lj-<arch>.so, and HP ships it only under a proprietary licence.
#
# It is fetched onto THIS machine at first start (exactly what `hp-plugin`
# does) and cached on /share, so the add-on image itself stays free of
# redistributable-restricted binaries and restarts cost no download.
# ---------------------------------------------------------------------------
set -o pipefail

CACHE=/share/cups/hplip-plugin
DEST=/usr/share/hplip/prnt/plugins

# The plug-in version must match the installed hpcups version.
VER=$(dpkg-query -W -f='${Version}' printer-driver-hpcups 2>/dev/null \
        | grep -oE '^[0-9]+\.[0-9]+\.[0-9]+')
[ -n "$VER" ] || VER=3.22.10

case "$(dpkg --print-architecture)" in
    arm64) HPARCH=arm64  ;;
    armhf) HPARCH=arm32  ;;
    amd64) HPARCH=x86_64 ;;
    *) echo "[hplip] unsupported architecture - skipping plug-in"; exit 0 ;;
esac

RUN="hplip-${VER}-plugin.run"
SO="lj-${HPARCH}.so"

mkdir -p "$CACHE" "$DEST" /var/lib/hp

if [ ! -f "$CACHE/$SO" ]; then
    echo "[hplip] fetching HP binary plug-in ${VER} for ${HPARCH} (once; ~11 MB)"
    tmp=$(mktemp -d)
    if curl -fsSL --retry 3 --connect-timeout 20 \
         -o "$tmp/$RUN" \
         "https://www.openprinting.org/download/printdriver/auxfiles/HP/plugins/${RUN}" \
       && sh "$tmp/$RUN" --noexec --keep --target "$tmp/x" >/dev/null 2>&1 \
       && [ -f "$tmp/x/$SO" ]; then
        cp "$tmp/x/$SO" "$CACHE/$SO"
        [ -f "$tmp/x/bb_marvell-${HPARCH}.so" ] \
            && cp "$tmp/x/bb_marvell-${HPARCH}.so" "$CACHE/"
        cp "$tmp/x/license.txt" "$CACHE/HP-plugin-license.txt" 2>/dev/null || true
        echo "[hplip] cached in $CACHE (HP licence: $CACHE/HP-plugin-license.txt)"
    else
        echo "[hplip] WARNING: could not fetch the plug-in."
        echo "[hplip] Host-based HP LaserJets will not print until it is present."
        echo "[hplip] Drop $SO into $CACHE manually and restart the add-on."
    fi
    rm -rf "$tmp"
fi

if [ -f "$CACHE/$SO" ]; then
    install -m 0755 "$CACHE/$SO" "$DEST/$SO"
    ln -sfn "$SO" "$DEST/lj.so"
    if [ -f "$CACHE/bb_marvell-${HPARCH}.so" ]; then
        mkdir -p /usr/share/hplip/scan/plugins
        install -m 0755 "$CACHE/bb_marvell-${HPARCH}.so" /usr/share/hplip/scan/plugins/
        ln -sfn "bb_marvell-${HPARCH}.so" /usr/share/hplip/scan/plugins/bb_marvell.so
    fi
    printf '[plugin]\ninstalled = 1\neula = 1\nversion = %s\n' "$VER" > /var/lib/hp/hplip.state
    echo "[hplip] plug-in active: $DEST/lj.so -> $SO"
fi
exit 0
