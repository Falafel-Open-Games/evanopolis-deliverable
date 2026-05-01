import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

const processEnv =
  (
    globalThis as typeof globalThis & {
      process?: { env?: Record<string, string | undefined> };
    }
  ).process?.env ?? {};

function normalizeBaseUrl(url: string | undefined, fallback: string): string {
  return (url ?? fallback).trim().replace(/\/$/, "");
}

const authProxyTarget = normalizeBaseUrl(
  processEnv.AUTH_BASE_URL ?? processEnv.VITE_AUTH_BASE_URL,
  "http://127.0.0.1:3000",
);

const roomsProxyTarget = normalizeBaseUrl(
  processEnv.ROOMS_BASE_URL ??
    processEnv.ROOMS_API_BASE_URL ??
    processEnv.VITE_ROOMS_BASE_URL,
  "http://127.0.0.1:3001",
);

export default defineConfig({
  plugins: [react()],
  server: {
    host: "127.0.0.1",
    allowedHosts: [".falafel.com.br"],
    headers: {
      "Cache-Control": "no-store",
    },
    proxy: {
      "/__auth_proxy__": {
        target: authProxyTarget,
        changeOrigin: true,
        rewrite: (path) => path.replace(/^\/__auth_proxy__/, ""),
      },
      "/__rooms_proxy__": {
        target: roomsProxyTarget,
        changeOrigin: true,
        rewrite: (path) => path.replace(/^\/__rooms_proxy__/, ""),
      },
    },
  },
  build: {
    rollupOptions: {
      input: {
        main: new URL("index.html", import.meta.url).pathname,
        invite: new URL("invite.html", import.meta.url).pathname,
        launch: new URL("launch.html", import.meta.url).pathname,
      },
    },
  },
});
