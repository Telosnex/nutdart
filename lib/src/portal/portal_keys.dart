/// Key names for the portal backend, mapped to XKB keysyms.
///
/// Names are matched without case, and multi-character names also without
/// `_`, `-`, or spaces. The table covers the names of the synchronous nutdart
/// API, X11 keysym names such as `Page_Up` and `BackSpace`, and common aliases
/// such as `ctrl` and `esc`. `cmd`, `super`, `meta`, and `win` map to
/// `Super_L`. A single character maps to its keysym.
library;

const _named = <String, int>{
  // Editing and navigation.
  'return': 0xff0d,
  'enter': 0xff0d,
  'kpenter': 0xff8d,
  'tab': 0xff09,
  'escape': 0xff1b,
  'esc': 0xff1b,
  'backspace': 0xff08,
  'delete': 0xffff,
  'del': 0xffff,
  'insert': 0xff63,
  'ins': 0xff63,
  'home': 0xff50,
  'end': 0xff57,
  'pageup': 0xff55,
  'prior': 0xff55,
  'pagedown': 0xff56,
  'next': 0xff56,
  'left': 0xff51,
  'up': 0xff52,
  'right': 0xff53,
  'down': 0xff54,
  'space': 0x0020,
  'menu': 0xff67,
  'print': 0xff61,
  'printscreen': 0xff61,
  'pause': 0xff13,
  'clear': 0xff0b,
  'capslock': 0xffe5,
  'numlock': 0xff7f,
  'scrolllock': 0xff14,
  // Modifiers.
  'shift': 0xffe1,
  'shiftl': 0xffe1,
  'shiftr': 0xffe2,
  'control': 0xffe3,
  'ctrl': 0xffe3,
  'controll': 0xffe3,
  'ctrll': 0xffe3,
  'controlr': 0xffe4,
  'ctrlr': 0xffe4,
  'alt': 0xffe9,
  'altl': 0xffe9,
  'option': 0xffe9,
  'altr': 0xffea,
  'super': 0xffeb,
  'superl': 0xffeb,
  'cmd': 0xffeb,
  'command': 0xffeb,
  'meta': 0xffeb,
  'win': 0xffeb,
  'windows': 0xffeb,
  'superr': 0xffec,
  // Punctuation names used by xdotool-style key strings.
  'minus': 0x002d,
  'plus': 0x002b,
  'equal': 0x003d,
  'comma': 0x002c,
  'period': 0x002e,
  'slash': 0x002f,
  'backslash': 0x005c,
  'semicolon': 0x003b,
  'apostrophe': 0x0027,
  'grave': 0x0060,
  'bracketleft': 0x005b,
  'bracketright': 0x005d,
  // Media keys.
  'xf86audiomute': 0x1008ff12,
  'xf86audiolowervolume': 0x1008ff11,
  'xf86audioraisevolume': 0x1008ff13,
  'xf86audioplay': 0x1008ff14,
  'xf86audiostop': 0x1008ff15,
  'xf86audioprev': 0x1008ff16,
  'xf86audionext': 0x1008ff17,
};

final _function = RegExp(r'^f([1-9]|1[0-9]|2[0-4])$');

/// The keysym for one character, as used by [PortalComputerUse.type].
int keysymForRune(int rune) => switch (rune) {
  10 => 0xff0d, // Return
  9 => 0xff09, // Tab
  < 0x20 || 0x7f => throw ArgumentError('Unsupported control character'),
  <= 0xff => rune,
  (>= 0xd800 && <= 0xdfff) ||
  > 0x10ffff => throw ArgumentError('Invalid character'),
  _ => 0x01000000 | rune,
};

/// The keysym for a key name. Throws [ArgumentError] for an unknown name.
int portalKeysym(String name) {
  if (name.runes.length == 1) return keysymForRune(name.runes.single);
  final key = name.toLowerCase().replaceAll(RegExp(r'[_\- ]'), '');
  final named = _named[key];
  if (named != null) return named;
  final function = _function.firstMatch(key);
  if (function != null) return 0xffbe + int.parse(function[1]!) - 1;
  throw ArgumentError.value(name, 'name', 'Unknown key name');
}

/// Keysyms for a `+`-separated key combination, such as `ctrl+shift+n`.
/// The last name is the main key. `ctrl++` presses Control and plus.
List<int> parsePortalKeyCombo(String combo) {
  if (combo == '+') return [portalKeysym('+')];
  final parts = combo.endsWith('++')
      ? [...combo.substring(0, combo.length - 2).split('+'), '+']
      : combo.split('+');
  final names = parts.map((part) => part == '+' ? part : part.trim()).toList();
  if (names.any((name) => name.isEmpty)) {
    throw ArgumentError.value(combo, 'combo', 'Empty key name');
  }
  return [for (final name in names) portalKeysym(name)];
}
