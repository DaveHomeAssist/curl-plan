const { test, expect } = require("@playwright/test");

async function freshClassic(page) {
  await page.goto("/classic/");
  await page.evaluate(() => localStorage.clear());
  await page.reload();
}

test("Classic reports corrupt primary storage without overwriting it", async ({ page }) => {
  await page.addInitScript(() => localStorage.setItem("curlplan-v1", "{not-json"));
  await page.goto("/classic/");

  await expect(page.locator("#storageRecovery")).toBeVisible();
  await expect(page.locator("#storageRecovery")).toContainText("could not be read");
  expect(await page.evaluate(() => localStorage.getItem("curlplan-v1"))).toBe("{not-json");
});

test("Classic reports unavailable primary storage explicitly", async ({ page }) => {
  await page.addInitScript(() => {
    Storage.prototype.getItem = function getItem() {
      throw new DOMException("Audit storage denial", "SecurityError");
    };
  });
  await page.goto("/classic/");

  await expect(page.locator("#storageRecovery")).toBeVisible();
  await expect(page.locator("#storageRecovery")).toContainText("storage is unavailable");
});

test("Classic reset snapshot survives reload and restores after confirmation", async ({ page }) => {
  await freshClassic(page);
  await page.locator("#tab-ice").click();
  await page.locator("#addNoteBtn").click();
  await page.locator("#ice-date").fill("2026-08-24");
  await page.locator("#ice-rink").fill("Restore Me Club");
  await page.locator("#iceSaveBtn").click();
  await expect(page.locator("#ice-list")).toContainText("Restore Me Club");

  page.once("dialog", (dialog) => dialog.accept());
  await page.locator("#settingsBtn").click();
  await page.locator("#resetBtn").click();
  await expect(page.locator("#resetRecovery")).toBeVisible();
  await expect(page.locator("#ice-list")).not.toContainText("Restore Me Club");

  await page.reload();
  await expect(page.locator("#resetRecovery")).toBeVisible();
  page.once("dialog", (dialog) => dialog.accept());
  await page.locator("#restoreResetBtn").click();
  await page.locator("#tab-ice").click();
  await expect(page.locator("#ice-list")).toContainText("Restore Me Club");
  await expect(page.locator("#resetRecovery")).toBeHidden();
});

test("Classic overlays have one owner, trap focus, close from Escape, and restore the invoker", async ({ page }) => {
  await freshClassic(page);
  const overlays = page.locator(".overlay");
  await expect(overlays).toHaveCount(7);
  for (let index = 0; index < await overlays.count(); index += 1) {
    const overlay = overlays.nth(index);
    await expect(overlay).toBeHidden();
    await expect(overlay).toHaveAttribute("inert", "");
    await expect(overlay).toHaveAttribute("aria-hidden", "true");
  }

  const invoker = page.locator("#quickAddBtn");
  await invoker.focus();
  await invoker.click();
  await expect(page.locator("#modal-event")).toBeVisible();
  await expect(page.locator("#modal-event")).not.toHaveAttribute("inert", "");
  await expect.poll(() => page.evaluate(() => document.querySelector("#modal-event")?.contains(document.activeElement))).toBe(true);

  await page.keyboard.press("?");
  await expect(page.locator("#modal-event")).toBeHidden();
  await expect(page.locator("#modal-shortcuts")).toBeVisible();
  await expect(page.locator(".overlay.is-open")).toHaveCount(1);
  await page.keyboard.press("Tab");
  await expect.poll(() => page.evaluate(() => document.querySelector("#modal-shortcuts")?.contains(document.activeElement))).toBe(true);
  await page.keyboard.press("Escape");
  await expect(page.locator("#modal-shortcuts")).toBeHidden();
  await expect(invoker).toBeFocused();

  await page.locator("#shortcutHelpBtn").evaluate((button) => button.click());
  await expect(page.locator("#modal-shortcuts")).toBeVisible();
  await page.locator("#modal-shortcuts").evaluate((overlay) => overlay.click());
  await expect(page.locator("#modal-shortcuts")).toBeHidden();
});

test("Classic calendar detail always belongs to the active filter result", async ({ page }) => {
  await freshClassic(page);
  await page.locator("#tab-calendar").click();
  await page.locator("[data-filter='league']").click();
  await expect(page.locator("#event-list .event-item")).toHaveCount(1);
  await expect(page.locator("#eventDetail")).toContainText("Team Night");

  await page.locator("[data-filter='practice']").click();
  await expect(page.locator("#event-list .event-item")).toHaveCount(1);
  await expect(page.locator("#eventDetail")).toContainText("Morning Session");
  await expect(page.locator("#eventDetail")).not.toContainText("Team Night");
});

test("Classic custom navigation controls use native interactive elements", async ({ page }) => {
  await freshClassic(page);
  await page.locator("#tab-calendar").click();
  await expect(page.locator("#event-list .event-item").first()).toHaveJSProperty("tagName", "BUTTON");
  await page.locator("#tab-games").click();
  await expect(page.locator("#game-tbody [data-action='toggle-game-expand']").first()).toHaveJSProperty("tagName", "BUTTON");
  await page.locator("#tab-planner").click();
  await page.evaluate(() => {
    plannerDate = "2026-08-25";
    renderPlannerEntries();
  });
  await expect(page.locator("#planner-entries [data-action='planner-jump']").first()).toHaveJSProperty("tagName", "BUTTON");
});

test("Classic planner save updates its scoped view without a full application render", async ({ page }) => {
  const pageErrors = [];
  page.on("pageerror", (error) => pageErrors.push(error.message));
  await freshClassic(page);
  await page.locator("#tab-planner").click();
  await page.evaluate(() => {
    window.__classicFullRenderCount = 0;
    window.renderAll = () => {
      window.__classicFullRenderCount += 1;
    };
  });
  await page.locator("#pg-rink").fill("Scoped Render Club");
  await page.locator("#savePlannerBtn").click();

  await expect.poll(() => page.evaluate(() => JSON.parse(localStorage.getItem("curlplan-v1") || "null")?.plannerEntries?.some((entry) => entry.rink === "Scoped Render Club") || false)).toBe(true);
  expect(await page.evaluate(() => window.__classicFullRenderCount)).toBe(0);
  await expect(page.locator("#plannerStateStrip")).toContainText("Planner entry in progress");
  expect(pageErrors).toEqual([]);
});
