import 'package:dbus/dbus.dart';

import '../computer.dart';
import 'portal_keys.dart';
import 'xkb_compile.dart';

// dart:ffi is unavailable on web, so compiling a layout has a stub there.
export 'xkb_compile.dart';

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
