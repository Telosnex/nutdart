#!/bin/bash
# Run one portal probe scenario against a headless GNOME session, with a
# test helper acting as the user in the consent dialog.
#
#   tool/ci/gnome/run.sh <scenario>
#
# Scenarios: type (approve, then type), no-interaction (approve with
# "Allow Remote Interaction" off), deny (Cancel). Exits non-zero when the
# probe fails. Logs go to $LOG_DIR (default /tmp/nutdart-gnome-ci).
# Needs: gnome-shell, xdg-desktop-portal(-gnome), pipewire, wireplumber,
# dbus, at-spi2-core, python3-gi with Gtk 4 and Atspi.
set -u
scenario=${1:?scenario}
here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../../.." && pwd)
export LOG_DIR=${LOG_DIR:-/tmp/nutdart-gnome-ci}
mkdir -p "$LOG_DIR"
exec dbus-run-session -- bash "$here/session.sh" "$scenario" "$root"
