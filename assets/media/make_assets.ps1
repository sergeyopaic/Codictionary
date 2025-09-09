param(
  [string]$InputDir = "D:\Projects\Codictionary\assets\media",
  [string]$OutDir   = "D:\Projects\Codictionary\assets",
  [int]$BaseW = 120,
  [int]$BaseH = 180,
  [ValidateSet("cover","contain")]
  [string]$Fit = "cover"
)

$magick = Get-Command magick -ErrorAction SilentlyContinue
if (-not $magick) { Write-Error "ImageMagick (magick) не найден в PATH."; exit 1 }

$scales   = @(1,2,3,4)
$scaleDir = @{ 1 = "."; 2 = "2.0x"; 3 = "3.0x"; 4 = "4.0x" }

foreach ($s in $scales) {
  if ($s -ne 1) { New-Item -ItemType Directory -Force -Path (Join-Path $OutDir $scaleDir[$s]) | Out-Null }
}

$files = Get-ChildItem $InputDir -Filter "*_large.png" -File
if ($files.Count -eq 0) { Write-Warning "В $InputDir не найдено *_large.png" }

foreach ($f in $files) {
  $src = $f.FullName
  $name = ($f.BaseName -replace "_large$","") + ".png"

  foreach ($s in $scales) {
    $w = $BaseW * $s
    $h = $BaseH * $s
    $destDir = if ($s -eq 1) { $OutDir } else { Join-Path $OutDir $scaleDir[$s] }
    $dest = Join-Path $destDir $name

    $common = @("-alpha","on","-background","none","-filter","Lanczos","-define","png:color-type=6")

    if ($Fit -eq "cover") {
      & magick "$src" $common -resize ("{0}x{1}^" -f $w,$h) -gravity center -extent ("{0}x{1}" -f $w,$h) "$dest"
    } else {
      & magick "$src" $common -resize ("{0}x{1}"  -f $w,$h) -gravity center -extent ("{0}x{1}" -f $w,$h) "$dest"
    }

    if ($LASTEXITCODE -ne 0) {
      Write-Warning ("FAIL  {0}  ({1}x{2})" -f $dest,$w,$h)
    } else {
      Write-Host   ("OK    {0}  ({1}x{2})" -f $dest,$w,$h)
    }
  }
}
