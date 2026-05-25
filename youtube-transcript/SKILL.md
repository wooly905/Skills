---
name: youtube-transcript
description: Download a YouTube video's audio and generate transcript files (txt, srt, vtt, tsv, json) using OpenAI Whisper, with NVIDIA GPU acceleration when available. Use when the user provides a YouTube or other video URL and wants a transcript, captions, subtitles, 逐字稿, or 字幕. Triggers on requests to transcribe a video, generate captions for an uncaptioned YouTube video, 把影片轉成逐字稿/文字, extract speech from audio, or any mention of Whisper transcription. Also use when the user provides an mp3/mp4 path and asks for a transcript.
---

# YouTube to Transcript

Generate transcript files from a YouTube video (or any source supported by `yt-dlp`) using OpenAI Whisper. All work is done by the bundled PowerShell script:

```
C:\Users\bruce\.claude\skills\youtube-transcript\transcribe.ps1
```

## What to ask the user (briefly)

In one short message, confirm:

1. **URL** — required.
2. **Keywords / topic / proper nouns** — strongly recommended. Speaker names, product names ("Claude Code", "Anthropic"), jargon. These go into `--initial_prompt`. Without them, Whisper mishears proper nouns (e.g. "Claude" → "Cloud") and accuracy on names drops 5–10x.
3. **Output folder** — default `C:\temp`. Only ask if unclear.
4. **Language** — assume English unless the URL/title suggests otherwise.

If the user gives only a URL, peek at the video first and ask once for a keyword hint:

```powershell
yt-dlp --print "title: %(title)s`nduration: %(duration_string)s`nuploader: %(uploader)s" "<URL>"
```

## Running the script

```powershell
& "C:\Users\bruce\.claude\skills\youtube-transcript\transcribe.ps1" `
    -Url "<URL>" `
    -InitialPrompt "<hint, e.g. 'Talk by Daisy Holman about Claude Code at Anthropic'>" `
    -OutputDir "C:\temp"
```

Decision rules:

- **Background vs foreground**: estimate runtime. On the user's GPU (RTX 4060), expect roughly real-time-divided-by-10 for `medium.en`. If estimated runtime > 8 minutes, run with `run_in_background: true`. Otherwise foreground with `timeout: 600000` (10 min).
- **Non-English audio**: add `-Language Chinese` (or `Japanese`, etc.) AND switch the model: `-Model medium` (not `medium.en`). The `*.en` variants are English-only.
- **Tough audio / maximum accuracy**: switch to `-Model large`. Needs ~5GB VRAM (fits in 8GB on RTX 4060).

## First-time setup on a new machine

```powershell
& "C:\Users\bruce\.claude\skills\youtube-transcript\transcribe.ps1" -Setup
```

This installs (idempotently): Python 3.12 (winget), ffmpeg (winget), yt-dlp (winget), openai-whisper (pip), and the CUDA 12.8 build of PyTorch (pip) when an NVIDIA GPU is detected. winget installs may need a fresh PowerShell session before PATH picks up — the script refreshes PATH itself, but if a step fails with "command not found", advise the user to reopen PowerShell and re-run.

If PowerShell blocks the script with an execution policy error, advise:

```powershell
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
```

## After it finishes

- The script lists the produced files at the end (basename `yt_YYYYMMDD_HHMMSS`).
- Preview the first 10–15 lines of `<basename>.txt` so the user can sanity-check quality.
- If a proper noun looks wrong throughout, suggest re-running with a richer `-InitialPrompt`. Optionally back up the previous output to a `v1_no_prompt` subfolder so the user can compare.

## Output formats

| File | Content |
|---|---|
| `<base>.txt` | Plain text, one paragraph per segment |
| `<base>.srt` | SRT subtitle (timestamps + text) |
| `<base>.vtt` | WebVTT subtitle |
| `<base>.tsv` | Tab-separated: start_ms, end_ms, text |
| `<base>.json` | Full per-segment data including confidence scores |

The downloaded `<base>.mp3` is deleted unless `-KeepAudio` is passed.

## Common pitfalls

- **Whisper `--help` Unicode crash**: setting `$env:PYTHONIOENCODING = 'utf-8'` fixes it. The script already does this for the transcription run, but mention it if the user hits the error elsewhere.
- **CPU-only PyTorch**: a plain `pip install openai-whisper` pulls the CPU build. The `-Setup` flow detects this and swaps in the CUDA build. If the user manually reinstalled torch and lost CUDA, re-run `-Setup`.
- **Hallucinated repetition at silent segments**: Whisper sometimes loops on silence. If the transcript has obvious repetition, suggest re-running with `--condition_on_previous_text False` (would need a small script edit).
