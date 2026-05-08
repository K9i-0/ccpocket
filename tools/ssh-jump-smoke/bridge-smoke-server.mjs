import crypto from 'node:crypto';
import http from 'node:http';

const port = Number.parseInt(process.env.CCPOCKET_BRIDGE_SMOKE_PORT ?? '8765', 10);

const server = http.createServer((request, response) => {
  if (request.url === '/health') {
    response.writeHead(200, { 'content-type': 'text/plain' });
    response.end('ok');
    return;
  }

  if (request.url === '/version') {
    response.writeHead(200, { 'content-type': 'application/json' });
    response.end(JSON.stringify({
      version: '0.0.0-smoke',
      platform: 'linux',
      arch: process.arch,
    }));
    return;
  }

  response.writeHead(404, { 'content-type': 'text/plain' });
  response.end('not found');
});

server.on('upgrade', (request, socket) => {
  const key = request.headers['sec-websocket-key'];
  if (typeof key !== 'string') {
    socket.destroy();
    return;
  }

  const accept = crypto
    .createHash('sha1')
    .update(`${key}258EAFA5-E914-47DA-95CA-C5AB0DC85B11`)
    .digest('base64');

  socket.write([
    'HTTP/1.1 101 Switching Protocols',
    'Upgrade: websocket',
    'Connection: Upgrade',
    `Sec-WebSocket-Accept: ${accept}`,
    '',
    '',
  ].join('\r\n'));

  const payload = Buffer.from(JSON.stringify({
    type: 'bridge_smoke',
    ok: true,
  }));
  socket.write(Buffer.concat([
    Buffer.from([0x81, payload.length]),
    payload,
  ]));
});

server.listen(port, '0.0.0.0', () => {
  console.log(`ccpocket bridge smoke server listening on ${port}`);
});
