# Automatic Installer, Auto-Update, and Security Optimization

This plan outlines how to automate the installation of dependencies (like Python), implement a seamless auto-update system, and ensure the application is trusted by Windows Security.

## User Review Required

> [!IMPORTANT]
> **Code Signing**: To truly avoid "Unknown Publisher" warnings and virus detection, you MUST purchase a Code Signing Certificate (EV Certificate is recommended). This is a paid service from vendors like Sectigo or DigiCert.
> 
> **Server for Updates**: You need a place to host your update metadata (e.g., GitHub Releases). The current logic uses GitHub API.

## Proposed Changes

### 1. Dependency Management (Python)

We will implement a hybrid approach:
- **Installer Level**: Use Inno Setup to create the installer.
- **App Level**: Add a "Pre-flight Check" to verify environment readiness.

#### [NEW] [setup_script.iss](file:///d:/SUPER%20SKRIPSI%20GANDI/super_sk_manager/windows/installer/setup_script.iss)
A script for Inno Setup that:
- Checks if Python is in the PATH.
- If not, downloads the Python installer and runs it with `/quiet InstallAllUsers=1 PrependPath=1`.
- Bundles the Flutter app and assets.

### 2. Auto-Update System

Integrate the existing `UpdaterService` into the application lifecycle.

#### [MODIFY] [main.dart](file:///d:/SUPER%20SKRIPSI%20GANDI/super_skripsi_manager/lib/main.dart)
- Call `UpdaterService().checkForUpdate()` on app launch.
- If an update is available, show a custom `UpdateDialog`.

#### [NEW] [update_dialog.dart](file:///d:/SUPER%20SKRIPSI%20GANDI/super_skripsi_manager/lib/widgets/update_dialog.dart)
- A Glassmorphism-style dialog showing release notes and a download button.
- Progress indicator for the download process.

### 3. Security and Trust (Virus Detection)

To prevent the application from being detected as a virus:
- **Code Signing**: Sign the `.exe` and the installer with a certificate.
- **App Manifest**: Ensure the `windows/runner/Runner.exe.manifest` is correctly configured with `requestedExecutionLevel`.
- **Packaging**: Prepare for MSIX distribution which is more trusted by Windows.

## Verification Plan

### Automated Tests
- Test the version comparison logic in `UpdaterService`.
- Mock GitHub API response to trigger the update dialog.

### Manual Verification
1. Run the app with a lower version number in `pubspec.yaml` to see the update prompt.
2. Verify that the installer correctly identifies if Python is missing.
3. Test the "One-Click Install" flow in a clean Windows Sandbox environment.
