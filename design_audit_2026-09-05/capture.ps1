param([Parameter(Mandatory=$true)][string]$Name)
$auditAdb = 'C:\Users\manis\AppData\Local\Android\Sdk\platform-tools\adb.exe'
$auditDevice = 'R3CT20G3VYM'
& $auditAdb -s $auditDevice shell uiautomator dump /sdcard/memorize-audit.xml | Out-Null
& $auditAdb -s $auditDevice pull /sdcard/memorize-audit.xml "$PSScriptRoot/$Name.xml" | Out-Null
& $auditAdb -s $auditDevice shell screencap -p /sdcard/memorize-audit.png
& $auditAdb -s $auditDevice pull /sdcard/memorize-audit.png "$PSScriptRoot/$Name.png" | Out-Null
[xml]$auditXml = Get-Content -Raw "$PSScriptRoot/$Name.xml"
$auditXml.SelectNodes('//node') | Where-Object { $_.'content-desc' -or $_.text } | ForEach-Object {
  [pscustomobject]@{label=($_.'content-desc'+$_.text); bounds=$_.bounds; clickable=$_.clickable; selected=$_.selected}
} | ConvertTo-Json -Compress
