param(
  [Parameter(Mandatory = $true)]
  [string]$SourceDirectory,
  [Parameter(Mandatory = $true)]
  [string]$OutputDirectory
)

Add-Type -AssemblyName System.Drawing

$qualityEncoder = [System.Drawing.Imaging.Encoder]::Quality
$jpegCodec = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() |
  Where-Object { $_.MimeType -eq 'image/jpeg' }

function Save-ManualImage {
  param(
    [long]$SourceLength,
    [string]$OutputName,
    [int]$Top = 0,
    [int]$Height = 0
  )

  $sourceItem = Get-ChildItem -LiteralPath $SourceDirectory -File |
    Where-Object { $_.Length -eq $SourceLength } |
    Select-Object -First 1
  if ($null -eq $sourceItem) {
    throw "No source image with length $SourceLength was found."
  }
  $sourcePath = $sourceItem.FullName
  $outputPath = [System.IO.Path]::GetFullPath((Join-Path $OutputDirectory $OutputName))
  $source = [System.Drawing.Image]::FromFile($sourcePath)

  try {
    $cropTop = [Math]::Min([Math]::Max($Top, 0), $source.Height - 1)
    $cropHeight = if ($Height -gt 0) {
      [Math]::Min($Height, $source.Height - $cropTop)
    } else {
      $source.Height - $cropTop
    }

    $bitmap = New-Object System.Drawing.Bitmap($source.Width, $cropHeight)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)

    try {
      $graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
      $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
      $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
      $sourceRect = New-Object System.Drawing.Rectangle(0, $cropTop, $source.Width, $cropHeight)
      $targetRect = New-Object System.Drawing.Rectangle(0, 0, $source.Width, $cropHeight)
      $graphics.DrawImage($source, $targetRect, $sourceRect, [System.Drawing.GraphicsUnit]::Pixel)
    } finally {
      $graphics.Dispose()
    }

    try {
      $encoderParameters = New-Object System.Drawing.Imaging.EncoderParameters(1)
      $encoderParameters.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter($qualityEncoder, 88L)
      $bitmap.Save($outputPath, $jpegCodec, $encoderParameters)
      $encoderParameters.Dispose()
    } finally {
      $bitmap.Dispose()
    }
  } finally {
    $source.Dispose()
  }
}

New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null

$assets = @(
  @{ Length = 1089539; Output = 'onboarding-start.jpg' },
  @{ Length = 1109183; Output = 'onboarding-flashcard.jpg' },
  @{ Length = 1168194; Output = 'onboarding-stats.jpg' },
  @{ Length = 1183042; Output = 'onboarding-finish.jpg' },
  @{ Length = 377311; Output = 'import-entry.jpg'; Top = 0; Height = 1650 },
  @{ Length = 294632; Output = 'drive-picker.jpg' },
  @{ Length = 195087; Output = 'sheet-select.jpg' },
  @{ Length = 368208; Output = 'import-complete.jpg' },
  @{ Length = 676913; Output = 'home-overview.jpg'; Top = 190; Height = 1900 },
  @{ Length = 717483; Output = 'home-counts.jpg'; Top = 190; Height = 1900 },
  @{ Length = 569243; Output = 'flashcard-front.jpg' },
  @{ Length = 564620; Output = 'flashcard-back.jpg' },
  @{ Length = 488823; Output = 'review-home.jpg'; Top = 190; Height = 1750 },
  @{ Length = 275109; Output = 'quiz-multiple-choice.jpg' },
  @{ Length = 288996; Output = 'quiz-spelling.jpg' },
  @{ Length = 189321; Output = 'quiz-feedback.jpg' },
  @{ Length = 287334; Output = 'stats-overview.jpg'; Top = 190; Height = 1800 },
  @{ Length = 472251; Output = 'ai-home.jpg'; Top = 190; Height = 1850 },
  @{ Length = 488981; Output = 'ai-settings.jpg'; Top = 190; Height = 1900 },
  @{ Length = 314655; Output = 'ai-provider.jpg'; Top = 190; Height = 1900 },
  @{ Length = 409737; Output = 'ai-api-key.jpg'; Top = 190; Height = 1900 },
  @{ Length = 688272; Output = 'ai-endpoint.jpg'; Top = 190; Height = 2200 },
  @{ Length = 407481; Output = 'ai-fallback.jpg'; Top = 190; Height = 1900 },
  @{ Length = 497956; Output = 'ai-connect-success.jpg'; Top = 190; Height = 1900 },
  @{ Length = 609420; Output = 'ai-connect-failure.jpg'; Top = 190; Height = 1900 },
  @{ Length = 707973; Output = 'ai-quiz-entry.jpg'; Top = 0; Height = 2350 },
  @{ Length = 374036; Output = 'ai-quiz-options.jpg' },
  @{ Length = 368211; Output = 'ai-generating.jpg' },
  @{ Length = 718868; Output = 'ai-result.jpg'; Top = 0; Height = 2500 },
  @{ Length = 299369; Output = 'pdf-result.jpg' },
  @{ Length = 328904; Output = 'pdf-dialog.jpg' },
  @{ Length = 282896; Output = 'pdf-options.jpg' },
  @{ Length = 768720; Output = 'share-sheet.jpg' },
  @{ Length = 351613; Output = 'eye-comfort.jpg'; Top = 670; Height = 1200 },
  @{ Length = 368067; Output = 'settings-guide.jpg'; Top = 190; Height = 1850 }
)

foreach ($asset in $assets) {
  $parameters = @{
    SourceLength = $asset.Length
    OutputName = $asset.Output
  }
  if ($asset.ContainsKey('Top')) { $parameters.Top = $asset.Top }
  if ($asset.ContainsKey('Height')) { $parameters.Height = $asset.Height }
  Save-ManualImage @parameters
}

Get-ChildItem -LiteralPath $OutputDirectory -File |
  Select-Object Name, Length |
  Sort-Object Name
