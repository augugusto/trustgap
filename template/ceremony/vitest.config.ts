import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    globals: true,
    environment: 'node',
    include: ['test/**/*.test.ts'],
    // Tests that require Docker or a network are skipped by default
    testTimeout: 30_000,
  },
});
