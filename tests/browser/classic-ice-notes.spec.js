const { test, expect } = require("@playwright/test");

test("Classic Ice Notes saves a valid draft without a runtime exception", async ({ page }) => {
  test.fail(true, "P0 baseline: Classic save raises ReferenceError: existing is not defined; P1 must remove this annotation.");
  const pageErrors = [];
  page.on("pageerror", (error) => pageErrors.push(error.message));
  await page.addInitScript(() => localStorage.clear());
  await page.goto("/classic/");

  await page.locator("#tab-ice").click();
  await page.locator("#addNoteBtn").click();
  await page.locator("#ice-date").fill("2026-08-24");
  await page.locator("#ice-rink").fill("Audit Club");
  await page.locator("#ice-sheet").fill("4");
  await page.locator("[data-speed='4']").click();
  await page.locator("#ice-notes-text").fill("P0 regression fixture");
  await page.locator("#iceSaveBtn").click();

  expect(pageErrors, `Classic save raised: ${pageErrors.join(" | ")}`).toEqual([]);
  await expect.poll(() => page.evaluate(() => {
    const stored = JSON.parse(localStorage.getItem("curlplan-v1") || "null");
    return stored?.ice?.some((entry) => entry.rink === "Audit Club") || false;
  })).toBe(true);
});
