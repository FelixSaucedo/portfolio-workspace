import { defineConfig, loadEnv } from 'vite'
import vue from '@vitejs/plugin-vue'
import tailwindcss from '@tailwindcss/vite'

export default defineConfig(({ mode }) => {
  const env = loadEnv(mode, '.', '')
  return {
    plugins: [vue(), tailwindcss()],
    server: {
      host: '0.0.0.0',
      port: 5173,
      strictPort: true,
      watch: { usePolling: true, interval: 250 },
      proxy: {
        '/api': { target: env.API_PROXY_TARGET || 'http://host.docker.internal:8080', changeOrigin: true },
        '/storage': { target: env.API_PROXY_TARGET || 'http://host.docker.internal:8080', changeOrigin: true },
      },
    },
  }
})
