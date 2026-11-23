#!/usr/bin/env bash
# Capture seed-42 cloud parallax at gameplay zoom under xvfb.
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
output="${1:-$repo/docs/evidence/cloud-parallax-693}"
scratch="$(mktemp -d)"
trap 'rm -rf "$scratch"' EXIT
godot="${GODOT:-godot}"

display() {
  timeout 120s xvfb-run -a -s "-screen 0 1280x720x24" "$godot" --path "$repo" --rendering-driver opengl3 --audio-driver Dummy "$@"
}

export FLAGORIA_CLOUD_FRAMES="$scratch/frames"
export XDG_DATA_HOME="$scratch/data"
export XDG_CONFIG_HOME="$scratch/config"
export XDG_CACHE_HOME="$scratch/cache"
user_data="$XDG_DATA_HOME/godot/app_userdata/Flagoria"
mkdir -p "$user_data" "$output"
cat > "$user_data/map_gen_params.cfg" <<'CFG'
[map_gen]

altitude_seed=42
moisture_seed=43
temperature_seed=44
items_seed=45
biome_seed=46
CFG

if [[ ! -f "$repo/.godot/global_script_class_cache.cfg" ]]; then
  display --import
fi
display --script res://tools/capture_cloud_parallax.gd

frames="$FLAGORIA_CLOUD_FRAMES/frame_%03d.png"
ffmpeg -v error -y -filter_complex_threads 1 -framerate 12 -i "$frames" \
  -filter_complex 'split[a][b];[a]palettegen[p];[b][p]paletteuse=dither=none' \
  -loop 0 -final_delay 8 "$output/cloud-drift.gif"
ffmpeg -v error -y -filter_threads 1 -framerate 12 -i "$frames" \
  -c:v libx264 -pix_fmt yuv420p -crf 18 -movflags +faststart "$output/cloud-drift.mp4"
cp "$FLAGORIA_CLOUD_FRAMES"/cloud-*.png "$output/"
