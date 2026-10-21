param([Parameter(Mandatory = $true)][string]$OutDir)
# Draws the studio art (LED screens, ON AIR sign, floor medallion) as PNGs for 금칙어 게임 Korean.
# No word-bank words on any of them (checked: 금칙어 / KOREAN / ON AIR / TALK / LIVE).
Add-Type -AssemblyName System.Drawing
New-Item -ItemType Directory -Force $OutDir | Out-Null

function New-Canvas([int]$w, [int]$h) {
	$bmp = New-Object System.Drawing.Bitmap $w, $h, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
	$g = [System.Drawing.Graphics]::FromImage($bmp)
	$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
	$g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
	$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
	return @($bmp, $g)
}
function C([int]$a, [int]$r, [int]$gr, [int]$b) { [System.Drawing.Color]::FromArgb($a, $r, $gr, $b) }

# Text with a soft neon glow: wide transparent strokes, then a bright core.
function Draw-GlowText($g, [string]$text, [string]$fontName, [float]$size, [System.Drawing.FontStyle]$style, [float]$cx, [float]$cy, $glow, $core, [float]$spacing = 0) {
	$family = New-Object System.Drawing.FontFamily $fontName
	$path = New-Object System.Drawing.Drawing2D.GraphicsPath
	$fmt = New-Object System.Drawing.StringFormat
	$fmt.Alignment = [System.Drawing.StringAlignment]::Center
	$fmt.LineAlignment = [System.Drawing.StringAlignment]::Center
	if ($spacing -gt 0) { $text = ($text.ToCharArray() -join ([string][char]0x200A * 2)) }
	$path.AddString($text, $family, [int]$style, $size, (New-Object System.Drawing.PointF $cx, $cy), $fmt)
	foreach ($w in @(28, 18, 11, 6)) {
		$alpha = [int](255 * (0.10 + (28 - $w) / 28 * 0.25))
		$pen = New-Object System.Drawing.Pen ((C $alpha $glow.R $glow.G $glow.B)), $w
		$pen.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round
		$g.DrawPath($pen, $path)
		$pen.Dispose()
	}
	$g.FillPath((New-Object System.Drawing.SolidBrush $core), $path)
	$edge = New-Object System.Drawing.Pen ((C 255 $glow.R $glow.G $glow.B)), 2.5
	$g.DrawPath($edge, $path)
	$path.Dispose()
}

function Save-Png($bmp, $g, [string]$name) {
	$g.Dispose()
	$bmp.Save((Join-Path $OutDir $name), [System.Drawing.Imaging.ImageFormat]::Png)
	$bmp.Dispose()
	"saved $name"
}

$magenta = C 255 255 95 140
$cyan = C 255 70 205 220
$gold = C 255 255 200 80

# 1. Logo screen (16:9).
$bmp, $g = New-Canvas 1024 576
$rect = New-Object System.Drawing.Rectangle 0, 0, 1024, 576
$bg = New-Object System.Drawing.Drawing2D.LinearGradientBrush $rect, (C 255 14 20 48), (C 255 52 18 72), 35.0
$g.FillRectangle($bg, $rect)
for ($i = 0; $i -lt 14; $i++) {
	$pen = New-Object System.Drawing.Pen ((C 40 255 255 255)), 2
	$g.DrawEllipse($pen, 512 - 60 * $i, 300 - 34 * $i, 120 * $i, 68 * $i)
	$pen.Dispose()
}
for ($y = 0; $y -lt 576; $y += 4) { $g.FillRectangle((New-Object System.Drawing.SolidBrush (C 28 0 0 0)), 0, $y, 1024, 2) }
# speech bubble with a slash (the "don't say it" mark)
$bubble = New-Object System.Drawing.Drawing2D.GraphicsPath
$bubble.AddEllipse(110, 120, 190, 150)
$bubble.AddPolygon(@((New-Object System.Drawing.PointF 150, 250), (New-Object System.Drawing.PointF 125, 300), (New-Object System.Drawing.PointF 190, 262)))
$g.FillPath((New-Object System.Drawing.SolidBrush (C 255 255 255 255)), $bubble)
$dots = New-Object System.Drawing.SolidBrush (C 255 40 30 70)
foreach ($x in @(160, 205, 250)) { $g.FillEllipse($dots, $x - 12, 183, 24, 24) }
$slash = New-Object System.Drawing.Pen ((C 255 255 50 80)), 18
$slash.StartCap = [System.Drawing.Drawing2D.LineCap]::Round; $slash.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
$g.DrawEllipse($slash, 95, 100, 220, 190)
$g.DrawLine($slash, 130, 265, 280, 125)
Draw-GlowText $g "금칙어" "Malgun Gothic" 170 ([System.Drawing.FontStyle]::Bold) 640 250 $magenta (C 255 255 255 255)
Draw-GlowText $g "KOREAN" "Segoe UI" 64 ([System.Drawing.FontStyle]::Bold) 640 415 $cyan (C 255 235 250 255) 1
$g.FillRectangle((New-Object System.Drawing.SolidBrush $gold), 440, 470, 400, 8)
Save-Png $bmp $g "screen_logo.png"

