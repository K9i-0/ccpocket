import { createServer, type Server } from "node:http";
import type { AddressInfo } from "node:net";
import { afterEach, describe, expect, it } from "vitest";
import { listenForStartup } from "./server-listen.js";

const servers: Server[] = [];

describe("listenForStartup", () => {
  afterEach(async () => {
    await Promise.all(
      servers.splice(0).map(
        (server) =>
          new Promise<void>((resolve) => {
            if (!server.listening) {
              resolve();
              return;
            }
            server.close(() => resolve());
          }),
      ),
    );
  });

  it("resolves after the server is listening", async () => {
    const server = createServer();
    servers.push(server);

    await listenForStartup(server, 0, "127.0.0.1");

    expect(server.listening).toBe(true);
  });

  it("rejects when the port is already in use", async () => {
    const occupied = createServer();
    const candidate = createServer();
    servers.push(occupied, candidate);
    await listenForStartup(occupied, 0, "127.0.0.1");
    const port = (occupied.address() as AddressInfo).port;

    await expect(
      listenForStartup(candidate, port, "127.0.0.1"),
    ).rejects.toMatchObject({ code: "EADDRINUSE" });
  });
});
