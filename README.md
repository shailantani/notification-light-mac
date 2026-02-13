# Notification Light App

A simple app that turns on the Camera Indicator light to show any important notifications that you dont want to miss!

### Features
- **Manual Toggle**: Click the camera button to toggle the green light.
- **Notification Monitoring**: The green light flashes when a selected app sends a notification.

### Images
<img width="916" height="469" alt="Screenshot 2026-02-13 at 3 41 19 PM" src="https://github.com/user-attachments/assets/a80d8f37-c59d-40f2-a27d-393743371a94" />

<img width="907" height="457" alt="Screenshot 2026-02-13 at 3 43 39 PM" src="https://github.com/user-attachments/assets/acc23532-d10f-4ce0-b6ca-57d5bfcf0472" />

### Setup Instructions
1.  **Run the App**:
    - Double-click `NotificationLight.app`.
2.  **Grant Permissions**:
    - **Camera**: Required to turn on the light.
    - **Accessibility**: Required to detect notifications. The app will prompt you or show a button to open System Settings.
3.  **Monitor Notifications**:
    - Click the **(+) Add App** button in the sidebar.
    - Select an app (e.g., `Messages.app`, `Mail.app`, `Slack.app`).
    - Toggle **Enable Monitoring** to ON.
    - When that app sends a notification (banner appears), the green light will flash!

### Troubleshooting
- If the Accessibility permission seems "stuck" (you granted it but the app says otherwise), try restarting the app. If that doesnt work, try removing the app from the Accessibility list in System Settings and adding it again, or restart the app.
- Ensure "Allow Notifications" is ON for the apps you are watching in System Settings > Notifications. The banner must appear for the app to detect it.
- To test out if the app is working correctly, you can turn on debug logs from settings.
- If you get an error while opening the app, try to go to system settings -> Security & Privacy -> Confirm opening the app. (This is because of MacOS's strict notarisation policy. (To avoid all this you can disable gatekeeper too at your own risk)

Inspied by this tweet:
https://x.com/Youkhna/status/2019904966937440264

## License

Droppy is source-available under [GPL-3.0 with Commons Clause](LICENSE).
This license is not OSI open source and restricts selling the software.
