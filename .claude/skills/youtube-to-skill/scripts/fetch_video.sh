#!/usr/bin/env bash
# Fetch transcript + scene-change frames of a YouTube video for Claude to read.
# Usage: fetch_video.sh <url> <workdir> [max_frames]
set -euo pipefail

URL="$1"
WORK="$2"
MAX_FRAMES="${3:-60}"

command -v yt-dlp >/dev/null || { echo "yt-dlp missing (pip install yt-dlp)" >&2; exit 1; }
command -v ffmpeg >/dev/null || { echo "ffmpeg missing" >&2; exit 1; }

mkdir -p "$WORK/frames"

# Subtitles: prefer manual, fall back to auto-generated.
yt-dlp --skip-download --write-subs --write-auto-subs --sub-langs "en.*,de.*" \
  --sub-format vtt -o "$WORK/subs.%(ext)s" "$URL" || true

# Strip VTT timing noise but keep one timestamp per cue.
: > "$WORK/transcript.txt"
for f in "$WORK"/subs*.vtt; do
  [ -e "$f" ] || continue
  awk '/-->/ {split($1,t,"."); ts=t[1]; next}
       /^(WEBVTT|Kind:|Language:|$)/ {next}
       {gsub(/<[^>]*>/,""); if ($0 != last) print "[" ts "] " $0; last=$0}' "$f" >> "$WORK/transcript.txt"
  break
done
[ -s "$WORK/transcript.txt" ] || echo "(no subtitles available)" > "$WORK/transcript.txt"

# Low-res video is enough for reading screens.
yt-dlp -f "bv*[height<=720]+ba/b[height<=720]/b" --merge-output-format mp4 \
  -o "$WORK/video.%(ext)s" "$URL"

# One frame per scene change, timestamp in the file name via showinfo log.
ffmpeg -hide_banner -loglevel error -i "$WORK/video.mp4" \
  -vf "select='gt(scene,0.25)',scale=1280:-2" -fps_mode vfr \
  -frames:v "$MAX_FRAMES" "$WORK/frames/frame_%04d.jpg"

# Guarantee some coverage for static screencasts with few scene changes.
if [ "$(ls "$WORK/frames" | wc -l)" -lt 10 ]; then
  ffmpeg -hide_banner -loglevel error -i "$WORK/video.mp4" \
    -vf "fps=1/15,scale=1280:-2" -frames:v "$MAX_FRAMES" "$WORK/frames/t15s_%04d.jpg"
fi

echo "transcript: $WORK/transcript.txt"
echo "frames:     $(ls "$WORK/frames" | wc -l) in $WORK/frames"
