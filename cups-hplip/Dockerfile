FROM ghcr.io/hassio-addons/debian-base:7.6.2

ENV DEBIAN_FRONTEND=noninteractive LANG=C.UTF-8

# Minimal print path for a host-based HP LaserJet:
#   PDF --(ghostscript/gstoraster)--> CUPS raster --(hpcups)--> ZjStream
# printer-driver-hpcups brings the hpcups filter and the HP PPDs; the full
# `hplip` package is deliberately NOT installed (it drags in python3, PyQt
# tooling and the scanner stack we do not need for printing).
RUN apt-get update && apt-get install -y --no-install-recommends \
        cups cups-filters cups-client \
        ghostscript \
        printer-driver-hpcups \
        avahi-daemon libnss-mdns dbus \
        libsane-hpaio sane-utils \
        busybox \
        curl ca-certificates \
    && apt-get purge -y --auto-remove \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
              /usr/share/doc/* /usr/share/man/* /usr/share/locale/* \
              /var/cache/debconf/*-old

# hpcups reads [hplip] version from /etc/hp/hplip.conf and refuses to dlopen
# the binary plug-in if it disagrees with /var/lib/hp/hplip.state. Generate it
# from the installed package version so the two can never drift, rather than
# relying on whichever hplip.conf a dependency happens to ship.
RUN set -eux; \
    VER="$(dpkg-query -W -f='${Version}' printer-driver-hpcups | grep -oE '^[0-9]+\.[0-9]+\.[0-9]+')"; \
    install -d /etc/hp /var/lib/hp /usr/share/hplip/prnt/plugins; \
    printf '[hplip]\nversion=%s\n\n[dirs]\nhome=/usr/share/hplip\nrun=/var/run\nppd=/usr/share/ppd/hplip/HP\nppdbase=/usr/share/ppd/hplip\ncupsbackend=/usr/lib/cups/backend\ncupsfilter=/usr/lib/cups/filter\ndrv=/usr/share/cups/drv\nbin=/usr/bin\n' "$VER" > /etc/hp/hplip.conf; \
    cat /etc/hp/hplip.conf

COPY rootfs /
RUN find /etc/cont-init.d /etc/services.d -type f -exec chmod +x {} \;

EXPOSE 631
HEALTHCHECK CMD lpstat -r || exit 1

LABEL \
    io.hass.name="CUPS + HPLIP Print Server" \
    io.hass.type="addon" \
    io.hass.arch="aarch64|amd64"
