# Camera Light App

## macOS Version
App: `CameraLight.app` (in this folder)

### Features
- **Manual Toggle**: Click the camera button to toggle the green light.
- **Notification Monitoring**: The green light flashes when a selected app sends a notification.

### Setup Instructions
1.  **Run the App**:
    - Double-click `CameraLight.app`.
2.  **Grant Permissions**:
    - **Camera**: Required to turn on the light.
    - **Accessibility**: Required to detect notifications. The app will prompt you or show a button to open System Settings.
3.  **Monitor Notifications**:
    - Click the **(+) Add App** button in the sidebar.
    - Select an app (e.g., `Messages.app`, `Mail.app`, `Slack.app`).
    - Toggle **Enable Monitoring** to ON.
    - When that app sends a notification (banner appears), the green light will flash!

### Troubleshooting
- If the Accessibility permission seems "stuck" (you granted it but the app says otherwise), try removing the app from the Accessibility list in System Settings and adding it again, or restart the app.
- Ensure "Allow Notifications" is ON for the apps you are watching in System Settings > Notifications. The banner must appear for the app to detect it.

## iOS Version
File: `CameraLightApp.swift`
- Handles toggling the Torch/Flash on iPhone.
