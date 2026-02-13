# Notification Light App
A simple app that turns on the Camera Indicator light to show any important notifications that you dont want to miss!

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
- To test out if the app is working correctly, you can turn on debug logs from settings.
