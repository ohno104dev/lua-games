# LÖVE Web Builds

Each game is packaged as a `.love` file and served through the standalone love.js player.

## Build

Build every game:

```bash
./scripts/build-love-web.sh
```

Build one game:

```bash
./scripts/build-love-web.sh game-topgun-shooter
```

Or use the per-game wrappers:

```bash
npm run build:topgun-shooter
npm run build:crazy-shotgun
npm run build:lili-run
```

The same commands are also available through Make:

```bash
make build-games
make build-topgun-shooter
make build-crazy-shotgun
make build-lili-run
```

The local build output is written to:

```text
public/games/
```

## Vue / Cloudflare Pages

Local development builds games into `dist/games` before running Vite:

```bash
npm run dev
```

Production builds prepare `dist/_headers` and package games into `dist/games` for Cloudflare Pages:

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
<iframe src="/games/topgun-shooter/"></iframe>
```

The final deployed structure intentionally does not include a root `index.html`.
It should include:

```text
dist/
  _headers
  games/topgun-shooter/index.html
  games/topgun-shooter/topgun-shooter.love
  games/topgun-shooter/player.js
  games/topgun-shooter/11.5/love.js
  games/topgun-shooter/11.5/love.wasm
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
web/templates/game-topgun-shooter.html
web/templates/game-crazy-shotgun.html
web/templates/game-lili-run.html
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
