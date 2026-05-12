import { defineConfig } from 'vite'

function serveGameDirectoryIndexes() {
  return {
    name: 'serve-game-directory-indexes',
    configureServer(server) {
      server.middlewares.use((req, _res, next) => {
        if (req.url && /^\/games\/[^/]+\/(?:\?.*)?$/.test(req.url)) {
          req.url = req.url.replace(/\/(\?.*)?$/, '/index.html$1')
        }
        next()
      })
    },
    configurePreviewServer(server) {
      server.middlewares.use((req, _res, next) => {
        if (req.url && /^\/games\/[^/]+\/(?:\?.*)?$/.test(req.url)) {
          req.url = req.url.replace(/\/(\?.*)?$/, '/index.html$1')
        }
        next()
      })
    },
  }
}

export default defineConfig({
  plugins: [serveGameDirectoryIndexes()],
  root: 'dist',
  publicDir: false,
  server: {
    host: '127.0.0.1',
    headers: {
      'Cross-Origin-Opener-Policy': 'same-origin',
      'Cross-Origin-Embedder-Policy': 'require-corp',
    },
  },
  preview: {
    headers: {
      'Cross-Origin-Opener-Policy': 'same-origin',
      'Cross-Origin-Embedder-Policy': 'require-corp',
    },
  },
})
