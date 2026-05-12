#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT_DIR="${OUTPUT_DIR:-$ROOT_DIR/dist/games}"
TEMPLATE_DIR="$ROOT_DIR/web/templates"
LOVE_VERSION="11.5"

case "$OUTPUT_DIR" in
	/*)
		;;
	*)
		OUTPUT_DIR="$ROOT_DIR/$OUTPUT_DIR"
		;;
esac

GAMES=(
	"game-top-down-shooter"
	"game-shooting-gallery"
	"game-platformer"
)

game_size() {
	case "$1" in
		game-top-down-shooter)
			printf '960 540'
			;;
		game-shooting-gallery)
			printf '800 600'
			;;
		game-platformer)
			printf '1000 768'
			;;
		*)
			printf '800 600'
			;;
	esac
}

game_slug() {
	printf '%s' "$1" | sed 's/^game-//'
}

find_lovejs_dir() {
	if [[ -n "${LOVEJS_DIR:-}" ]]; then
		printf '%s\n' "$LOVEJS_DIR"
	elif [[ -f "$ROOT_DIR/web/lovejs/player.js" ]]; then
		printf '%s\n' "$ROOT_DIR/web/lovejs"
	elif [[ -f "$ROOT_DIR/dist/web/love.js/player.js" ]]; then
		printf '%s\n' "$ROOT_DIR/dist/web/love.js"
	else
		cat >&2 <<'MSG'
Could not find the love.js runtime.

Set LOVEJS_DIR=/path/to/love.js, or keep the minimal runtime in:
  web/lovejs/
MSG
		exit 1
	fi
}

copy_lovejs() {
	local source_dir="$1"
	local game_dist_dir="$2"

	mkdir -p "$game_dist_dir/11.5" "$game_dist_dir/lua"
	cp "$source_dir/player.js" "$game_dist_dir/"
	cp "$source_dir/style.css" "$game_dist_dir/"
	cp "$source_dir/nogame.love" "$game_dist_dir/"
	cp "$source_dir/license.txt" "$game_dist_dir/lovejs-license.txt"
	cp "$source_dir/11.5/love.js" "$game_dist_dir/11.5/"
	cp "$source_dir/11.5/love.wasm" "$game_dist_dir/11.5/"
	cp "$source_dir/11.5/license.txt" "$game_dist_dir/11.5/"
	cp "$source_dir/lua/normalize1.lua" "$game_dist_dir/lua/"
	cp "$source_dir/lua/normalize2.lua" "$game_dist_dir/lua/"
}

write_index() {
	local game="$1"
	local game_dist_dir="$2"
	local title
	local width
	local height
	local love_file
	local template_file
	local slug

	title="$(printf '%s' "$game" | sed 's/game-//; s/-/ /g')"
	read -r width height <<< "$(game_size "$game")"
	slug="$(game_slug "$game")"
	love_file="$slug.love"

	if [[ -f "$TEMPLATE_DIR/$game.html" ]]; then
		template_file="$TEMPLATE_DIR/$game.html"
	else
		template_file="$TEMPLATE_DIR/game.html"
	fi

	sed \
		-e "s|{{TITLE}}|$title|g" \
		-e "s|{{GAME_ID}}|$game|g" \
		-e "s|{{LOVE_FILE}}|$love_file|g" \
		-e "s|{{LOVE_VERSION}}|$LOVE_VERSION|g" \
		-e "s|{{WIDTH}}|$width|g" \
		-e "s|{{HEIGHT}}|$height|g" \
		"$template_file" > "$game_dist_dir/index.html"
}

build_game() {
	local game="$1"
	local game_dir="$ROOT_DIR/$game"
	local slug
	local game_dist_dir
	local love_file
	local lovejs_dir="$2"

	slug="$(game_slug "$game")"
	game_dist_dir="$OUTPUT_DIR/$slug"
	love_file="$game_dist_dir/$slug.love"

	if [[ ! -f "$game_dir/main.lua" ]]; then
		echo "Skipping $game: missing main.lua" >&2
		return
	fi

	rm -rf "$game_dist_dir"
	mkdir -p "$game_dist_dir"

	(
		cd "$game_dir"
		zip -9 -r "$love_file" . -x "*.DS_Store" ".gitignore"
	)

	copy_lovejs "$lovejs_dir" "$game_dist_dir"
	write_index "$game" "$game_dist_dir"

	echo "Built $game -> $game_dist_dir"
}

lovejs_dir="$(find_lovejs_dir)"

if [[ "$#" -gt 0 ]]; then
	for game in "$@"; do
		build_game "$game" "$lovejs_dir"
	done
else
	for game in "${GAMES[@]}"; do
		build_game "$game" "$lovejs_dir"
	done
fi

cat <<MSG

Done.

Local output:
  $OUTPUT_DIR

Local test:
  npm run dev

Open:
  http://localhost:5173/games/top-down-shooter/
  http://localhost:5173/games/shooting-gallery/
  http://localhost:5173/games/platformer/
MSG
