# portfolio_state_management

## Network Diagnostic Dashboard

Activity 03 adds a Provider-backed diagnostic dashboard at **Network Diagnostic Dashboard**.
It runs an idle ping, then measures download bandwidth while pinging concurrently, and
finally measures upload bandwidth while tracking upload ping. The provider repeats the
sequence every minute while the dashboard is open and makes the current tier available
globally to other widgets.

Health tiers use the slower of download/upload bandwidth: **Excellent** (>10 Mbps),
**Fair** (2-10 Mbps), **Poor** (<2 Mbps), and **Degraded** for extreme latency.

For the activity recording, open the dashboard, tap the refresh icon, and capture the
three progress states: idle ping, download plus ping, and upload plus ping. The app uses
Cloudflare Speed Test endpoints, so the device or emulator needs internet access.

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
