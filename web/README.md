# LÖVE Web Builds

Each game is packaged as a `.love` file and served through the standalone love.js player.

## Build

Build every game:

```bash
./scripts/build-love-web.sh
```

Build one game:

```bash
./scripts/build-love-web.sh game-top-down-shooter
```

Or use the per-game wrappers:

```bash
npm run build:top-down-shooter
npm run build:shooting-gallery
npm run build:platformer
```

The same commands are also available through Make:

```bash
make build-games
make build-top-down-shooter
make build-shooting-gallery
make build-platformer
```

The local build output is written to:

```text
public/games/
```

## Vue / Cloudflare Pages

Local development builds games into `public/games` before running Vite:

```bash
npm run dev
```

Production builds package games into `public/games` and copy `public` to `dist` for Cloudflare Pages:

```bash
npm run build
```

Cloudflare Pages should use:

```text
Build command: npm run build
Build output directory: dist
```

Embed each game from Vue with an iframe:

```html
<iframe src="/games/game-top-down-shooter/"></iframe>
```

The final deployed structure intentionally does not include a root `index.html`.
It should include:

```text
dist/
  _headers
  games/game-top-down-shooter/index.html
  games/game-top-down-shooter/game-top-down-shooter.love
  games/game-top-down-shooter/player.js
  games/game-top-down-shooter/11.5/love.js
  games/game-top-down-shooter/11.5/love.wasm
```

## Server Headers

Serve the built files from a web server. Do not open `index.html` with `file://`.

Cloudflare Pages reads `public/_headers`, which should include:

```text
/*
  Cross-Origin-Opener-Policy: same-origin
  Cross-Origin-Embedder-Policy: require-corp
```

## Game Page Templates

Generated game pages are built from:

```text
web/templates/game.html
```

To override one game, create a matching template:

```text
web/templates/game-top-down-shooter.html
web/templates/game-shooting-gallery.html
web/templates/game-platformer.html
```

Supported placeholders:

```text
{{TITLE}}
{{GAME_ID}}
{{LOVE_FILE}}
{{LOVE_VERSION}}
{{WIDTH}}
{{HEIGHT}}
```
