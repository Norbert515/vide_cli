#!/usr/bin/env node

// Generates landing/assets/og-image.png by rendering og.html with Puppeteer.
//
// Usage:
//   cd landing && npm install && node generate-og.mjs
//
// Optional flags:
//   --time <float>   Vortex animation time (default: 2.5)
//   --output <path>  Output file path (default: assets/og-image.png)

import puppeteer from 'puppeteer';
import { fileURLToPath } from 'url';
import path from 'path';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

function parseArgs() {
  const args = process.argv.slice(2);
  const opts = { time: 2.5, output: path.join(__dirname, 'assets', 'og-image.png') };

  for (let i = 0; i < args.length; i++) {
    if (args[i] === '--time' && args[i + 1]) {
      opts.time = parseFloat(args[++i]);
    } else if (args[i] === '--output' && args[i + 1]) {
      opts.output = args[++i];
    }
  }

  return opts;
}

async function main() {
  const opts = parseArgs();

  const browser = await puppeteer.launch({
    headless: true,
    args: ['--no-sandbox', '--disable-setuid-sandbox'],
  });

  const page = await browser.newPage();
  await page.setViewport({ width: 1200, height: 630 });

  const ogPath = path.join(__dirname, 'og.html');
  await page.goto(`file://${ogPath}`, { waitUntil: 'networkidle0' });

  // Wait for fonts to load and vortex to initialize
  await page.waitForFunction('typeof window.__renderVortex === "function"', {
    timeout: 10000,
  });

  // Render the vortex at the desired animation time
  await page.evaluate((time) => window.__renderVortex(time), opts.time);

  // Small delay so the composited frame is ready
  await new Promise((r) => setTimeout(r, 200));

  await page.screenshot({ path: opts.output, type: 'png' });

  await browser.close();

  console.log(`OG image saved to ${opts.output}`);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
