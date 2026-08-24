const { test, expect } = require("@playwright/test");

async function freshRoot(page) {
  await page.goto("/");
  await page.evaluate(() => localStorage.clear());
  await page.reload();
  await page.getByRole("button", { name: "Explore the demo" }).click();
}

async function openNewSpiel(page, name) {
  await page.getByRole("tab", { name: "Spiels" }).click();
  await page.getByRole("button", { name: "New spiel" }).click();
  await page.getByLabel("Spiel name").fill(name);
  await page.getByRole("button", { name: "Add spiel" }).click();
}

test("quota failure is visible, preserves durable state, and offers a durable retry", async ({ page }) => {
  await freshRoot(page);
  await page.evaluate(() => {
    const original = Storage.prototype.setItem;
    window.__restoreSetItem = () => { Storage.prototype.setItem = original; };
    Storage.prototype.setItem = function (key, value) {
      if (String(key).startsWith("curlplan-hifi-state-v1:")) {
        throw new DOMException("Quota exceeded", "QuotaExceededError");
      }
      return original.call(this, key, value);
    };
  });

  await openNewSpiel(page, "Not Yet Durable");
  await expect(page.getByRole("alert")).toContainText("could not be saved");
  await expect(page.getByText("Not Yet Durable", { exact: true })).toHaveCount(0);
  await page.evaluate(() => window.__restoreSetItem());
  await page.getByRole("button", { name: "Retry save" }).click();
  await expect(page.getByRole("status")).toContainText("saved");
  await expect(page.getByText("Not Yet Durable", { exact: true })).toBeVisible();
  await page.reload();
  await expect(page.getByText("Not Yet Durable", { exact: true })).toBeVisible();
});
test("disabled storage and malformed JSON are reported without replacing in-memory defaults", async ({ page }) => {
  await page.goto("/");
  await page.evaluate(() => {
    localStorage.clear();
    localStorage.setItem("curlplan-hifi-auth-v1", JSON.stringify({ session: "demo" }));
    localStorage.setItem("curlplan-hifi-state-v1:demo", "{broken json");
  });
  await page.reload();
  await expect(page.getByRole("alert")).toContainText("stored CurlPlan data is malformed");
  await expect(page.getByRole("tab", { name: "Passport" })).toBeVisible();

  await page.evaluate(() => {
    const original = Storage.prototype.setItem;
    window.__restoreSetItem = () => { Storage.prototype.setItem = original; };
    Storage.prototype.setItem = function () { throw new DOMException("Disabled", "SecurityError"); };
  });
  await openNewSpiel(page, "Blocked by Storage");
  await expect(page.getByRole("alert")).toContainText("browser storage is unavailable");
  await expect(page.getByText("Blocked by Storage", { exact: true })).toHaveCount(0);
});
