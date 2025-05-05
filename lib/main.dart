import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:system_tray/system_tray.dart';
import 'package:window_manager/window_manager.dart';
import 'package:intl/intl.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();

  WindowOptions windowOptions = const WindowOptions(
    size: Size(400, 300),
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.hidden,
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
      title: 'Background Screenshot App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const BackgroundScreenshotApp(),
    );
  }
}

class BackgroundScreenshotApp extends StatefulWidget {
  const BackgroundScreenshotApp({Key? key}) : super(key: key);

  @override
  _BackgroundScreenshotAppState createState() =>
      _BackgroundScreenshotAppState();
}

class _BackgroundScreenshotAppState extends State<BackgroundScreenshotApp>
    with WindowListener {
  final SystemTray _systemTray = SystemTray();
  final AppWindow _appWindow = AppWindow();

  Timer? _screenshotTimer;
  bool _isRunning = false;
  int _screenshotInterval = 10; // in minutes
  int _screenshotCount = 0;
  String _savePath = '';

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _initSystemTray();
    _initSavePath();
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    _stopScreenshotTimer();
    super.dispose();
  }

  @override
  void onWindowClose() async {
    // Hide the window instead of closing it
    await windowManager.hide();
  }

  Future<void> _initSavePath() async {
    final directory = await getApplicationDocumentsDirectory();
    final screenshotsDir = Directory('${directory.path}/Screenshots');

    if (!await screenshotsDir.exists()) {
      await screenshotsDir.create(recursive: true);
    }

    setState(() {
      _savePath = screenshotsDir.path;
    });
  }

  Future<void> _initSystemTray() async {
    String iconPath;

    if (Platform.isWindows) {
      iconPath = 'assets/app_icon.ico';
    } else if (Platform.isMacOS) {
      iconPath = 'assets/app_icon.png';
    } else {
      iconPath = 'assets/app_icon.png';
    }

    await _systemTray.initSystemTray(
      title: "Background Screenshot",
      iconPath: iconPath,
    );

    final Menu menu = Menu();
    await menu.buildFrom([
      MenuItemLabel(
          label: 'Show App',
          onClicked: (_) async {
            await windowManager.show();
          }),
      MenuItemLabel(
          label: 'Start Screenshots',
          onClicked: (_) {
            _startScreenshotTimer();
          }),
      MenuItemLabel(
          label: 'Stop Screenshots',
          onClicked: (_) {
            _stopScreenshotTimer();
          }),
      MenuItemLabel(
          label: 'Open Screenshots Folder',
          onClicked: (_) {
            _openScreenshotsFolder();
          }),
      MenuSeparator(),
      MenuItemLabel(
          label: 'Exit',
          onClicked: (_) async {
            await _systemTray.destroy();
            exit(0);
          }),
    ]);

    await _systemTray.setContextMenu(menu);

    _systemTray.registerSystemTrayEventHandler((eventName) {
      if (eventName == kSystemTrayEventClick) {
        _appWindow.show();
      } else if (eventName == kSystemTrayEventRightClick) {
        _systemTray.popUpContextMenu();
      }
    });
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
  }

  void _stopScreenshotTimer() {
    if (_screenshotTimer != null) {
      _screenshotTimer!.cancel();
      _screenshotTimer = null;

      setState(() {
        _isRunning = false;
      });
    }
  }

  Future<void> _takeScreenshot() async {
    try {
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final filename = 'screenshot_$timestamp.png';
      final filePath = '$_savePath/$filename';

      // Use native screenshot method for desktop platforms
      if (Platform.isWindows) {
        await Process.run('powershell', [
          '-command',
          'Add-Type -AssemblyName System.Windows.Forms; [System.Windows.Forms.SendKeys]::SendWait(\"%{PRTSC}\"); Start-Sleep -Milliseconds 100; \$img = [System.Windows.Forms.Clipboard]::GetImage(); if (\$img -ne \$null) { \$img.Save(\"$filePath\"); }'
        ]);
      } else if (Platform.isMacOS) {
        await Process.run('screencapture', ['-x', filePath]);
      }

      setState(() {
        _screenshotCount++;
      });

      print('Screenshot saved to: $filePath');
    } catch (e) {
      print('Error taking screenshot: $e');
    }
  }

  void _openScreenshotsFolder() async {
    try {
      if (Platform.isWindows) {
        await Process.run('explorer', [_savePath]);
      } else if (Platform.isMacOS) {
        await Process.run('open', [_savePath]);
      }
    } catch (e) {
      print('Error opening screenshots folder: $e');
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Background Screenshot App'),
        actions: [
          IconButton(
            icon: const Icon(Icons.folder_open),
            onPressed: _openScreenshotsFolder,
            tooltip: 'Open Screenshots Folder',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
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
            const SizedBox(height: 20),
            Text('Screenshot Interval (minutes):'),
            Slider(
              value: _screenshotInterval.toDouble(),
              min: 1,
              max: 60,
              divisions: 59,
              label: _screenshotInterval.toString(),
              onChanged: (value) => _updateInterval(value.toInt()),
            ),
            const SizedBox(height: 20),
            Text('Screenshots Taken: $_screenshotCount'),
            const SizedBox(height: 20),
            Text('Save Location: $_savePath'),
            const SizedBox(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Start'),
                  onPressed: _isRunning ? null : _startScreenshotTimer,
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.stop),
                  label: const Text('Stop'),
                  onPressed: _isRunning ? _stopScreenshotTimer : null,
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Take Now'),
                  onPressed: _takeScreenshot,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
