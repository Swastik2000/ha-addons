#!/usr/bin/with-contenv bashio
if [ "$(jq -r '.enable_scanning // false' /data/options.json 2>/dev/null)" != "true" ]; then
    bashio::log.info "scanning: disabled - removing the scan UI service entirely"
    rm -rf /etc/services.d/scanui
    exit 0
fi

rm -f /tmp/scan.* 2>/dev/null || true
rm -rf /tmp/scan.lock 2>/dev/null || true

DIST=/opt/scanui-dist          # pristine, ships with the image
WWW=/share/cups/www            # live, editable, survives updates
STAMP="$WWW/.shipped-sum"

# Fingerprint a tree by path+content so we can tell three cases apart:
# never seeded, seeded and untouched, seeded and edited by the user.
# Bookkeeping files are excluded or the stamp would change its own answer.
sumtree() {
    find "$1" -type f ! -name '.shipped-sum' -printf '%P\n' 2>/dev/null \
      | LC_ALL=C sort \
      | while read -r f; do printf '%s ' "$f"; md5sum "$1/$f" | cut -d' ' -f1; done \
      | md5sum | cut -d' ' -f1
}

# Replace rather than overlay: copying over the top would leave behind files
# that a later release deleted.
seed() { rm -rf "$WWW"; mkdir -p "$WWW"; cp -r "$DIST"/. "$WWW"/; sumtree "$DIST" > "$STAMP"; }

if [ ! -f "$WWW/cgi-bin/scan" ]; then
    seed
    bashio::log.info "scanning: seeded editable UI at $WWW"
else
    dist_sum="$(sumtree "$DIST")"
    live_sum="$(sumtree "$WWW")"
    was_sum="$(cat "$STAMP" 2>/dev/null || echo none)"

    if [ "$live_sum" = "$dist_sum" ]; then
        echo "$dist_sum" > "$STAMP"                  # already current
    elif [ "$live_sum" = "$was_sum" ]; then
        # untouched since we put it there, and the image now ships something
        # newer - the user gains nothing by keeping the old copy.
        seed
        bashio::log.info "scanning: UI was unmodified - refreshed to the version in this update"
    else
        bashio::log.warning "scanning: $WWW has local edits, so the updated UI in this release was NOT installed."
        bashio::log.warning "scanning: to take the new one, delete $WWW and restart (your edits are lost),"
        bashio::log.warning "scanning: or diff yours against the shipped copy in $DIST inside the container."
    fi
fi

chmod -R 755 "$WWW" 2>/dev/null || true
rm -rf /var/www && ln -sfn "$WWW" /var/www
bashio::log.info "scanning: UI served from $WWW (edit there, no rebuild needed)"

grep -qx 'hpaio' /etc/sane.d/dll.conf 2>/dev/null || echo 'hpaio' >> /etc/sane.d/dll.conf

if [ -e /usr/share/hplip/scan/plugins/bb_marvell.so ]; then
    bashio::log.info "scanning: marvell scan plug-in present"
else
    bashio::log.warning "scanning: bb_marvell.so MISSING - the scanner will not be detected"
fi

bashio::log.info "scanning: probing for the scanner..."
timeout 25 scanimage -L 2>&1 | sed 's/^/[scan] /' || true
bashio::log.info "scanning: UI available on http://<ha-ip>:8090"
