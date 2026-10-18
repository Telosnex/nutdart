import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Linux capture and dimensions tolerate a missing X display', () async {
    final temp = await Directory.systemTemp.createTemp('nutdart-no-display-');
    addTearDown(() => temp.delete(recursive: true));
    final source = File('${temp.path}/probe.c');
    await source.writeAsString(r'''
#include "screen.h"
#include "screengrab.h"
#include "xdisplay.h"
#include <assert.h>
#include <stdlib.h>
Display *XGetMainDisplay(void) { return NULL; }
void showHighlightWindow(int32_t x, int32_t y, int32_t w, int32_t h, long d, float o) {}
MMBitmapRef copyMMBitmapFromDisplayInRect(MMRect rect) {
  // An empty display must never reach capture (XGetImage can abort).
  abort();
}
extern uint8_t *copyBitmapFullJpeg_LINUX(int32_t, int32_t, int32_t, int64_t *);
int main(void) {
  MMSize size = getMainDisplaySize();
  assert(size.width == 0 && size.height == 0);
  assert(!pointVisibleOnMainDisplay(MMPointMake(0, 0)));
  int64_t length = 123;
  assert(copyBitmapFullJpeg_LINUX(800, 1280, 80, &length) == NULL);
  assert(length == 0);
  return 0;
}
''');
    final executable = '${temp.path}/probe';
    final build = await Process.run('cc', [
      '-Isrc',
      source.path,
      'src/linux/screen.c',
      'src/linux/screengrab_jpeg.c',
      'src/MMBitmap.c',
      '-ljpeg',
      '-lm',
      '-o',
      executable,
    ]);
    expect(build.exitCode, 0, reason: '${build.stdout}\n${build.stderr}');
    final run = await Process.run(executable, []);
    expect(run.exitCode, 0, reason: '${run.stdout}\n${run.stderr}');
  }, skip: !Platform.isLinux);
}
