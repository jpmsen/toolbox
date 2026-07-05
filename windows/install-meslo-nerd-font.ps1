# Installs the MesloLGS NF font (recommended by powerlevel10k) for the current
# Windows user. Run in a normal, non-admin PowerShell window - it only touches
# per-user font storage, no admin rights needed.
#
# After running, set "MesloLGS NF" as the font in Windows Terminal:
# Settings > your WSL profile > Appearance > Font face.

$ErrorActionPreference = "Stop"

$fonts = @(
    "MesloLGS NF Regular.ttf",
    "MesloLGS NF Bold.ttf",
    "MesloLGS NF Italic.ttf",
    "MesloLGS NF Bold Italic.ttf"
)

$destDir = Join-Path $env:LOCALAPPDATA "Microsoft\Windows\Fonts"
New-Item -ItemType Directory -Force -Path $destDir | Out-Null

$fontsRegKey = "HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts"

foreach ($font in $fonts) {
    $url = "https://github.com/romkatv/powerlevel10k-media/raw/master/$([uri]::EscapeDataString($font))"
    $destPath = Join-Path $destDir $font

    Write-Host "Downloading $font..."
    Invoke-WebRequest -Uri $url -OutFile $destPath

    $regName = "$([System.IO.Path]::GetFileNameWithoutExtension($font)) (TrueType)"
    New-ItemProperty -Path $fontsRegKey -Name $regName -Value $font -PropertyType String -Force | Out-Null
}

Write-Host "Done. Restart Windows Terminal, then set the font face to 'MesloLGS NF'."
