import 'dart:io';
import 'package:nutdart/nutdart.dart';

void main() async {
  print('Nutdart Demo Test');
  print('=================\n');

  // Test 1: Get screen size
  print('1. Getting screen size...');
  try {
    final size = Screen.getSize();
    print('   Screen size: ${size.width} x ${size.height}');
  } catch (e) {
    print('   Error getting screen size: $e');
  }

  print('\n2. Getting mouse position...');
  try {
    final position = Mouse.getPosition();
    print('   Mouse position: (${position.x}, ${position.y})');
  } catch (e) {
    print('   Error getting mouse position: $e');
  }

  print('\n3. Moving mouse to center of screen...');
  try {
    final size = Screen.getSize();
    final centerX = size.width ~/ 2;
    final centerY = size.height ~/ 2;
    Mouse.moveTo(centerX, centerY);
    print('   Mouse moved to ($centerX, $centerY)');
    
    // Verify position
    await Future.delayed(Duration(milliseconds: 100));
    final newPosition = Mouse.getPosition();
    print('   Verified position: (${newPosition.x}, ${newPosition.y})');
  } catch (e) {
    print('   Error moving mouse: $e');
  }

  print('\n4. Capturing screenshot...');
  try {
    // Capture with JPEG compression, max dimension 800px
    print('   Calling Screen.capture...');
    final data = Screen.capture(
      maxSmallDimension: 800,
      quality: 85,
    );
    
    if (data != null) {
      print('   Screenshot captured: ${data.length} bytes');
      
      // Save to file
      final file = File('test_screenshot.jpg');
      await file.writeAsBytes(data);
      print('   Screenshot saved to: ${file.absolute.path}');
    } else {
      print('   Screenshot capture returned null');
    }
  } catch (e, stackTrace) {
    print('   Error capturing screenshot: $e');
    print('   Stack trace: $stackTrace');
  }

  print('\n5. Testing keyboard operations...');
  try {
    print('   Note: This will type in the currently focused window!');
    await Future.delayed(Duration(seconds: 2));
    
    // Type some text
    Keyboard.type('Hello from nutdart!');
    print('   Typed: "Hello from nutdart!"');
    
    await Future.delayed(Duration(milliseconds: 500));
    
    // Select all
    Keyboard.selectAll();
    print('   Selected all text');
    
    await Future.delayed(Duration(milliseconds: 500));
    
    // Copy
    Keyboard.copy();
    print('   Copied to clipboard');
  } catch (e) {
    print('   Error with keyboard operations: $e');
  }

  print('\n6. Testing mouse clicks...');
  try {
    // Single click
    Mouse.click();
    print('   Performed single click');
    
    await Future.delayed(Duration(milliseconds: 500));
    
    // Double click
    Mouse.doubleClick();
    print('   Performed double click');
  } catch (e) {
    print('   Error with mouse clicks: $e');
  }

  print('\n7. Testing mouse scroll...');
  try {
    // Scroll down
    Mouse.scrollVertical(-5);
    print('   Scrolled down 5 units');
    
    await Future.delayed(Duration(milliseconds: 500));
    
    // Scroll up
    Mouse.scrollVertical(5);
    print('   Scrolled up 5 units');
  } catch (e) {
    print('   Error with mouse scroll: $e');
  }

  print('\n8. Testing screen region capture...');
  try {
    // Capture a 400x300 region from position (100, 100)
    final regionData = Screen.captureRegion(100, 100, 400, 300,
      maxSmallDimension: 400,
      quality: 90,
    );
    
    if (regionData != null) {
      print('   Region captured: ${regionData.length} bytes');
      
      // Save to file
      final file = File('test_region_screenshot.jpg');
      await file.writeAsBytes(regionData);
      print('   Region screenshot saved to: ${file.absolute.path}');
    } else {
      print('   Region capture returned null');
    }
  } catch (e) {
    print('   Error capturing screen region: $e');
  }

  print('\nDemo complete!');
}