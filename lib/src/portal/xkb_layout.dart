import 'dart:ffi';

import 'package:dbus/dbus.dart';
import 'package:ffi/ffi.dart';

import '../computer.dart';
import 'portal_keys.dart';

/// One XKB layout, as named by `org.gnome.desktop.input-sources`.
class XkbLayout {
  final String layout;
  final String variant;
  final String options;
  const XkbLayout(this.layout, {this.variant = '', this.options = ''});

  @override
  String toString() => variant.isEmpty ? layout : '$layout+$variant';
}

/// The active GNOME input source, from the desktop Settings portal.
///
/// The Settings portal works in Flatpak and Snap. GNOME stores the active
/// source first in `mru-sources`; older sessions use `sources[current]`.
/// Throws [ComputerActionUnsupported] when the active source is not an XKB
/// layout (for example an IBus input method) or cannot be read.
Future<XkbLayout> readActiveGnomeLayout() async {
  final client = DBusClient.session();
  try {
    final reply =
        await DBusRemoteObject(
              client,
              name: 'org.freedesktop.portal.Desktop',
              path: DBusObjectPath('/org/freedesktop/portal/desktop'),
            )
            .callMethod('org.freedesktop.portal.Settings', 'ReadAll', [
              DBusArray.string(['org.gnome.desktop.input-sources']),
            ], replySignature: DBusSignature('a{sa{sv}}'))
            .timeout(const Duration(seconds: 5));
    final all = reply.returnValues.single.asDict();
    final settings = all[const DBusString('org.gnome.desktop.input-sources')]
        ?.asStringVariantDict();
    if (settings == null) throw StateError('no input-sources settings');
    return activeLayoutFromSettings(settings);
  } on ComputerActionUnsupported {
    rethrow;
  } catch (error) {
    throw ComputerActionUnsupported(
      'type',
      'Cannot read the active keyboard layout ($error). No text was sent.',
    );
  } finally {
    await client.close();
  }
}

/// Pure selection logic, separate for tests.
XkbLayout activeLayoutFromSettings(Map<String, DBusValue> settings) {
  List<(String, String)> sources(String key) =>
      (settings[key]?.asArray() ?? const [])
          .map((v) => v.asStruct())
          .map((s) => (s[0].asString(), s[1].asString()))
          .toList();
  final mru = sources('mru-sources');
  final all = sources('sources');
  final current = settings['current']?.asUint32() ?? 0;
  final (type, id) = mru.isNotEmpty
      ? mru.first
      : all.isNotEmpty
      ? all[current < all.length ? current : 0]
      : ('xkb', 'us');
  if (type != 'xkb') {
    throw ComputerActionUnsupported(
      'type',
      'The active input source is $type:$id, not a keyboard layout. '
          'No text was sent.',
    );
  }
  final plus = id.indexOf('+');
  final options = (settings['xkb-options']?.asStringArray() ?? const []).join(
    ',',
  );
  return plus < 0
      ? XkbLayout(id, options: options)
      : XkbLayout(
          id.substring(0, plus),
          variant: id.substring(plus + 1),
          options: options,
        );
}

final class _RuleNames extends Struct {
  external Pointer<Utf8> rules, model, layout, variant, options;
}

/// Every keysym that [layout] produces on any key and level, plus the
/// keysym that libxkbcommon assigns to each Unicode character.
class XkbKeysyms {
  /// For error messages, such as `us` or `de+nodeadkeys`.
  final String name;
  final Set<int> keysyms;
  final int Function(int rune) utf32ToKeysym;
  const XkbKeysyms(this.name, this.keysyms, this.utf32ToKeysym);
}

