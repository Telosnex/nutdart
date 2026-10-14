import 'dart:ffi';

import 'package:ffi/ffi.dart';

/// GTK fixture for portal_loop_probe.dart. The synchronous GLib loop keeps
/// every GTK call on one OS thread. An async Dart timer can migrate threads.
/// The controller launches this process with GSK_RENDERER=cairo.
void main() {
  final gtk = DynamicLibrary.open('libgtk-4.so.1');
  final glib = DynamicLibrary.open('libglib-2.0.so.0');
  final object = DynamicLibrary.open('libgobject-2.0.so.0');
  final write = DynamicLibrary.open('libc.so.6')
      .lookupFunction<
        IntPtr Function(Int32, Pointer<Void>, UintPtr),
        int Function(int, Pointer<Void>, int)
      >('write');
  void text(String value, void Function(Pointer<Utf8>) call) {
    final p = value.toNativeUtf8();
    try {
      call(p);
    } finally {
      calloc.free(p);
    }
  }

  gtk.lookupFunction<Void Function(), void Function()>('gtk_init')();
  final window = gtk
      .lookupFunction<Pointer<Void> Function(), Pointer<Void> Function()>(
        'gtk_window_new',
      )();
  final button = gtk
      .lookupFunction<Pointer<Void> Function(), Pointer<Void> Function()>(
        'gtk_button_new',
      )();
  final setTitle = gtk
      .lookupFunction<
        Void Function(Pointer<Void>, Pointer<Utf8>),
        void Function(Pointer<Void>, Pointer<Utf8>)
      >('gtk_window_set_title');
  text('nutdart controlled input test', (p) => setTitle(window, p));
  final provider = gtk
      .lookupFunction<Pointer<Void> Function(), Pointer<Void> Function()>(
        'gtk_css_provider_new',
      )();
  final load = gtk
      .lookupFunction<
        Void Function(Pointer<Void>, Pointer<Utf8>, IntPtr),
        void Function(Pointer<Void>, Pointer<Utf8>, int)
      >('gtk_css_provider_load_from_data');
  text(
    'button.red { background: #b40000; background-image: none; border-radius: 0; } button.green { background: #00b400; background-image: none; border-radius: 0; }',
    (p) => load(provider, p, -1),
  );
  final display = gtk
      .lookupFunction<
        Pointer<Void> Function(Pointer<Void>),
        Pointer<Void> Function(Pointer<Void>)
      >('gtk_widget_get_display')(window);
  gtk.lookupFunction<
    Void Function(Pointer<Void>, Pointer<Void>, Uint32),
    void Function(Pointer<Void>, Pointer<Void>, int)
  >('gtk_style_context_add_provider_for_display')(display, provider, 800);
  object.lookupFunction<
    Void Function(Pointer<Void>),
    void Function(Pointer<Void>)
  >('g_object_unref')(provider);
  final addClass = gtk
      .lookupFunction<
        Void Function(Pointer<Void>, Pointer<Utf8>),
        void Function(Pointer<Void>, Pointer<Utf8>)
      >('gtk_widget_add_css_class');
  final removeClass = gtk
      .lookupFunction<
        Void Function(Pointer<Void>, Pointer<Utf8>),
        void Function(Pointer<Void>, Pointer<Utf8>)
      >('gtk_widget_remove_css_class');
  text('red', (p) => addClass(button, p));
  var clicks = 0, ticks = 0;
  void clicked(Pointer<Void> widget, Pointer<Void> data) {
    clicks++;
    text(clicks.isOdd ? 'red' : 'green', (p) => removeClass(button, p));
    text(clicks.isOdd ? 'green' : 'red', (p) => addClass(button, p));
  }

  final clickedCallback =
      NativeCallable<Void Function(Pointer<Void>, Pointer<Void>)>.isolateLocal(
        clicked,
      );
  final connect = object
      .lookupFunction<
        Uint64 Function(
          Pointer<Void>,
          Pointer<Utf8>,
          Pointer<Void>,
          Pointer<Void>,
          Pointer<Void>,
          Int32,
        ),
        int Function(
          Pointer<Void>,
          Pointer<Utf8>,
          Pointer<Void>,
          Pointer<Void>,
          Pointer<Void>,
          int,
        )
      >('g_signal_connect_data');
  text(
    'clicked',
    (p) => connect(
      button,
      p,
      clickedCallback.nativeFunction.cast(),
      nullptr,
      nullptr,
      0,
    ),
  );
  // Capture keyboard events before the button's own bindings consume them.
  final controller = gtk
      .lookupFunction<Pointer<Void> Function(), Pointer<Void> Function()>(
        'gtk_event_controller_key_new',
      )();
  gtk.lookupFunction<
    Void Function(Pointer<Void>, Int32),
    void Function(Pointer<Void>, int)
  >('gtk_event_controller_set_propagation_phase')(controller, 1);
  void keyEvent(String direction, int value, int code) {
    final event = 'KEY $direction $value $code\n';
    text(event, (p) => write(1, p.cast(), event.length));
  }

  int keyPressed(
    Pointer<Void> controller,
    int value,
    int code,
    int state,
    Pointer<Void> data,
  ) {
    keyEvent('DOWN', value, code);
    return 0;
  }

  void keyReleased(
    Pointer<Void> controller,
    int value,
    int code,
    int state,
    Pointer<Void> data,
  ) {
    keyEvent('UP', value, code);
  }

  final keyDownCallback =
      NativeCallable<
        Int32 Function(Pointer<Void>, Uint32, Uint32, Uint32, Pointer<Void>)
      >.isolateLocal(keyPressed, exceptionalReturn: 0);
  final keyUpCallback =
      NativeCallable<
        Void Function(Pointer<Void>, Uint32, Uint32, Uint32, Pointer<Void>)
      >.isolateLocal(keyReleased);
  text(
    'key-pressed',
    (p) => connect(
      controller,
      p,
      keyDownCallback.nativeFunction.cast(),
      nullptr,
      nullptr,
      0,
    ),
  );
  text(
    'key-released',
    (p) => connect(
      controller,
      p,
      keyUpCallback.nativeFunction.cast(),
      nullptr,
      nullptr,
      0,
    ),
  );
  gtk.lookupFunction<
    Void Function(Pointer<Void>, Pointer<Void>),
    void Function(Pointer<Void>, Pointer<Void>)
  >('gtk_widget_add_controller')(window, controller);
  gtk.lookupFunction<
    Void Function(Pointer<Void>, Pointer<Void>),
    void Function(Pointer<Void>, Pointer<Void>)
  >('gtk_window_set_child')(window, button);
  gtk.lookupFunction<
    Void Function(Pointer<Void>),
    void Function(Pointer<Void>)
  >('gtk_window_fullscreen')(window);
  gtk.lookupFunction<
    Void Function(Pointer<Void>),
    void Function(Pointer<Void>)
  >('gtk_window_present')(window);
  final label = gtk
      .lookupFunction<
        Void Function(Pointer<Void>, Pointer<Utf8>),
        void Function(Pointer<Void>, Pointer<Utf8>)
      >('gtk_button_set_label');
  final active = gtk
      .lookupFunction<
        Int32 Function(Pointer<Void>),
        int Function(Pointer<Void>)
      >('gtk_window_is_active');
  final focused = gtk
      .lookupFunction<
        Int32 Function(Pointer<Void>),
        int Function(Pointer<Void>)
      >('gtk_widget_has_focus');
  int tick(Pointer<Void> data) {
    // Real compositor updates allow timestamp checks even on a static desktop.
    text(
      'nutdart controlled test — ${ticks++} — activations $clicks',
      (p) => label(button, p),
    );
    // Synchronous pipe writes: Dart's async stdout cannot drain during GLib.run.
    final state = 'STATE $clicks ${active(window)} ${focused(button)}\n';
    text(state, (p) => write(1, p.cast(), state.length));
    return 1;
  }

  final tickCallback =
      NativeCallable<Int32 Function(Pointer<Void>)>.isolateLocal(
        tick,
        exceptionalReturn: 0,
      );
  final timer = glib
      .lookupFunction<
        Uint32 Function(Uint32, Pointer<Void>, Pointer<Void>),
        int Function(int, Pointer<Void>, Pointer<Void>)
      >('g_timeout_add')(33, tickCallback.nativeFunction.cast(), nullptr);
  final loop = glib
      .lookupFunction<
        Pointer<Void> Function(Pointer<Void>, Int32),
        Pointer<Void> Function(Pointer<Void>, int)
      >('g_main_loop_new')(nullptr, 0);
  final quit = glib
      .lookupFunction<
        Void Function(Pointer<Void>),
        void Function(Pointer<Void>)
      >('g_main_loop_quit');
  int stop(Pointer<Void> data) {
    quit(loop);
    return 0;
  }

  final stopCallback =
      NativeCallable<Int32 Function(Pointer<Void>)>.isolateLocal(
        stop,
        exceptionalReturn: 0,
      );
  glib.lookupFunction<
    Uint32 Function(Int32, Pointer<Void>, Pointer<Void>),
    int Function(int, Pointer<Void>, Pointer<Void>)
  >('g_unix_signal_add')(15, stopCallback.nativeFunction.cast(), nullptr);
  try {
    glib.lookupFunction<
      Void Function(Pointer<Void>),
      void Function(Pointer<Void>)
    >('g_main_loop_run')(loop);
  } finally {
    glib.lookupFunction<Int32 Function(Uint32), int Function(int)>(
      'g_source_remove',
    )(timer);
    gtk.lookupFunction<
      Void Function(Pointer<Void>),
      void Function(Pointer<Void>)
    >('gtk_window_destroy')(window);
    glib.lookupFunction<
      Void Function(Pointer<Void>),
      void Function(Pointer<Void>)
    >('g_main_loop_unref')(loop);
    tickCallback.close();
    stopCallback.close();
    clickedCallback.close();
    keyDownCallback.close();
    keyUpCallback.close();
  }
}
