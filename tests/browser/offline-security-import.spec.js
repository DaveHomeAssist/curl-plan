const { test, expect } = require("@playwright/test");
const fs = require("node:fs");
const path = require("node:path");

const repoRoot = path.resolve(__dirname, "../..");

test("manifests are product-scoped and every declared install asset is available", async ({ page, request }) => {
  for (const manifestPath of ["/manifest.webmanifest", "/classic/manifest.webmanifest"]) {
    const response = await request.get(manifestPath);
    expect(response.ok()).toBe(true);
    const manifest = await response.json();
    expect(manifest.name).toMatch(/^CurlPlan/);
    expect(manifest.display).toBe("standalone");
    expect(manifest.start_url).toMatch(/^\.\//);
    expect(manifest.scope).toMatch(/^\.\//);
    expect(manifest.icons.length).toBeGreaterThanOrEqual(2);
    for (const icon of manifest.icons) {
      const url = new URL(icon.src, new URL(manifestPath, "http://127.0.0.1:4173"));
      expect((await request.get(url.pathname)).ok(), `${url.pathname} should load`).toBe(true);
    }
  }
  await page.goto("/");
  await expect(page.locator('link[rel="manifest"]')).toHaveAttribute("href", "manifest.webmanifest");
  await page.goto("/classic/");
  await expect(page.locator('link[rel="manifest"]')).toHaveAttribute("href", "manifest.webmanifest");
});

test("service-worker upgrades delete only their own prefixed caches", async ({ page }) => {
  await page.goto("/");
  await page.evaluate(async () => {
    await caches.open("curlplan-root-old-test");
    await caches.open("curlplan-classic-preserve-test");
    await caches.open("unrelated-preserve-test");
    const registration = await navigator.serviceWorker.register(`/sw.js?audit=${Date.now()}`, { scope: "/" });
    const worker = registration.installing || registration.waiting || registration.active;
    if (worker && worker.state !== "activated") {
      await new Promise(resolve => worker.addEventListener("statechange", () => worker.state === "activated" && resolve()));
    }
  });
  let keys = await page.evaluate(() => caches.keys());
  expect(keys).not.toContain("curlplan-root-old-test");
  expect(keys).toContain("curlplan-classic-preserve-test");
  expect(keys).toContain("unrelated-preserve-test");

  await page.goto("/classic/");
  await page.evaluate(async () => {
    await caches.open("curlplan-classic-old-test");
    await caches.open("curlplan-root-preserve-test");
    const registration = await navigator.serviceWorker.register(`/classic/sw.js?audit=${Date.now()}`, { scope: "/classic/" });
    const worker = registration.installing || registration.waiting || registration.active;
    if (worker && worker.state !== "activated") {
      await new Promise(resolve => worker.addEventListener("statechange", () => worker.state === "activated" && resolve()));
    }
  });
  keys = await page.evaluate(() => caches.keys());
  expect(keys).not.toContain("curlplan-classic-old-test");
  expect(keys).toContain("curlplan-root-preserve-test");
  expect(keys).toContain("unrelated-preserve-test");
});

test("each installed app has its own offline shell and never serves the other shell", async ({ browser }) => {
  const rootContext = await browser.newContext();
  const root = await rootContext.newPage();
  await root.goto("/");
  await root.waitForFunction(() => navigator.serviceWorker.ready.then(() => true));
  await root.reload();
  await rootContext.setOffline(true);
  await root.reload();
  await expect(root).toHaveTitle("CurlPlan");
  await expect(root.goto("/classic/not-a-real-route", { waitUntil: "domcontentloaded" })).rejects.toThrow();
  await rootContext.close();

  const classicContext = await browser.newContext();
  const classic = await classicContext.newPage();
  await classic.goto("/classic/");
  await classic.waitForFunction(() => navigator.serviceWorker.ready.then(() => true));
  await classic.reload();
  await classicContext.setOffline(true);
  await classic.reload();
  await expect(classic).toHaveTitle("CurlPlan Classic");
  expect(await classic.evaluate(() => fetch("/").then(() => "wrong-shell").catch(() => "failed"))).toBe("failed");
  await classicContext.close();
});

test("CSP, import limits, and club URL verifier reject unsafe regressions", async ({ page }) => {
  const rootHtml = fs.readFileSync(path.join(repoRoot, "index.html"), "utf8");
  const classicHtml = fs.readFileSync(path.join(repoRoot, "classic/index.html"), "utf8");
  for (const html of [rootHtml, classicHtml]) {
    expect(html).toContain("Content-Security-Policy");
    expect(html).toContain("object-src 'none'");
    expect(html).toContain("base-uri 'self'");
    expect(html).toContain("form-action 'self'");
    expect(html).toContain("frame-src 'none'");
  }

  const clubData = JSON.parse(fs.readFileSync(path.join(repoRoot, "data/curling-clubs.json"), "utf8"));
  const insecure = clubData.clubs.filter(club => club.website && /^http:\/\//i.test(club.website));
  expect(insecure).toEqual([]);

  await page.goto("/classic/");
  const oversize = await page.evaluate(() => {
    const file = new File(["x".repeat(2 * 1024 * 1024 + 1)], "too-large.json", { type: "application/json" });
    importData(file);
    return document.getElementById("statusBar").textContent;
  });
  expect(oversize).toMatch(/too large/i);

  await page.evaluate(() => {
    const deeplyNested = `${"[".repeat(30)}0${"]".repeat(30)}`;
    importData(new File([deeplyNested], "deep.json", { type: "application/json" }));
  });
  await expect(page.locator("#statusBar")).toContainText(/nesting limit/i);

  await page.evaluate(() => {
    const manyRecords = JSON.stringify({ events: Array.from({ length: 5001 }, (_, index) => ({ id: String(index) })) });
    importData(new File([manyRecords], "records.json", { type: "application/json" }));
  });
  await expect(page.locator("#statusBar")).toContainText(/record limit/i);

  await page.evaluate(() => {
    const manyKeys = {};
    for (let index = 0; index < 25001; index += 1) manyKeys[`key${index}`] = index;
    importData(new File([JSON.stringify(manyKeys)], "keys.json", { type: "application/json" }));
  });
  await expect(page.locator("#statusBar")).toContainText(/key limit/i);
});
