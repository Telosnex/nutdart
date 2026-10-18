import 'dart:ffi';

import 'package:ffi/ffi.dart';

import '../computer.dart';
import 'xkb_layout.dart';

final class _RuleNames extends Struct {
  external Pointer<Utf8> rules, model, layout, variant, options;
}

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
