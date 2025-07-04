import 'package:flutter/material.dart';
import 'package:nutdart/nutdart.dart';
import 'dart:typed_data';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String screenInfo = 'Press button to get screen size';
  String mouseInfo = 'Mouse position: unknown';
  Uint8List? screenshotData;
  bool isCapturing = false;

  @override
  void initState() {
    super.initState();
  }

  void _getScreenSize() {
    try {
      final size = Screen.getSize();
      setState(() {
        screenInfo = 'Screen size: ${size.width} x ${size.height}';
      });
    } catch (e) {
      setState(() {
        screenInfo = 'Error getting screen size: $e';
      });
    }
  }

  void _getMousePosition() {
    try {
      final position = Mouse.getPosition();
      setState(() {
        mouseInfo = 'Mouse position: (${position.x}, ${position.y})';
      });
    } catch (e) {
      setState(() {
        mouseInfo = 'Error getting mouse position: $e';
      });
    }
  }

  void _captureScreenshot() async {
    print('Starting screenshot capture...');
    setState(() {
      isCapturing = true;
      screenshotData = null;
    });

    try {
      // Capture with JPEG compression, max dimension 800px for display
      print('Calling Screen.capture...');
      final data = Screen.capture(
        maxSmallDimension: 800,
        quality: 85,
      );
      
      print('Screenshot data received: ${data?.length ?? 0} bytes');
      
      setState(() {
        screenshotData = data;
        isCapturing = false;
      });
    } catch (e, stackTrace) {
      print('Error capturing screenshot: $e');
      print('Stack trace: $stackTrace');
      setState(() {
        isCapturing = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error capturing screenshot: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const textStyle = TextStyle(fontSize: 20);
    const spacerSmall = SizedBox(height: 10);
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Computer Use Demo'),
        ),
        body: SingleChildScrollView(
          child: Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  screenInfo,
                  style: textStyle,
                  textAlign: TextAlign.center,
                ),
                spacerSmall,
                ElevatedButton(
                  onPressed: _getScreenSize,
                  child: const Text('Get Screen Size'),
                ),
                const SizedBox(height: 20),
                Text(
                  mouseInfo,
                  style: textStyle,
                  textAlign: TextAlign.center,
                ),
                spacerSmall,
                ElevatedButton(
                  onPressed: _getMousePosition,
                  child: const Text('Get Mouse Position'),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    // Move mouse to center of screen
                    try {
                      final size = Screen.getSize();
                      Mouse.moveTo(size.width ~/ 2, size.height ~/ 2);
                      setState(() {
                        mouseInfo = 'Mouse moved to center of screen';
                      });
                    } catch (e) {
                      setState(() {
                        mouseInfo = 'Error moving mouse: $e';
                      });
                    }
                  },
                  child: const Text('Move Mouse to Center'),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: isCapturing ? null : _captureScreenshot,
                  child: Text(isCapturing ? 'Capturing...' : 'Take Screenshot'),
                ),
                const SizedBox(height: 20),
                Builder(
                  builder: (context) {
                    return ElevatedButton(
                      onPressed: () {
                        // First test: make sure regular tap works
                        try {
                          Keyboard.tap('a');
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Regular tap("a") worked'),
                            ),
                          );
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Regular tap failed: $e')),
                          );
                        }
                      },
                      child: const Text('Test Regular Tap'),
                    );
                  },
                ),
                const SizedBox(height: 10),
                Builder(
                  builder: (context) {
                    return ElevatedButton(
                      onPressed: () async {
                        // Test tapWithModifiers with empty modifiers (should fall back to regular tap)
                        try {
                          Keyboard.tapWithModifiers('b', []);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'tapWithModifiers with empty modifiers worked',
                              ),
                            ),
                          );
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'tapWithModifiers with empty modifiers failed: $e',
                              ),
                            ),
                          );
                        }
                      },
                      child: const Text('Test Empty Modifiers'),
                    );
                  }
                ),
                const SizedBox(height: 10),
                Builder(
                  builder: (context) {
                    return ElevatedButton(
                      onPressed: () {
                        // Test single modifier
                        try {
                          Keyboard.tapWithModifiers('c', ['cmd']);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Sent Cmd+C (Copy)')),
                          );
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error with Cmd+C: $e')),
                          );
                        }
                      },
                      child: const Text('Test Cmd+C'),
                    );
                  }
                ),
                const SizedBox(height: 10),
                Builder(
                  builder: (context) {
                    return ElevatedButton(
                      onPressed: () {
                        // Test two modifiers
                        try {
                          Keyboard.tapWithModifiers('a', ['cmd', 'shift']);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Sent Cmd+Shift+A')),
                          );
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error with Cmd+Shift+A: $e')),
                          );
                        }
                      },
                      child: const Text('Test Cmd+Shift+A'),
                    );
                  }
                ),
                const SizedBox(height: 10),
                Builder(
                  builder: (context) {
                    return ElevatedButton(
                      onPressed: () {
                        // Test using the convenience copy() method
                        try {
                          Keyboard.copy();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Called Keyboard.copy() successfully'),
                            ),
                          );
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error with copy(): $e')),
                          );
                        }
                      },
                      child: const Text('Test copy() method'),
                    );
                  }
                ),
                const SizedBox(height: 20),
                if (screenshotData != null) ...[
                  const Text(
                    'Screenshot:',
                    style: textStyle,
                  ),
                  const SizedBox(height: 10),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.memory(
                        screenshotData!,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            padding: const EdgeInsets.all(20),
                            child: Text(
                              'Error displaying image: $error',
                              style: const TextStyle(color: Colors.red),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
