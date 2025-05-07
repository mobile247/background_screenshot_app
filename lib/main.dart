import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:window_manager/window_manager.dart';
import 'package:intl/intl.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();

  // Configure window options
  WindowOptions windowOptions = const WindowOptions(
    size: Size(400, 480),
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.hidden,
    minimumSize: Size(400, 480),
  );

  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Screenshot App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const ScreenshotApp(),
    );
  }
}

class ScreenshotApp extends StatefulWidget {
  const ScreenshotApp({Key? key}) : super(key: key);

  @override
  _ScreenshotAppState createState() => _ScreenshotAppState();
}

class _ScreenshotAppState extends State<ScreenshotApp> with WindowListener {
  Timer? _screenshotTimer;
  bool _isRunning = false;
  int _screenshotInterval = 10; // in minutes
  int _screenshotCount = 0;
  String _savePath = '';
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _initSavePath();

    // Add delay to see if initialization is working
    Future.delayed(Duration(seconds: 2), () {
      print("App initialized successfully");
    });
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    _stopScreenshotTimer();
    super.dispose();
  }

  @override
  void onWindowClose() async {
    bool _isPreventClose = await windowManager.isPreventClose();
    if (_isPreventClose && _isRunning) {
      showDialog(
        context: context,
        builder: (_) {
          return AlertDialog(
            title: Text('Confirm'),
            content: Text(
                'Screenshots are still running. Are you sure you want to exit?'),
            actions: [
              TextButton(
                child: Text('No'),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
              TextButton(
                child: Text('Yes'),
                onPressed: () async {
                  Navigator.of(context).pop();
                  await windowManager.destroy();
                },
              ),
            ],
          );
        },
      );
    } else {
      await windowManager.destroy();
    }
  }

  @override
  void onWindowFocus() {
    setState(() {});
  }

  Future<void> _initSavePath() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final screenshotsDir = Directory('${directory.path}/Screenshots');

      if (!await screenshotsDir.exists()) {
        await screenshotsDir.create(recursive: true);
      }

      setState(() {
        _savePath = screenshotsDir.path;
      });
      print("Save path initialized: $_savePath");
    } catch (e) {
      setState(() {
        _errorMessage = "Error initializing save path: $e";
      });
      print(_errorMessage);
    }
  }

  void _startScreenshotTimer() {
    if (_isRunning) return;

    setState(() {
      _isRunning = true;
    });

    // Take screenshot immediately
    _takeScreenshot();

    // Set up timer to take screenshots at intervals
    _screenshotTimer = Timer.periodic(
        Duration(minutes: _screenshotInterval), (_) => _takeScreenshot());

    print("Screenshot timer started");
  }

  void _stopScreenshotTimer() {
    if (_screenshotTimer != null) {
      _screenshotTimer!.cancel();
      _screenshotTimer = null;

      setState(() {
        _isRunning = false;
      });

      print("Screenshot timer stopped");
    }
  }

  Future<void> _takeScreenshot() async {
    try {
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final filename = 'screenshot_$timestamp.png';
      final filePath = '$_savePath/$filename';

      // Use native screenshot method for desktop platforms
      if (Platform.isWindows) {
        // Use a direct bitmap approach instead of SendKeys for Windows
        // This avoids the Snipping Tool popup in Windows 11
        final result = await Process.run('powershell', [
          '-command',
          '''
          Add-Type -AssemblyName System.Windows.Forms,System.Drawing
          
          function Screenshot([Drawing.Rectangle]\$bounds, \$path) {
            \$bmp = New-Object Drawing.Bitmap \$bounds.width, \$bounds.height
            \$graphics = [Drawing.Graphics]::FromImage(\$bmp)
            \$graphics.CopyFromScreen(\$bounds.Location, [Drawing.Point]::Empty, \$bounds.size)
            \$bmp.Save(\$path, [System.Drawing.Imaging.ImageFormat]::Png)
            \$graphics.Dispose()
            \$bmp.Dispose()
          }
          
          # Get the entire screen bounds
          \$totalWidth = 0
          \$totalHeight = 0
          
          # Get all screen dimensions
          \$screens = [System.Windows.Forms.Screen]::AllScreens
          
          foreach (\$screen in \$screens) {
            \$right = \$screen.Bounds.Right
            \$bottom = \$screen.Bounds.Bottom
            
            if (\$right -gt \$totalWidth) {
              \$totalWidth = \$right
            }
            
            if (\$bottom -gt \$totalHeight) {
              \$totalHeight = \$bottom
            }
          }
          
          # Create bounds for the entire virtual screen
          \$bounds = [Drawing.Rectangle]::FromLTRB(0, 0, \$totalWidth, \$totalHeight)
          
          # Take the screenshot
          Screenshot \$bounds "$filePath"
          '''
        ]);

        print("powershell exit code: ${result.exitCode}");
        print("powershell stdout: ${result.stdout}");
        print("powershell stderr: ${result.stderr}");
      } else if (Platform.isMacOS) {
        print("Taking screenshot on macOS to: $filePath");
        // Use additional flags for macOS screencapture
        final result = await Process.run('screencapture', ['-xCS', filePath]);
        print("screencapture exit code: ${result.exitCode}");
        print("screencapture stdout: ${result.stdout}");
        print("screencapture stderr: ${result.stderr}");
      }

      setState(() {
        _screenshotCount++;
      });

      print('Screenshot saved to: $filePath');
    } catch (e) {
      setState(() {
        _errorMessage = "Error taking screenshot: $e";
      });
      print(_errorMessage);
    }
  }

  void _openScreenshotsFolder() async {
    try {
      if (Platform.isWindows) {
        await Process.run('explorer', [_savePath]);
      } else if (Platform.isMacOS) {
        print("Opening folder: $_savePath");
        final result = await Process.run('open', [_savePath]);
        print("open exit code: ${result.exitCode}");
        print("open stdout: ${result.stdout}");
        print("open stderr: ${result.stderr}");
      }
    } catch (e) {
      setState(() {
        _errorMessage = "Error opening folder: $e";
      });
      print(_errorMessage);
    }
  }

  void _updateInterval(int minutes) {
    setState(() {
      _screenshotInterval = minutes;
    });

    if (_isRunning) {
      _stopScreenshotTimer();
      _startScreenshotTimer();
    }
  }

  Future<void> _minimizeWindow() async {
    await windowManager.minimize();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Screenshot App'),
        actions: [
          IconButton(
            icon: const Icon(Icons.folder_open),
            onPressed: _openScreenshotsFolder,
            tooltip: 'Open Screenshots Folder',
          ),
          IconButton(
            icon: const Icon(Icons.minimize),
            onPressed: _minimizeWindow,
            tooltip: 'Minimize Window',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Error message display
            if (_errorMessage.isNotEmpty)
              Card(
                color: Colors.red[100],
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Error:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.red[900],
                        ),
                      ),
                      Text(_errorMessage),
                    ],
                  ),
                ),
              ),

            // Status section
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Status: ${_isRunning ? 'Running' : 'Stopped'}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _isRunning ? Colors.green : Colors.red,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('Screenshots Taken: $_screenshotCount'),
                    const SizedBox(height: 8),
                    Text('Save Location: $_savePath'),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Settings section
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Settings',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text('Screenshot Interval (minutes): $_screenshotInterval'),
                    Slider(
                      value: _screenshotInterval.toDouble(),
                      min: 1,
                      max: 60,
                      divisions: 59,
                      label: _screenshotInterval.toString(),
                      onChanged: (value) => _updateInterval(value.toInt()),
                    ),
                  ],
                ),
              ),
            ),

            const Spacer(),

            // Control buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Start'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(110, 45),
                    backgroundColor: Colors.green,
                  ),
                  onPressed: _isRunning ? null : _startScreenshotTimer,
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.stop),
                  label: const Text('Stop'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(110, 45),
                    backgroundColor: Colors.red,
                  ),
                  onPressed: _isRunning ? _stopScreenshotTimer : null,
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Take Now'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(110, 45),
                  ),
                  onPressed: _takeScreenshot,
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
