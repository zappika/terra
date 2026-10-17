// Zero-dependency static server for the simulator. Serves device-sim/ and the iOS fixtures read-only.
import { createServer } from 'node:http';
import { readFile } from 'node:fs/promises';
import { extname, resolve, sep } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = resolve(fileURLToPath(new URL('.', import.meta.url)));
const fixtures = resolve(here, '../ios/Fixtures');
const port = Number(process.env.PORT) || 4810;
const types = { '.html': 'text/html', '.js': 'text/javascript', '.json': 'application/json', '.css': 'text/css' };

createServer(async (req, res) => {
  const path = decodeURIComponent(new URL(req.url, 'http://x').pathname);
  const [root, rel] = path.startsWith('/fixtures/') ? [fixtures, path.slice('/fixtures/'.length)] : [here, path === '/' ? 'index.html' : path.slice(1)];
  const file = resolve(root, rel);
  if (!file.startsWith(root + sep)) return res.writeHead(403).end();
  try {
    const body = await readFile(file);
    res.writeHead(200, { 'content-type': types[extname(file)] ?? 'application/octet-stream', 'cache-control': 'no-store' }).end(body);
  } catch {
    res.writeHead(404).end('Not found');
  }
}).listen(port, () => console.log(`TERRA device simulator: http://localhost:${port}`));
