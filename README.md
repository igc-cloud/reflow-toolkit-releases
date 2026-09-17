# Reflow Toolkit

Installers and the update manifest for **Reflow Toolkit**, the desktop app for restoring the
local `reflow.app` database and impersonating users.

This repository holds binaries only. The source lives in the private `reflow.toolkit`
repository, and CI publishes releases here so the app can reach them without a credential.

## Install

**macOS**

```sh
curl -fsSL https://raw.githubusercontent.com/igc-cloud/reflow-toolkit-releases/main/install.sh | sh
```

**Windows** (PowerShell)

```powershell
irm https://raw.githubusercontent.com/igc-cloud/reflow-toolkit-releases/main/install.ps1 | iex
```

That is the whole setup. No Node, no Rust, no clone.

You only ever run this once: the app updates itself afterwards.

## Why a command instead of downloading the installer

The app is not signed with an Apple Developer ID or a Windows code signing certificate. Both
operating systems refuse software the **browser** downloaded: macOS through Gatekeeper,
Windows through SmartScreen.

That refusal is attached to the download, not to the program. macOS marks browser downloads
with a `com.apple.quarantine` extended attribute; Windows marks them with the Mark-of-the-Web.
`curl` and `Invoke-WebRequest` attach neither, so a terminal install has nothing to dismiss.

If you would rather download by hand, the installers are on the
[releases page](https://github.com/igc-cloud/reflow-toolkit-releases/releases) — you will just
have to clear the warning once:

- **macOS:** System Settings, Privacy and Security, "Open Anyway" after the first attempt.
- **Windows:** "More info", then "Run anyway".

## What the installer verifies

Every release carries `SHA256SUMS.txt`, and the installers check the file they downloaded
against it. That catches a corrupted or truncated download.

It is **not** protection against a malicious release: the checksum file travels from the same
place as the binary, so anything able to tamper with one could tamper with both.

The real signature is minisign, and it is what the auto-updater verifies against a public key
compiled into the app — so every update after the first install is cryptographically checked.
On macOS the installer also verifies that signature when `minisign` is available
(`brew install minisign`), and says so when it is not, rather than implying the checksum is
equivalent.

## Updates

The app checks this repository for new releases and installs them silently. Signature
verification uses minisign, which is independent of operating system code signing — which is
why updates need no certificate even though the first install shows a warning.

## Reporting a problem

Issues belong in the private `reflow.toolkit` repository, with the code. This repository is
for distribution only.
