#!/usr/bin/env pwsh
if ("$env:APV_SIGN_KEY" -eq "") {
  Write-Error "APV_SIGN_KEY is not configured." -ErrorAction Stop
} elseif ("$env:APV_NO" -eq "") {
  Write-Error "APV_NO is not configured." -ErrorAction Stop
} elseif (-not (Get-Command planet -ErrorAction SilentlyContinue)) {
  Write-Error "`
The planet command does not exist.
Please install Libplanet.Tools first:
  dotnet tool install --global Libplanet.Tools" `
    -ErrorAction Stop
}

$DefaultUrlBase = "https://download.nine-chronicles.com/v"

if ("$env:APV_MACOS_URL" -eq "") {
  $macOSBinaryUrl = "$DefaultUrlBase$env:APV_NO/macOS.tar.gz"
} else {
  $macOSBinaryUrl = $env:APV_MACOS_URL;
}

if ("$env:APV_WINDOWS_URL" -eq "") {
  $windowsBinaryUrl = "$DefaultUrlBase$env:APV_NO/Windows.zip"
} else {
  $windowsBinaryUrl = $env:APV_WINDOWS_URL;
}

$passphrase = [Guid]::NewGuid().ToString()
$keyId = (
  "$(planet key import --passphrase="$passphrase" "$env:APV_SIGN_KEY")"
).Split(" ")[0]
$apv = "$(`
  planet apv sign `
    --passphrase="$passphrase" `
    --extra macOSBinaryUrl="$macOSBinaryUrl" `
    --extra WindowsBinaryUrl="$windowsBinaryUrl" `
    --extra timestamp="$([DateTimeOffset]::UtcNow.ToString("o"))" `
    "$keyId" `
    "$env:APV_NO" `
)"
Write-Host "$apv"
planet key remove --passphrase="$passphrase" "$keyId"
planet apv analyze "$apv"

$configPath = $MyInvocation.MyCommand.Definition `
  | Split-Path -Parent `
  | Split-Path -Parent `
  | Join-Path -ChildPath "dist" `
  | Join-Path -ChildPath "config.json"

node -e @"
const fs = require('fs');
fs.readFile(process.argv[1], 'utf8', (err, data) => {
  var config = (data || '').trim() ? JSON.parse(data) : {};
  config.AppProtocolVersion = process.argv[2];
  fs.writeFile(
    process.argv[1],
    JSON.stringify(config, null, 2),
    'utf8',
    () => undefined
  );
});
"@ "$configPath" "$apv"