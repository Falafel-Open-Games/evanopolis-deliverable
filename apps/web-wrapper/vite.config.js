import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";
export default defineConfig({
    plugins: [react()],
    server: {
        host: "127.0.0.1",
        allowedHosts: [".falafel.com.br"],
        proxy: {
            "/__auth_proxy__": {
                target: "http://127.0.0.1:3000",
                changeOrigin: true,
                rewrite: function (path) { return path.replace(/^\/__auth_proxy__/, ""); },
            },
            "/__rooms_proxy__": {
                target: "http://127.0.0.1:3001",
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
