var _a, _b, _c, _d, _e;
import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";
var processEnv = (_b = (_a = globalThis.process) === null || _a === void 0 ? void 0 : _a.env) !== null && _b !== void 0 ? _b : {};
function normalizeBaseUrl(url, fallback) {
    return (url !== null && url !== void 0 ? url : fallback).trim().replace(/\/$/, "");
}
var authProxyTarget = normalizeBaseUrl((_c = processEnv.AUTH_BASE_URL) !== null && _c !== void 0 ? _c : processEnv.VITE_AUTH_BASE_URL, "http://127.0.0.1:3000");
var roomsProxyTarget = normalizeBaseUrl((_e = (_d = processEnv.ROOMS_BASE_URL) !== null && _d !== void 0 ? _d : processEnv.ROOMS_API_BASE_URL) !== null && _e !== void 0 ? _e : processEnv.VITE_ROOMS_BASE_URL, "http://127.0.0.1:3001");
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
                rewrite: function (path) { return path.replace(/^\/__auth_proxy__/, ""); },
            },
            "/__rooms_proxy__": {
                target: roomsProxyTarget,
                changeOrigin: true,
                rewrite: function (path) { return path.replace(/^\/__rooms_proxy__/, ""); },
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
