const { test, expect } = require("@playwright/test");
const AxeBuilder = require("@axe-core/playwright").default;

const overlayTypes = ["event", "game", "practice", "ice", "issue", "import-preview", "shortcuts"];

async function freshClassic(page) {
  await page.goto("/classic/");
  await page.evaluate(() => localStorage.clear());
  await page.reload();
}

for (const theme of ["light", "dark"]) {
  test(`Classic ${theme} theme overlays pass automated accessibility and keyboard checks`, async ({ page }) => {
    await freshClassic(page);
    await page.evaluate((nextTheme) => {
      applyTheme(nextTheme);
      saveUiPrefs({ ...uiPrefs, theme: nextTheme });
    }, theme);

    const pageResults = await new AxeBuilder({ page }).analyze();
    expect(pageResults.violations, `base page violations: ${JSON.stringify(pageResults.violations, null, 2)}`).toEqual([]);

    for (const type of overlayTypes) {
      await page.evaluate((overlayType) => openModal(overlayType), type);
      const overlay = page.locator(`#modal-${type}`);
      await expect(overlay).toBeVisible();
      await expect(overlay).toHaveAttribute("aria-hidden", "false");
      await expect.poll(() => page.evaluate((overlayId) => document.getElementById(overlayId)?.contains(document.activeElement), `modal-${type}`)).toBe(true);

      const results = await new AxeBuilder({ page })
        .include(`#modal-${type}`)
        .analyze();
      expect(results.violations, `${type} violations: ${JSON.stringify(results.violations, null, 2)}`).toEqual([]);

      await page.keyboard.press("Tab");
      await expect.poll(() => page.evaluate((overlayId) => document.getElementById(overlayId)?.contains(document.activeElement), `modal-${type}`)).toBe(true);
      await page.keyboard.press("Escape");
      await expect(overlay).toBeHidden();
      await expect(overlay).toHaveAttribute("inert", "");
      await expect(overlay).toHaveAttribute("aria-hidden", "true");
    }
  });
}

test("Classic tabs and Ice speed radio group support standard arrow-key operation", async ({ page }) => {
  await freshClassic(page);
  await page.locator("#tab-dashboard").focus();
  await page.keyboard.press("ArrowRight");
  await expect(page.locator("#tab-calendar")).toBeFocused();
  await expect(page.locator("#tab-calendar")).toHaveAttribute("aria-selected", "true");

  await page.locator("#tab-ice").click();
  await page.locator("#addNoteBtn").click();
  await page.locator("[data-speed='1']").focus();
  await page.keyboard.press("ArrowRight");
  await expect(page.locator("[data-speed='2']")).toBeFocused();
  await expect(page.locator("[data-speed='2']")).toHaveAttribute("aria-checked", "true");
  await expect(page.locator("[data-speed='1']")).toHaveAttribute("tabindex", "-1");
});
