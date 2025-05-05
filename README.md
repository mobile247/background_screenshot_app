Background Screenshot App
A Flutter desktop application that runs in the background and takes screenshots at regular intervals (default: every 10 minutes). Supports both macOS and Windows.

Features
Run silently in the background
System tray integration for easy access
Configurable screenshot interval
View screenshot count and save location
Manually trigger screenshots
Open screenshots folder directly from the app
Auto-start at system boot (optional)
Setup Instructions
Prerequisites
Install Flutter (version 2.10.0 or higher recommended)
Set up Flutter for desktop development:
For Windows: https://docs.flutter.dev/desktop#windows-setup
For macOS: https://docs.flutter.dev/desktop#macos-setup
Project Setup
Clone or download this repository
Create an assets folder in the project root and add:
app_icon.png - For macOS (recommended size: 512x512px)
app_icon.ico - For Windows (recommend including multiple sizes in the ICO)
Install dependencies:
flutter pub get
Run in debug mode:
flutter run -d windows  # For Windows
flutter run -d macos    # For macOS
Build for Production
To create a standalone executable:

Windows
flutter build windows
The output will be in build\windows\runner\Release\

macOS
flutter build macos
The output will be in build/macos/Build/Products/Release/

How It Works
The application uses platform-specific commands to take screenshots:

On Windows: PowerShell commands with PrintScreen simulation
On macOS: The screencapture command-line utility
Screenshots are saved in the application documents directory under a "Screenshots" folder with timestamps in the filename.

Setting Up Auto-Start (Optional)
Windows
Create a shortcut to the generated .exe file
Press Win+R, type shell:startup, and press Enter
Move the shortcut to this Startup folder
macOS
Go to System Preferences > Users & Groups
Select your user account and click on "Login Items"
Click the "+" button and add your application
Troubleshooting
Permission Issues: On macOS, you may need to grant screen recording permissions to the app. Go to System Preferences > Security & Privacy > Privacy > Screen Recording and add the app.
Missing Dependencies: Run flutter doctor to ensure your environment is correctly set up.
Icon Not Showing: Ensure the icon files are in the assets folder and properly referenced in pubspec.yaml.
Customization
You can modify the source code to:

Change the default screenshot interval
Customize the UI
Add additional features like upload to cloud storage
Implement screenshot preview
Add annotation capabilities
