const { defineConfig } = require("@playwright/test");

module.exports = defineConfig({
  testDir: "./e2e",
  timeout: 30_000,
  retries: 0,
  workers: 1,
  use: {
    baseURL: "http://127.0.0.1:3001",
    headless: true,
  },
  projects: [
    {
      name: "chromium",
      use: { browserName: "chromium" },
      grepInvert: /@devnet/,
    },
    {
      name: "devnet",
      use: { browserName: "chromium" },
      grep: /@devnet/,
      timeout: 180_000,
    },
  ],
  webServer: {
    command:
      "bin/rails db:test:prepare && bin/rails runner e2e/seed.rb && bin/rails server -p 3001 -e test",
    url: "http://127.0.0.1:3001/up",
    reuseExistingServer: !process.env.CI,
    timeout: 30_000,
    env: { RAILS_ENV: "test" },
  },
});
