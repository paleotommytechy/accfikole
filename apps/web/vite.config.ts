import path from 'path';
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

export default defineConfig(({ mode }) => {
    const previewAllowedHost = process.env.PREVIEW_ALLOWED_HOST;

    return {
      server: {
        port: 3000,
        host: '0.0.0.0',
        ...(previewAllowedHost ? { allowedHosts: [previewAllowedHost] } : {}),
      },
      plugins: [react()],
      resolve: {
        alias: {
          '@': path.resolve(__dirname, '.'),
        }
      }
    };
});
