// Features:
// - HTTP server serving the Elm SPA on PORT (default 8080)
// - SEA mode: serves index.html and bundle.js from embedded assets
// - Non-SEA mode: reads index.html and bundle.js from the filesystem (container and local dev)
import fs from 'node:fs'
import http from 'node:http'
import path from 'node:path'
import sea from 'node:sea'

let html: string
let bundle: string

if (sea.isSea()) {
  html = sea.getAsset('index.html', 'utf8')
  bundle = sea.getAsset('bundle.js', 'utf8')
} else {
  html = fs.readFileSync(path.join(__dirname, '..', 'index.html'), 'utf8')
  bundle = fs.readFileSync(path.join(__dirname, 'bundle.js'), 'utf8')
}

const PORT = process.env.PORT ?? 8080

http.createServer((req, res) => {
  if (req.url === '/dist/bundle.js') {
    res.writeHead(200, { 'Content-Type': 'application/javascript' })
    res.end(bundle)
  } else {
    res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' })
    res.end(html)
  }
}).listen(PORT, () => console.log(`listening on :${PORT}`))
