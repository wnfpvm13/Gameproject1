# Generates one Korean WAV per word (Windows "Microsoft Heami" voice) into Studio's content folder,
# so the probe can load them as rbxasset://sounds/bannedwords_probe/wNN.wav without uploading.
param([string]$StudioVersionDir)
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$out = Join-Path $StudioVersionDir "content\sounds\bannedwords_probe"
New-Item -ItemType Directory -Force $out | Out-Null
Add-Type -AssemblyName System.Speech
$words = Get-Content (Join-Path $here "words.txt") -Encoding UTF8 | Where-Object { $_.Trim() }
function Josa($w, $a, $b) { $c = [int][char]$w[$w.Length-1]; if ($c -ge 0xAC00 -and $c -le 0xD7A3 -and (($c - 0xAC00) % 28) -ne 0) { $a } else { $b } }
$templates = @(
  { param($w) "$w$(Josa $w '이' '가') 정말 좋아" },
  { param($w) "나는 어제 $w$(Josa $w '을' '를') 봤어" },
  { param($w) "$w$(Josa $w '은' '는') 어디 있어?" }
)
$fmt = New-Object System.Speech.AudioFormat.SpeechAudioFormatInfo(16000, [System.Speech.AudioFormat.AudioBitsPerSample]::Sixteen, [System.Speech.AudioFormat.AudioChannel]::Mono)
$manifest = @()
for ($i = 0; $i -lt $words.Count; $i++) {
  $w = [string]$words[$i]; $id = "w{0:D2}" -f ($i + 1)
  $sentence = & $templates[$i % 3] $w
  $s = New-Object System.Speech.Synthesis.SpeechSynthesizer
  $s.SelectVoice("Microsoft Heami Desktop")
  $s.SetOutputToWaveFile((Join-Path $out "$id.wav"), $fmt); $s.Speak($sentence); $s.SetOutputToNull(); $s.Dispose()
  $manifest += [pscustomobject]@{ id = $id; word = $w; sentence = $sentence }
}
$json = $manifest | ConvertTo-Json -Compress
[IO.File]::WriteAllText((Join-Path $here "manifest.json"), $json, (New-Object System.Text.UTF8Encoding $false))
"generated $($manifest.Count) files in $out"
