#!/usr/bin/env python3
"""GTK 4 window with one entry, for the GNOME probe. Prints, flushed:
ACTIVE True|False on activity changes, KEY <keyval> per key press, and
TEXT:<json> after each change to the entry."""
import json, gi
gi.require_version('Gtk', '4.0'); gi.require_version('Gdk', '4.0')
from gi.repository import Gtk, Gdk


def out(s):
    print(s, flush=True)


def activate(app):
    w = Gtk.ApplicationWindow(application=app, title='type-target')
    e = Gtk.Entry(); w.set_child(e)
    e.connect('changed', lambda e: out('TEXT:' + json.dumps(e.get_text())))
    w.connect('notify::is-active', lambda w, _: out(f'ACTIVE {w.is_active()}'))
    k = Gtk.EventControllerKey(); k.set_propagation_phase(Gtk.PropagationPhase.CAPTURE)
    k.connect('key-pressed', lambda c, kv, code, st: out(f'KEY {Gdk.keyval_name(kv)}') or False)
    w.add_controller(k)
    w.present(); e.grab_focus()


app = Gtk.Application(application_id='dev.nutdart.TypeTarget')
app.connect('activate', activate)
app.run([])
