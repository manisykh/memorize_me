param(
    [string]$Alias = "upload",
    [string]$KeystoreFile = "upload-keystore.jks"
)

$ErrorActionPreference = "Stop"

$androidDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$keystorePath = Join-Path $androidDir $KeystoreFile
$keyPropertiesPath = Join-Path $androidDir "key.properties"

if (Test-Path -LiteralPath $keystorePath) {
    throw "Keystore already exists: $keystorePath"
}

if (Test-Path -LiteralPath $keyPropertiesPath) {
    throw "key.properties already exists: $keyPropertiesPath"
}

Write-Host "This script creates a local Android upload keystore for Play Console uploads."
Write-Host "Keep the generated .jks file and passwords backed up. They are not committed to Git."
Write-Host ""

$storePasswordSecure = Read-Host "Store password" -AsSecureString
$keyPasswordSecure = Read-Host "Key password" -AsSecureString

$storePasswordPtr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($storePasswordSecure)
$keyPasswordPtr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($keyPasswordSecure)

try {
    $storePassword = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($storePasswordPtr)
    $keyPassword = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($keyPasswordPtr)

    if ([string]::IsNullOrWhiteSpace($storePassword) -or [string]::IsNullOrWhiteSpace($keyPassword)) {
        throw "Passwords cannot be empty."
    }

    keytool `
        -genkeypair `
        -v `
        -keystore $keystorePath `
        -storetype JKS `
        -keyalg RSA `
        -keysize 2048 `
        -validity 10000 `
        -alias $Alias `
        -storepass $storePassword `
        -keypass $keyPassword `
        -dname "CN=Memorize Me, OU=Release, O=Memorize Me, L=Seoul, ST=Seoul, C=KR"

    $storeFileForGradle = "../$KeystoreFile"
    @(
        "storePassword=$storePassword"
        "keyPassword=$keyPassword"
        "keyAlias=$Alias"
        "storeFile=$storeFileForGradle"
    ) | Set-Content -LiteralPath $keyPropertiesPath -Encoding UTF8

    Write-Host ""
    Write-Host "Release signing files created:"
    Write-Host "  $keystorePath"
    Write-Host "  $keyPropertiesPath"
    Write-Host ""
    Write-Host "Back up the keystore and passwords securely before uploading to Play Console."
} finally {
    if ($storePasswordPtr -ne [IntPtr]::Zero) {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($storePasswordPtr)
    }
    if ($keyPasswordPtr -ne [IntPtr]::Zero) {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($keyPasswordPtr)
    }
}
