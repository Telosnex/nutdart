#!/usr/bin/env python3
"""Test helper acting as the user in GNOME's Remote Desktop dialog.

  consent_helper.py type|no-interaction|deny

Finds the dialog through AT-SPI. For "type" it turns on "Allow Remote
Interaction" and clicks Share; "no-interaction" clicks Share with the
switch off; "deny" clicks Cancel.

The switch (AdwSwitchRow) has no AT-SPI action, so the helper presses Tab
and Space through mutter's private org.gnome.Mutter.RemoteDesktop API.
That session is created first and kept open for the whole run: a
headless session has no keyboard until one exists, and if the app's
input created it, mutter drops the first key. Only this helper uses that
API; the code under test does not.
"""
import sys, time, gi
gi.require_version('Atspi', '2.0')
from gi.repository import Atspi, Gio, GLib

mode = sys.argv[1]
MUTTER = 'org.gnome.Mutter.RemoteDesktop'
bus = Gio.bus_get_sync(Gio.BusType.SESSION)


def mutter(path, iface, method, args=None):
    return bus.call_sync(MUTTER, path, iface, method, args, None, 0, 5000, None)


def keyboard():
    for _ in range(60):
        try:
            path = mutter('/org/gnome/Mutter/RemoteDesktop', MUTTER, 'CreateSession').unpack()[0]
            mutter(path, MUTTER + '.Session', 'Start')
            return path
        except GLib.Error:
            time.sleep(0.5)
    sys.exit('mutter RemoteDesktop unavailable')


KB = keyboard()  # Must stay open; see the module docstring.


def key(sym):
    for down in (True, False):
        mutter(KB, MUTTER + '.Session', 'NotifyKeyboardKeysym', GLib.Variant('(ub)', (sym, down)))


def walk(node, depth=0):
    if node is None or depth > 40:
        return
    yield node
    for i in range(node.get_child_count()):
        try:
            yield from walk(node.get_child_at_index(i), depth + 1)
        except GLib.Error:
            pass


def find(nodes, roles, name):
    for n in nodes:
        try:
            if n.get_role_name() in roles and (n.get_name() or '').strip() == name:
                return n
        except GLib.Error:
            pass


def press(button):
    a = button.get_action_iface()
    a.do_action(0)


def checked(n):
    return n.get_state_set().contains(Atspi.StateType.CHECKED)


def focused(n):
    return n.get_state_set().contains(Atspi.StateType.FOCUSED)


deadline = time.time() + 90
while time.time() < deadline:
    desktop = Atspi.get_desktop(0)
    nodes = [n for i in range(desktop.get_child_count()) for n in walk(desktop.get_child_at_index(i))]
    share = find(nodes, ('push button', 'button'), 'Share')
    if share is None:
        time.sleep(0.5)
        continue
    switch = find(nodes, ('switch', 'toggle button', 'check box'), 'Allow Remote Interaction')
    print('dialog found; switch', None if switch is None else checked(switch), flush=True)
    if mode == 'deny':
        press(find(nodes, ('push button', 'button'), 'Cancel'))
        print('clicked Cancel', flush=True)
    else:
        want = mode == 'type'
        if switch is not None and checked(switch) != want:
            key(0xff1b)  # Escape: headless GNOME starts in the overview.
            time.sleep(1)
            for _ in range(12):
                if focused(switch):
                    break
                key(0xff09)  # Tab
                time.sleep(0.3)
            if focused(switch):
                key(0x20)  # Space
                time.sleep(0.5)
        print('switch now', None if switch is None else checked(switch), flush=True)
        press(share)
        print('clicked Share', flush=True)
    time.sleep(3600)  # Keep KB open until the run ends.
print('no dialog found', flush=True)
sys.exit(1)
