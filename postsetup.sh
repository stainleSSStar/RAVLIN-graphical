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

# Make sure the display manager and audio/session services are enabled on
# the live rootfs. build.sh also passes them via mklive -S; doing it here
# too keeps the service set correct even if mklive's default set changes,
# and void-installer's local install copies /var/service to the disk.
for svc in dbus elogind sddm pipewire wireplumber; do
    if [ -d "$ROOTFS/etc/sv/$svc" ]; then
        mkdir -p "$ROOTFS/var/service"
        ln -sf "/etc/sv/$svc" "$ROOTFS/var/service/$svc"
        echo "ravlin-graphical: enabled service $svc"
    fi
done

echo "ravlin-graphical: postsetup done"
