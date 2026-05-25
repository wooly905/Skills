<#
.SYNOPSIS
    Download a YouTube video's audio and generate transcripts using OpenAI Whisper.

.DESCRIPTION
    Downloads audio with yt-dlp, then runs Whisper to produce transcripts in
    five formats (txt, srt, vtt, tsv, json). Automatically uses an NVIDIA GPU
    when available, otherwise falls back to CPU.

    Run with -Setup once on a new machine to install all required tools.

.PARAMETER Url
    YouTube (or any yt-dlp-supported) video URL.

.PARAMETER InitialPrompt
    Hint string passed to Whisper. Strongly recommended for videos containing
    proper nouns, product names, or jargon. Without it, Whisper often mishears
    names (for example "Claude" -> "Cloud"). Maximum is roughly 150 English
    words; longer prompts are silently truncated.

.PARAMETER OutputDir
    Directory for the audio file and transcripts. Created if missing.
    Default: C:\temp.

.PARAMETER Model
    Whisper model. Default: medium.en (English-only, best speed/accuracy
    balance on GPU). Other options: tiny.en, base.en, small.en, large
    (multilingual only, needs ~5GB VRAM).

.PARAMETER Language
    Spoken language, English name (English, Chinese, Japanese, ...).
    Default: English. For non-English audio, switch to a multilingual model
    (medium, large) instead of *.en.

.PARAMETER KeepAudio
    Keep the downloaded mp3 file after transcription. By default it is
    removed once the transcript is produced.

.PARAMETER Setup
    Install missing dependencies (Python, ffmpeg, yt-dlp, openai-whisper, and
    the CUDA build of PyTorch when an NVIDIA GPU is detected) and exit.

.EXAMPLE
    .\transcribe.ps1 -Setup

    Install everything needed (one time per machine).

.EXAMPLE
    .\transcribe.ps1 -Url "https://www.youtube.com/watch?v=tuY2ChJIx48"

    Default usage. Writes transcripts to C:\temp.

.EXAMPLE
    .\transcribe.ps1 -Url "https://..." -InitialPrompt "Talk by Daisy Holman about Claude Code at Anthropic."

    Hint Whisper about proper nouns for much better accuracy.

.EXAMPLE
    .\transcribe.ps1 -Url "https://..." -Language Chinese -Model medium -OutputDir D:\transcripts

    Chinese audio, multilingual model, custom output directory.
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$Url,

    [string]$InitialPrompt = '',
    [string]$OutputDir = 'C:\temp',
    [string]$Model = 'medium.en',
    [string]$Language = 'English',
    [switch]$KeepAudio,
    [switch]$Setup
)

$ErrorActionPreference = 'Stop'

