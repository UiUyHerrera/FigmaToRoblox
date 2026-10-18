# FigmaToRoblox setup: installs everything it can and only asks for what it can't get by itself.
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $root

function Step($n, $text) { Write-Host ""; Write-Host "[$n/6] $text" -ForegroundColor Cyan }
function Ok($text) { Write-Host "  OK  $text" -ForegroundColor Green }
function Info($text) { Write-Host "      $text" -ForegroundColor Gray }
function Ask($text) { Write-Host ""; return (Read-Host "  > $text") }

Clear-Host
Write-Host "FigmaToRoblox setup" -ForegroundColor White
Write-Host "Turns Figma designs into Roblox UI. This takes about 3 minutes." -ForegroundColor Gray

# ---------------------------------------------------------------- 1. Node.js
Step 1 "Node.js"
function Refresh-Path {
  $env:Path = [Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [Environment]::GetEnvironmentVariable("Path", "User")
}
if (Get-Command node -ErrorAction SilentlyContinue) {
  Ok ("Node.js " + (node -v) + " is installed")
} else {
  Info "Node.js is needed to run the FigmaToRoblox server."
  $yes = Ask "Install Node.js now? (Y/n)"
  if ($yes -match '^[nN]') { Write-Host "Install it from https://nodejs.org and run Setup again."; exit 1 }
  if (Get-Command winget -ErrorAction SilentlyContinue) {
    winget install --id OpenJS.NodeJS.LTS -e --accept-source-agreements --accept-package-agreements
    Refresh-Path
  }
  if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
    Info "Could not install it automatically. Opening the download page..."
    Start-Process "https://nodejs.org"
    Write-Host "Install Node.js (LTS), then run Setup again." -ForegroundColor Yellow
    exit 1
  }
  Ok ("Node.js " + (node -v) + " installed")
}

# ---------------------------------------------------------------- 2. Roblox account
Step 2 "Your Roblox account"
$configPath = Join-Path $root "server\config.json"
$config = $null
if (Test-Path $configPath) {
  try { $config = Get-Content $configPath -Raw | ConvertFrom-Json } catch {}
}
if ($config -and $config.apiKey -and $config.apiKey -ne "PASTE_YOUR_API_KEY_HERE" -and $config.userId) {
  Ok "Already set up (User ID $($config.userId)). Delete server\config.json to redo this step."
} else {
  $userId = $null
  while (-not $userId) {
    $name = Ask "Your Roblox username"
    try {
      $body = @{ usernames = @($name); excludeBannedUsers = $true } | ConvertTo-Json
      $res = Invoke-RestMethod -Method Post -Uri "https://users.roblox.com/v1/usernames/users" -ContentType "application/json" -Body $body
      if ($res.data.Count -gt 0) { $userId = $res.data[0].id; Ok "Found $($res.data[0].name) (User ID $userId)" }
      else { Write-Host "  That username was not found, try again." -ForegroundColor Yellow }
    } catch {
      Write-Host "  Couldn't reach Roblox. Type your User ID instead (the number in your profile URL)." -ForegroundColor Yellow
      $userId = Ask "User ID"
    }
  }

  # ------------------------------------------------------------ 3. API key
  Step 3 "Roblox API key (so images upload to your account)"
  Info "A browser tab will open. On that page:"
  Info "  1. Click 'Create API Key'"
  Info "  2. Name: FigmaToRoblox"
  Info "  3. Access Permissions: choose 'Assets', click Add, tick Read and Write"
  Info "  4. Accepted IP Addresses: add 0.0.0.0/0"
  Info "  5. Click 'Save & Generate Key', then 'Copy Key to Clipboard'"
  Read-Host "  Press Enter to open the page"
  Start-Process "https://create.roblox.com/dashboard/credentials"
  $key = ""
  while ($key.Length -lt 20) {
    $secure = Read-Host "  > Paste your API key here (it stays hidden)" -AsSecureString
    $key = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)).Trim()
    if ($key.Length -lt 20) { Write-Host "  That doesn't look like a key, try again." -ForegroundColor Yellow }
  }
  @{ apiKey = $key; userId = [long]$userId } | ConvertTo-Json | Set-Content -Path $configPath -Encoding UTF8
  Ok "Saved to server\config.json (keep this file private)"
}

# ---------------------------------------------------------------- 4. Studio plugin
Step 4 "Roblox Studio plugin"
node roblox-plugin\build.js --install | Out-Null
if ($LASTEXITCODE -ne 0) { Write-Host "Could not install the Studio plugin." -ForegroundColor Red; exit 1 }
Ok "Installed. Restart Roblox Studio and open Plugins -> FigmaToRoblox."

# ---------------------------------------------------------------- 5. Desktop shortcut
Step 5 "Desktop shortcut"
try {
  $shell = New-Object -ComObject WScript.Shell
  $lnk = $shell.CreateShortcut((Join-Path ([Environment]::GetFolderPath("Desktop")) "FigmaToRoblox.lnk"))
  $lnk.TargetPath = Join-Path $root "FigmaToRoblox.bat"
  $lnk.WorkingDirectory = $root
  $lnk.Description = "Start the FigmaToRoblox server"
  $lnk.Save()
  Ok "Created 'FigmaToRoblox' on your desktop. Open it whenever you want to use FigmaToRoblox."
} catch { Info "Could not create the shortcut; use FigmaToRoblox.bat in this folder instead." }

# ---------------------------------------------------------------- 6. Figma (manual)
Step 6 "Figma plugin (one manual step)"
Info "Figma doesn't let programs install plugins, so do this once:"
Info "  1. Open the Figma desktop app and any file"
Info "  2. Menu -> Plugins -> Development -> Import plugin from manifest..."
Info "  3. Pick this file (the folder will open now):"
Write-Host ("      " + (Join-Path $root "figma-plugin\manifest.json")) -ForegroundColor White
Start-Process explorer.exe (Join-Path $root "figma-plugin")

Write-Host ""
Write-Host "All set!" -ForegroundColor Green
$start = Ask "Start the FigmaToRoblox server now? (Y/n)"
if ($start -notmatch '^[nN]') { Start-Process (Join-Path $root "FigmaToRoblox.bat") }