/// Keysyms for [text] that [layout] can produce, one per character.
///
/// Tries the Unicode keysym first, then the legacy keysym that
/// libxkbcommon assigns (for example `Greek_OMEGA` for U+03A9), because
/// mutter matches the keysym exactly. Throws [ComputerActionUnsupported]
/// that names every missing character; nothing is sent in that case.
List<int> resolveTypeKeysyms(String text, XkbKeysyms layout) {
  final out = <int>[];
  final missing = <String>{};
  for (final rune in text.runes) {
    final direct = keysymForRune(rune);
    final legacy = layout.utf32ToKeysym(rune);
    if (layout.keysyms.contains(direct)) {
      out.add(direct);
    } else if (legacy != 0 && layout.keysyms.contains(legacy)) {
      out.add(legacy);
    } else {
      missing.add(String.fromCharCode(rune));
    }
  }
  if (missing.isNotEmpty) {
    throw ComputerActionUnsupported(
      'type',
      'These characters are not on the active keyboard layout '
          '(${layout.name}): ${missing.map((c) => '"$c"').join(', ')}. '
          'No text was sent. Type text without them, or ask the user to '
          'switch keyboard layout.',
    );
  }
  return out;
}

/// Reads the active GNOME layout and compiles it.
Future<XkbKeysyms> activeGnomeKeysyms() async =>
    compileXkbLayout(await readActiveGnomeLayout());

XkbKeysyms compileXkbLayout(XkbLayout layout) {
  final lib = DynamicLibrary.open('libxkbcommon.so.0');
  final contextNew = lib
      .lookupFunction<
        Pointer<Void> Function(Int32),
        Pointer<Void> Function(int)
      >('xkb_context_new');
  final contextUnref = lib
      .lookupFunction<
        Void Function(Pointer<Void>),
        void Function(Pointer<Void>)
      >('xkb_context_unref');
  final keymapNew = lib
      .lookupFunction<
        Pointer<Void> Function(Pointer<Void>, Pointer<_RuleNames>, Int32),
        Pointer<Void> Function(Pointer<Void>, Pointer<_RuleNames>, int)
      >('xkb_keymap_new_from_names');
  final keymapUnref = lib
      .lookupFunction<
        Void Function(Pointer<Void>),
        void Function(Pointer<Void>)
      >('xkb_keymap_unref');
  final minKey = lib
      .lookupFunction<
        Uint32 Function(Pointer<Void>),
        int Function(Pointer<Void>)
      >('xkb_keymap_min_keycode');
  final maxKey = lib
      .lookupFunction<
        Uint32 Function(Pointer<Void>),
        int Function(Pointer<Void>)
      >('xkb_keymap_max_keycode');
  final levels = lib
      .lookupFunction<
        Uint32 Function(Pointer<Void>, Uint32, Uint32),
        int Function(Pointer<Void>, int, int)
      >('xkb_keymap_num_levels_for_key');
  final symsByLevel = lib
      .lookupFunction<
        Int32 Function(
          Pointer<Void>,
          Uint32,
          Uint32,
          Uint32,
          Pointer<Pointer<Uint32>>,
        ),
        int Function(Pointer<Void>, int, int, int, Pointer<Pointer<Uint32>>)
      >('xkb_keymap_key_get_syms_by_level');
  final utf32 = lib.lookupFunction<Uint32 Function(Uint32), int Function(int)>(
    'xkb_utf32_to_keysym',
  );

  return using((arena) {
    final names = arena<_RuleNames>();
    names.ref
      ..rules = 'evdev'.toNativeUtf8(allocator: arena)
      ..model = 'pc105'.toNativeUtf8(allocator: arena)
      ..layout = layout.layout.toNativeUtf8(allocator: arena)
      ..variant = layout.variant.toNativeUtf8(allocator: arena)
      ..options = layout.options.toNativeUtf8(allocator: arena);
    final context = contextNew(0);
    if (context == nullptr) throw StateError('xkb_context_new failed');
    try {
      final keymap = keymapNew(context, names, 0);
      if (keymap == nullptr) {
        throw ComputerActionUnsupported(
          'type',
          'Cannot compile keyboard layout $layout. No text was sent.',
        );
      }
      try {
        final found = <int>{};
        final syms = arena<Pointer<Uint32>>();
        for (var key = minKey(keymap); key <= maxKey(keymap); key++) {
          // Layout index 0: the keymap holds only the active layout.
          for (var level = 0; level < levels(keymap, key, 0); level++) {
            final n = symsByLevel(keymap, key, 0, level, syms);
            for (var i = 0; i < n; i++) {
              found.add(syms.value[i]);
            }
          }
        }
        return XkbKeysyms(layout.toString(), found, utf32);
      } finally {
        keymapUnref(keymap);
      }
    } finally {
      contextUnref(context);
    }
  });
}