function Update-SessionPath {
    $env:Path = [System.Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' +
                [System.Environment]::GetEnvironmentVariable('Path', 'User')
}

function Test-Tool {
    param([Parameter(Mandatory)][string]$Name)
    [bool](Get-Command $Name -ErrorAction SilentlyContinue)
}

function Test-PipPackage {
    param([Parameter(Mandatory)][string]$Name)
    pip show $Name 2>&1 | Out-Null
    return ($LASTEXITCODE -eq 0)
}

function Test-CudaTorch {
    if (-not (Test-Tool 'python')) { return $false }
    $out = python -c "import torch; print(torch.cuda.is_available())" 2>$null
    return ($out -and $out.Trim() -eq 'True')
}

function Install-Dependencies {
    Write-Host '=== Setup: checking and installing dependencies ===' -ForegroundColor Cyan
    Update-SessionPath

    if (-not (Test-Tool 'python')) {
        Write-Host '> Installing Python 3.12 via winget ...' -ForegroundColor Yellow
        winget install --id Python.Python.3.12 -e --accept-source-agreements --accept-package-agreements
        Update-SessionPath
    } else {
        Write-Host '  Python: OK' -ForegroundColor Green
    }

    if (-not (Test-Tool 'ffmpeg')) {
        Write-Host '> Installing ffmpeg via winget ...' -ForegroundColor Yellow
        winget install --id Gyan.FFmpeg -e --accept-source-agreements --accept-package-agreements
        Update-SessionPath
    } else {
        Write-Host '  ffmpeg: OK' -ForegroundColor Green
    }

    if (-not (Test-Tool 'yt-dlp')) {
        Write-Host '> Installing yt-dlp via winget ...' -ForegroundColor Yellow
        winget install --id yt-dlp.yt-dlp -e --accept-source-agreements --accept-package-agreements
        Update-SessionPath
    } else {
        Write-Host '  yt-dlp: OK' -ForegroundColor Green
    }

    if (-not (Test-PipPackage 'openai-whisper')) {
        Write-Host '> Installing openai-whisper via pip (also pulls in PyTorch ~2.5GB) ...' -ForegroundColor Yellow
        pip install -U openai-whisper
    } else {
        Write-Host '  openai-whisper: OK' -ForegroundColor Green
    }

    if (Test-Tool 'nvidia-smi') {
        if (-not (Test-CudaTorch)) {
            Write-Host '> NVIDIA GPU detected. Replacing CPU-only PyTorch with CUDA 12.8 build (~2.8GB) ...' -ForegroundColor Yellow
            pip uninstall -y torch
            pip install torch --index-url https://download.pytorch.org/whl/cu128
        } else {
            Write-Host '  PyTorch CUDA: OK (GPU will be used)' -ForegroundColor Green
        }
    } else {
        Write-Host '  No NVIDIA GPU detected. CPU mode will be used (slower).' -ForegroundColor Yellow
    }

    Write-Host '=== Setup complete ===' -ForegroundColor Cyan
}

# --- main ---
Update-SessionPath

if ($Setup) {
    Install-Dependencies
    return
}

if (-not $Url) {
    Write-Error 'The -Url parameter is required. To install dependencies on a new machine, run: .\transcribe.ps1 -Setup'
    return
}

foreach ($tool in @('yt-dlp', 'ffmpeg', 'whisper')) {
    if (-not (Test-Tool $tool)) {
        Write-Error "Missing tool: $tool. Run with -Setup first."
        return
    }
}

New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null

$basename  = 'yt_' + (Get-Date -Format 'yyyyMMdd_HHmmss')
$audioFile = Join-Path $OutputDir "$basename.mp3"

Write-Host "Downloading audio from $Url ..." -ForegroundColor Cyan
yt-dlp -x --audio-format mp3 -o "$OutputDir\$basename.%(ext)s" $Url
if ($LASTEXITCODE -ne 0) {
    Write-Error 'yt-dlp failed.'
    return
}
if (-not (Test-Path $audioFile)) {
    Write-Error "Expected audio file not found: $audioFile"
    return
}

$device = if (Test-CudaTorch) { 'cuda' } else { 'cpu' }
Write-Host "Transcribing with model '$Model' on device '$device' ..." -ForegroundColor Cyan

$env:PYTHONIOENCODING = 'utf-8'
$whisperArgs = @(
    $audioFile
    '--language',      $Language
    '--model',         $Model
    '--device',        $device
    '--output_dir',    $OutputDir
    '--output_format', 'all'
    '--verbose',       'True'
)
if ($InitialPrompt) {
    $whisperArgs += @('--initial_prompt', $InitialPrompt)
}

whisper @whisperArgs
if ($LASTEXITCODE -ne 0) {
    Write-Error 'Whisper failed.'
    return
}

if (-not $KeepAudio) {
    Remove-Item $audioFile -Force -ErrorAction SilentlyContinue
    Write-Host "Removed $audioFile (use -KeepAudio to retain it)." -ForegroundColor DarkGray
}

Write-Host "`nDone. Transcript files in ${OutputDir}:" -ForegroundColor Green
Get-ChildItem (Join-Path $OutputDir "$basename.*") |
    Select-Object Name, @{N='Size'; E={'{0:N1} KB' -f ($_.Length / 1KB)}} |
    Format-Table -AutoSize
