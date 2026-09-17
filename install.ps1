# Reflow Toolkit installer for Windows.
#
# Why this exists rather than "download the .exe from Releases": the app is not signed with a
# code signing certificate, so SmartScreen blocks anything the browser downloads. That block
# comes from the Mark-of-the-Web the browser attaches to the file, not from the binary itself,
# and Invoke-WebRequest does not attach it. A terminal install therefore has no warning to
# dismiss, while a browser download has one per machine.

$ErrorActionPreference = 'Stop'

$Repo = 'igc-cloud/reflow-toolkit-releases'
$AppName = 'Reflow Toolkit'

function Fail($message) {
    Write-Host $message -ForegroundColor Red
    exit 1
}

if ([Environment]::Is64BitOperatingSystem -eq $false) {
    Fail 'Reflow Toolkit requires 64-bit Windows.'
}

$temp = Join-Path $env:TEMP ("reflow-toolkit-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $temp | Out-Null

try {
    Write-Host 'Finding the latest release...'
    $release = Invoke-RestMethod "https://api.github.com/repos/$Repo/releases/latest"
    $tag = $release.tag_name
    if (-not $tag) { Fail 'Could not read the latest release. Is the network up?' }

    $version = $tag.TrimStart('v')
    $installer = "Reflow.Toolkit_${version}_x64-setup.exe"
    $base = "https://github.com/$Repo/releases/download/$tag"
    $path = Join-Path $temp $installer

    Write-Host "Downloading $AppName $version..."
    Invoke-WebRequest -Uri "$base/$installer" -OutFile $path -UseBasicParsing

    # SHA256SUMS.txt travels with the release and catches a corrupted or truncated download.
    # It is NOT a defence against a malicious release: it comes from the same place as the
    # binary. The real signature is the minisign one the auto-updater verifies on every
    # update, against the public key baked into the app.
    $sumsPath = Join-Path $temp 'SHA256SUMS.txt'
    try {
        Invoke-WebRequest -Uri "$base/SHA256SUMS.txt" -OutFile $sumsPath -UseBasicParsing
        Write-Host 'Verifying checksum...'
        $line = Select-String -Path $sumsPath -Pattern ([regex]::Escape($installer)) | Select-Object -First 1
        if (-not $line) { Fail "No checksum listed for $installer; nothing was installed." }
        $expected = ($line.Line -split '\s+')[0]
        $actual = (Get-FileHash -Path $path -Algorithm SHA256).Hash
        if ($actual -ne $expected.ToUpper()) {
            Fail 'Checksum mismatch. The download is corrupt or has been tampered with; nothing was installed.'
        }
    } catch [System.Net.WebException] {
        Write-Host 'No checksum file in this release; skipping checksum verification.' -ForegroundColor DarkGray
    }

    # Invoke-WebRequest does not set the Mark-of-the-Web, but a file that arrived by another
    # route might carry one, and a blocked installer fails with an unhelpful message.
    Unblock-File -Path $path -ErrorAction SilentlyContinue

    Get-Process -Name 'Reflow Toolkit' -ErrorAction SilentlyContinue | ForEach-Object {
        Write-Host 'Quitting the running app...'
        $_.CloseMainWindow() | Out-Null
        Start-Sleep -Seconds 2
    }

    Write-Host "Installing $AppName..."
    # /S is NSIS's silent flag: no wizard, no clicks.
    $process = Start-Process -FilePath $path -ArgumentList '/S' -Wait -PassThru
    if ($process.ExitCode -ne 0) {
        Fail "The installer exited with code $($process.ExitCode)."
    }

    Write-Host ''
    Write-Host "$AppName $version installed."
    Write-Host 'Find it in the Start Menu. It updates itself from here on.' -ForegroundColor DarkGray
}
finally {
    Remove-Item -Recurse -Force $temp -ErrorAction SilentlyContinue
}
