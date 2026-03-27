import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

export default defineConfig({
  plugins: [react()],
  server: {
    allowedHosts: [".falafel.com.br"],
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
