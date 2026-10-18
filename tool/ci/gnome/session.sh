#!/bin/bash
# Inside dbus-run-session: start the desktop, the helper, then the probe.
set -u
scenario=$1 root=$2 here=$(cd "$(dirname "$0")" && pwd)
export XDG_RUNTIME_DIR=$(mktemp -d /tmp/nutdart-gnome-run.XXXXXX)
chmod 700 "$XDG_RUNTIME_DIR"
export XDG_CURRENT_DESKTOP=GNOME XDG_SESSION_TYPE=wayland WAYLAND_DISPLAY=wayland-ci
unset DISPLAY
export GTK_A11Y=atspi
cleanup() { kill $(jobs -p) 2>/dev/null; wait 2>/dev/null; rm -rf "$XDG_RUNTIME_DIR"; }
trap cleanup EXIT

pipewire >"$LOG_DIR/pipewire.log" 2>&1 &
sleep 1
wireplumber >"$LOG_DIR/wireplumber.log" 2>&1 &
# --unsafe-mode lets the helper call Shell.Eval (window focus only).
gnome-shell --unsafe-mode --headless --wayland --no-x11 \
  --wayland-display wayland-ci --virtual-monitor 1280x800 \
  >"$LOG_DIR/gnome-shell.log" 2>&1 &
for _ in $(seq 1 60); do [ -S "$XDG_RUNTIME_DIR/wayland-ci" ] && break; sleep 1; done
[ -S "$XDG_RUNTIME_DIR/wayland-ci" ] || { echo "gnome-shell did not start"; tail -30 "$LOG_DIR/gnome-shell.log"; exit 2; }
dbus-update-activation-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE XDG_RUNTIME_DIR GTK_A11Y
/usr/libexec/xdg-desktop-portal-gnome >"$LOG_DIR/xdpg.log" 2>&1 &
sleep 2
/usr/libexec/xdg-desktop-portal -r >"$LOG_DIR/xdp.log" 2>&1 &
for _ in $(seq 1 30); do
  gdbus introspect --session -d org.freedesktop.portal.Desktop \
    -o /org/freedesktop/portal/desktop 2>/dev/null | grep -q portal.RemoteDesktop && break
  sleep 1
done

python3 -u "$here/consent_helper.py" "$scenario" >"$LOG_DIR/helper.log" 2>&1 &

# Act as a user clicking the test window: focus it, leave the overview.
( while sleep 1; do
    gdbus call --session -d org.gnome.Shell -o /org/gnome/Shell -m org.gnome.Shell.Eval \
      "global.display.list_all_windows().filter(w => w.title === 'type-target').forEach(w => w.activate(global.get_current_time())); Main.overview.hide();" \
      >/dev/null 2>&1
  done ) &

cd "$root"
TARGET="$here/type_target.py" SCENARIO="$scenario" \
  timeout 180 dart run tool/ci/gnome/probe.dart
status=$?
echo "--- helper"; cat "$LOG_DIR/helper.log"
exit $status
