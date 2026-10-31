#!/bin/sh
#
# RAVLIN Graphical postsetup — mklive.sh -x hook.
# Receives the assembled live ROOTFS path as $1, after packages are
# installed and before the initramfs is generated.

set -e

ROOTFS="$1"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# /etc/os-release must be a real file, not the base-files symlink.
# The overlay copy (mklive's cp -P) still follows a symlink at the
# destination, so the RAVLIN Graphical identity would be written through
# the symlink into /usr/lib/os-release — package-owned content that the
# next base-files update overwrites with Void's, silently reverting
# the identity. Remove the symlink and put the real file in its place.
# /etc/xbps.d/49-ravlin-graphical-preserve.conf then keeps xbps from
# removing the type-mismatched regular file on future base-files updates.
echo "ravlin-graphical: /etc/os-release as a real file (identity survives updates)"
rm -f "$ROOTFS/etc/os-release"
install -m 644 "$SCRIPT_DIR/rootfs/etc/os-release" "$ROOTFS/etc/os-release"

# Register fish as a valid login shell. mklive changes the root shell via
# chsh only if it accepts the target, and chsh consults /etc/shells.
echo "ravlin-graphical: registering /usr/bin/fish in /etc/shells"
touch "$ROOTFS/etc/shells"
grep -qx '/usr/bin/fish' "$ROOTFS/etc/shells" || echo '/usr/bin/fish' >> "$ROOTFS/etc/shells"

# Fish as the root shell, on the live image and on any system installed
# from it (void-installer copies the live rootfs). Inside the Plasma
# session the terminal (konsole) still defaults to fish.
echo "ravlin-graphical: setting fish as the root shell"
chroot "$ROOTFS" chsh -s /usr/bin/fish root

# Make sure the graphical/session services are enabled on the live rootfs.
# build.sh also passes them via mklive -S; doing it here too keeps the
# service set correct even if mklive's default set changes, and
# void-installer's local install copies /var/service to the disk.
for svc in dbus elogind sddm; do
    if [ -d "$ROOTFS/etc/sv/$svc" ]; then
        # /var/service is a symlink to /etc/runit/runsvdir/default on Void;
        # mkdir -p on it fails with "File exists", so only create the real
        # target directory if the symlink is missing entirely.
        [ -d "$ROOTFS/var/service" ] || mkdir -p "$ROOTFS/etc/runit/runsvdir/default"
        ln -sf "/etc/sv/$svc" "$ROOTFS/var/service/$svc"
        echo "ravlin-graphical: enabled service $svc"
    fi
done

# PipeWire runs per-user inside the graphical session (SDDM provides the
# D-Bus session and XDG_RUNTIME_DIR). Wire it up system-wide the same way
# void-mklive's mkiso.sh does: XDG autostart entry + pipewire.conf.d snippets
# that launch wireplumber and the PulseAudio compat server, plus the ALSA
# route-to-pipewire configs from alsa-pipewire.
echo "ravlin-graphical: wiring up PipeWire session autostart"
mkdir -p "$ROOTFS/etc/xdg/autostart"
ln -sf /usr/share/applications/pipewire.desktop "$ROOTFS/etc/xdg/autostart/pipewire.desktop"
mkdir -p "$ROOTFS/etc/pipewire/pipewire.conf.d"
ln -sf /usr/share/examples/wireplumber/10-wireplumber.conf "$ROOTFS/etc/pipewire/pipewire.conf.d/10-wireplumber.conf"
ln -sf /usr/share/examples/pipewire/20-pipewire-pulse.conf "$ROOTFS/etc/pipewire/pipewire.conf.d/20-pipewire-pulse.conf"
mkdir -p "$ROOTFS/etc/alsa/conf.d"
ln -sf /usr/share/alsa/alsa.conf.d/50-pipewire.conf "$ROOTFS/etc/alsa/conf.d/50-pipewire.conf"
ln -sf /usr/share/alsa/alsa.conf.d/99-pipewire-default.conf "$ROOTFS/etc/alsa/conf.d/99-pipewire-default.conf"

echo "ravlin-graphical: postsetup done"