# 2. Equaliser screen (16:9): TALK / LIVE with level bars.
$bmp, $g = New-Canvas 1024 576
$bg = New-Object System.Drawing.Drawing2D.LinearGradientBrush $rect, (C 255 6 20 50), (C 255 20 6 50), 90.0
$g.FillRectangle($bg, $rect)
$rand = New-Object System.Random 7
for ($i = 0; $i -lt 32; $i++) {
	$h = 60 + $rand.Next(0, 300)
	$x = 40 + $i * 30
	$grad = New-Object System.Drawing.Drawing2D.LinearGradientBrush (New-Object System.Drawing.Rectangle $x, (520 - $h), 20, $h), $cyan, $magenta, 90.0
	for ($y = 520 - $h; $y -lt 520; $y += 14) { $g.FillRectangle($grad, $x, $y, 20, 10) }
}
for ($y = 0; $y -lt 576; $y += 4) { $g.FillRectangle((New-Object System.Drawing.SolidBrush (C 30 0 0 0)), 0, $y, 1024, 2) }
Draw-GlowText $g "TALK" "Segoe UI" 150 ([System.Drawing.FontStyle]::Bold) 512 170 $cyan (C 255 255 255 255) 1
$live = New-Object System.Drawing.SolidBrush (C 255 255 50 80)
$g.FillEllipse($live, 392, 300, 36, 36)
Draw-GlowText $g "LIVE" "Segoe UI" 60 ([System.Drawing.FontStyle]::Bold) 540 318 $magenta (C 255 255 255 255) 1
Save-Png $bmp $g "screen_talk.png"

# 3. ON AIR sign.
$bmp, $g = New-Canvas 512 192
$g.Clear((C 255 120 10 20))
$inner = New-Object System.Drawing.Drawing2D.LinearGradientBrush (New-Object System.Drawing.Rectangle 0, 0, 512, 192), (C 255 255 70 70), (C 255 170 10 30), 90.0
$g.FillRectangle($inner, 10, 10, 492, 172)
Draw-GlowText $g "ON AIR" "Segoe UI" 92 ([System.Drawing.FontStyle]::Bold) 256 98 (C 255 255 230 230) (C 255 255 255 255) 1
Save-Png $bmp $g "onair.png"

# 4. Floor medallion (transparent): rings, ticks and a soft starburst. The centre stays empty (table).
$bmp, $g = New-Canvas 1024 1024
$g.Clear((C 0 0 0 0))
$cx = 512; $cy = 512
for ($k = 0; $k -lt 20; $k++) {
	$a1 = ($k * 18) - 4; $a2 = 8
	$ray = New-Object System.Drawing.Drawing2D.GraphicsPath
	$ray.AddPie(12, 12, 1000, 1000, $a1, $a2)
	$col = if ($k % 2 -eq 0) { C 34 255 95 140 } else { C 34 70 205 220 }
	$g.FillPath((New-Object System.Drawing.SolidBrush $col), $ray)
}
$g.FillEllipse((New-Object System.Drawing.SolidBrush (C 255 0 0 0)), $cx - 150, $cy - 150, 300, 300)
$g.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceCopy
$g.FillEllipse((New-Object System.Drawing.SolidBrush (C 0 0 0 0)), $cx - 150, $cy - 150, 300, 300)
$g.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceOver
foreach ($ring in @(@(170, 6, $gold), @(260, 3, $cyan), @(420, 4, $magenta), @(500, 8, $cyan))) {
	$r = $ring[0]; $w = $ring[1]; $col = $ring[2]
	$pen = New-Object System.Drawing.Pen ((C 200 $col.R $col.G $col.B)), $w
	$g.DrawEllipse($pen, $cx - $r, $cy - $r, 2 * $r, 2 * $r)
	$pen.Dispose()
}
for ($k = 0; $k -lt 60; $k++) {
	$ang = $k * 6 * [math]::PI / 180
	$len = if ($k % 5 -eq 0) { 34 } else { 14 }
	$pen = New-Object System.Drawing.Pen ((C 170 255 255 255)), 3
	$g.DrawLine($pen, [float]($cx + [math]::Cos($ang) * 470), [float]($cy + [math]::Sin($ang) * 470), [float]($cx + [math]::Cos($ang) * (470 - $len)), [float]($cy + [math]::Sin($ang) * (470 - $len)))
	$pen.Dispose()
}
Save-Png $bmp $g "floor_medallion.png"
