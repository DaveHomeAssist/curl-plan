const { test, expect } = require("@playwright/test");

async function openClassic(page) {
  const pageErrors = [];
  page.on("pageerror", (error) => pageErrors.push(error.message));
  await page.goto("/classic/");
  await page.evaluate(() => localStorage.clear());
  await page.reload();
  return pageErrors;
}

async function openIceDraft(page) {
  await page.locator("#tab-ice").click();
  await page.locator("#addNoteBtn").click();
}

async function fillIceDraft(page, overrides = {}) {
  const draft = {
    date: "2026-08-24",
    rink: "Audit Club",
    sheet: "4",
    notes: "P1 regression fixture",
    ...overrides
  };
  await page.locator("#ice-date").fill(draft.date);
  await page.locator("#ice-rink").fill(draft.rink);
  await page.locator("#ice-sheet").fill(draft.sheet);
  await page.locator("[data-speed='4']").click();
  await page.locator("#ice-notes-text").fill(draft.notes);
}

test("Classic Ice Notes creates, edits, and survives reload", async ({ page }) => {
  const pageErrors = await openClassic(page);
  await openIceDraft(page);
  await fillIceDraft(page);
  await page.locator("#iceSaveBtn").click();

  await expect(page.locator("#modal-ice")).toBeHidden();
  await expect(page.locator("#ice-list")).toContainText("Audit Club");
  await expect.poll(() => page.evaluate(() => {
    const stored = JSON.parse(localStorage.getItem("curlplan-v1") || "null");
    return stored?.ice?.find((entry) => entry.rink === "Audit Club")?.notes || "";
  })).toBe("P1 regression fixture");

  await page.reload();
  await page.locator("#tab-ice").click();
  await expect(page.locator("#ice-list")).toContainText("Audit Club");
  await page.locator("#ice-list [data-open-modal='ice']").filter({ hasText: "Edit" }).first().click();
  await page.locator("#ice-rink").fill("Audit Club Updated");
  await page.locator("#ice-notes-text").fill("Edited and durable");
  await page.locator("#iceSaveBtn").click();

  await page.reload();
  await page.locator("#tab-ice").click();
  await expect(page.locator("#ice-list")).toContainText("Audit Club Updated");
  await expect(page.locator("#ice-list")).toContainText("Edited and durable");
  expect(pageErrors, `Classic raised: ${pageErrors.join(" | ")}`).toEqual([]);
});

test("Classic Ice Notes rejects an invalid draft without mutating storage", async ({ page }) => {
  await openClassic(page);
  const before = await page.evaluate(() => JSON.parse(localStorage.getItem("curlplan-v1") || "null")?.ice?.length || 0);
  await openIceDraft(page);
  await page.locator("#ice-date").fill("");
  await page.locator("#ice-rink").fill("Invalid Club");
  await page.locator("#iceSaveBtn").click();

  await expect(page.locator("#modal-ice")).toBeVisible();
  await expect(page.locator("#ice-date")).toHaveAttribute("aria-invalid", "true");
  await expect(page.locator("#statusBar")).toContainText("date is required");
  await expect.poll(() => page.evaluate(() => JSON.parse(localStorage.getItem("curlplan-v1") || "null")?.ice?.length || 0)).toBe(before);
});

test("Classic Ice Notes retains the draft and never reports success after a failed write", async ({ page }) => {
  await openClassic(page);
  await openIceDraft(page);
  await fillIceDraft(page, { rink: "Quota Failure Club" });
  await page.evaluate(() => {
    Storage.prototype.setItem = function setItem() {
      throw new DOMException("Audit quota failure", "QuotaExceededError");
    };
  });
  await page.locator("#iceSaveBtn").click();

  await expect(page.locator("#modal-ice")).toBeVisible();
  await expect(page.locator("#ice-rink")).toHaveValue("Quota Failure Club");
  await expect(page.locator("#statusBar")).toContainText("could not be saved");
  await expect(page.locator(".toast-copy")).not.toHaveText("Ice notes saved");
  await expect.poll(() => page.evaluate(() => {
    const stored = JSON.parse(localStorage.getItem("curlplan-v1") || "null");
    return stored?.ice?.some((entry) => entry.rink === "Quota Failure Club") || false;
  })).toBe(false);
});
