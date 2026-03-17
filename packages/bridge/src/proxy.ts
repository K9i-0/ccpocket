/**
 * Global proxy support for Bridge Server fetch() calls.
 *
 * Reads HTTPS_PROXY / HTTP_PROXY / ALL_PROXY and configures the
 * Node.js global fetch dispatcher via undici.
 *
 * Supported protocols:
 *   http://   → undici ProxyAgent
 *   https://  → undici ProxyAgent
 *   socks5:// → SOCKS5 tunnel via undici Agent + socks
 *   socks4:// → SOCKS4 tunnel via undici Agent + socks
 *
 * Call setupProxy() once before any fetch() — typically in index.ts / cli.ts.
 */

import { setGlobalDispatcher, ProxyAgent, Agent } from "undici";
import { SocksClient, type SocksProxy } from "socks";
import { connect as tlsConnect, type TLSSocket } from "node:tls";
import type { Socket } from "node:net";

function getProxyUrl(): string | undefined {
  return (
    process.env.HTTPS_PROXY ||
    process.env.https_proxy ||
    process.env.HTTP_PROXY ||
    process.env.http_proxy ||
    process.env.ALL_PROXY ||
    process.env.all_proxy
  );
}

export function setupProxy(): string | undefined {
  const proxyUrl = getProxyUrl();
  if (!proxyUrl) return undefined;

  let parsed: URL;
  try {
    parsed = new URL(proxyUrl);
  } catch {
    console.warn(`[proxy] Invalid proxy URL: ${proxyUrl}`);
    return undefined;
  }

  const proto = parsed.protocol.replace(":", "").toLowerCase();

  if (proto === "http" || proto === "https") {
    setGlobalDispatcher(new ProxyAgent({ uri: proxyUrl }));
  } else if (proto === "socks5" || proto === "socks5h" || proto === "socks4" || proto === "socks") {
    setupSocks(parsed, proto);
  } else {
    console.warn(`[proxy] Unsupported protocol: ${proto}`);
    return undefined;
  }

  console.log(`[proxy] Using ${proto} proxy ${parsed.hostname}:${parsed.port}`);
  return proxyUrl;
}

function setupSocks(parsed: URL, proto: string): void {
  const proxy: SocksProxy = {
    host: parsed.hostname,
    port: parseInt(parsed.port, 10) || 1080,
    type: proto.startsWith("socks4") ? 4 : 5,
  };

  if (parsed.username) {
    proxy.userId = decodeURIComponent(parsed.username);
  }
  if (parsed.password) {
    proxy.password = decodeURIComponent(parsed.password);
  }

  setGlobalDispatcher(
    new Agent({
      connect: async (opts, cb) => {
        try {
          const host =
            typeof opts.hostname === "string"
              ? opts.hostname
              : (opts.host ?? "localhost");
          const port =
            typeof opts.port === "number"
              ? opts.port
              : parseInt(String(opts.port ?? "443"), 10);

          const { socket } = await SocksClient.createConnection({
            proxy,
            command: "connect",
            destination: { host, port },
          });

          if (opts.protocol === "https:" || port === 443) {
            const tls = tlsConnect({
              socket: socket as unknown as Socket,
              servername: host,
            });
            cb(null, tls as TLSSocket);
          } else {
            cb(null, socket as unknown as Socket);
          }
        } catch (err) {
          cb(err instanceof Error ? err : new Error(String(err)), null);
        }
      },
    }),
  );
}
