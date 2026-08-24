const { test, expect } = require("@playwright/test");
const AxeBuilder = require("@axe-core/playwright").default;

async function freshRoot(page) {
  await page.goto("/");
  await page.evaluate(() => localStorage.clear());
  await page.reload();
  await page.getByRole("button", { name: "Explore the demo" }).click();
}

async function expectNoAxeViolations(page, context) {
  const results = await new AxeBuilder({ page }).analyze();
  expect(results.violations, `${context}: ${JSON.stringify(results.violations, null, 2)}`).toEqual([]);
}

test("root navigation and Locker filters expose state and support arrow keys", async ({ page }) => {
  await freshRoot(page);

  const primary = page.getByRole("tablist", { name: "Primary" });
  await expect(primary).toBeVisible();
  const passport = page.getByRole("tab", { name: "Passport" });
  await expect(passport).toHaveAttribute("aria-selected", "true");
  await passport.focus();
  await page.keyboard.press("ArrowRight");
  await expect(page.getByRole("tab", { name: "Locker" })).toBeFocused();
  await expect(page.getByRole("tab", { name: "Locker" })).toHaveAttribute("aria-selected", "true");

  const filters = page.getByRole("tablist", { name: "Locker posts" });
  await expect(filters).toBeVisible();
  await expect(page.getByRole("tab", { name: "Following" })).toHaveAttribute("aria-selected", "true");
  await page.getByRole("tab", { name: "Following" }).focus();
  await page.keyboard.press("ArrowRight");
  await expect(page.getByRole("tab", { name: "Discover" })).toBeFocused();
  await expect(page.getByRole("tab", { name: "Discover" })).toHaveAttribute("aria-selected", "true");
});

test("root-created spiel and curler records can be created, corrected, deleted, and reloaded", async ({ page }) => {
  await freshRoot(page);

  await page.getByRole("tab", { name: "Spiels" }).click();
  await page.getByRole("button", { name: "New spiel" }).click();
  await page.getByLabel("Spiel name").fill("Audit Open");
  await page.getByLabel("Spiel location").fill("Albany, NY");
  await page.getByLabel("Spiel dates").fill("SEP 2–4");
  await page.getByRole("button", { name: "Add spiel" }).click();
  await expect(page.getByRole("status")).toContainText("Spiel added and saved");
  await page.getByRole("button", { name: "Edit Audit Open" }).click();
  await page.getByLabel("Spiel name").fill("Audit Open Revised");
  await page.getByRole("button", { name: "Save spiel" }).click();
  await expect(page.getByText("Audit Open Revised", { exact: true })).toBeVisible();
  await page.reload();
  await expect(page.getByText("Audit Open Revised", { exact: true })).toBeVisible();
  await page.getByRole("button", { name: "Delete Audit Open Revised" }).click();
  await page.getByRole("button", { name: "Confirm delete spiel" }).click();
  await expect(page.getByText("Audit Open Revised", { exact: true })).toHaveCount(0);
  await page.reload();
  await expect(page.getByText("Audit Open Revised", { exact: true })).toHaveCount(0);

  await page.getByRole("tab", { name: "Roster" }).click();
  await page.getByRole("button", { name: "Add curler" }).click();
  await page.getByLabel("Curler name").fill("Taylor Audit");
  await page.getByLabel("Curler club").fill("Audit CC");
  await page.locator("#sheet2").getByRole("button", { name: "Add curler" }).click();
  await page.getByRole("button", { name: "Edit Taylor Audit" }).click();
  await page.getByLabel("Curler name").fill("Taylor Revised");
  await page.getByRole("button", { name: "Save curler" }).click();
  await expect(page.getByText("Taylor Revised", { exact: true })).toBeVisible();
  await page.reload();
  await expect(page.getByText("Taylor Revised", { exact: true })).toBeVisible();
  await page.getByRole("button", { name: "Delete Taylor Revised" }).click();
  await page.getByRole("button", { name: "Confirm delete curler" }).click();
  await expect(page.getByText("Taylor Revised", { exact: true })).toHaveCount(0);
  await page.reload();
  await expect(page.getByText("Taylor Revised", { exact: true })).toHaveCount(0);
});

test("root primary actions remain visible at a 200 percent mobile zoom equivalent", async ({ page }) => {
  // A 390 CSS-pixel mobile viewport at 200% browser zoom exposes about 195 CSS
  // pixels. This exercises the reflow boundary without relying on browser UI.
  await page.setViewportSize({ width: 195, height: 406 });
  await freshRoot(page);
  expect(await page.evaluate(() => document.documentElement.scrollWidth <= document.documentElement.clientWidth)).toBe(true);
  for (const tab of await page.getByRole("tablist", { name: "Primary" }).getByRole("tab").all()) {
    await expect(tab).toBeVisible();
    const box = await tab.boundingBox();
    expect(box.x).toBeGreaterThanOrEqual(0);
    expect(box.x + box.width).toBeLessThanOrEqual(195);
  }
  await page.getByRole("tab", { name: "Spiels" }).click();
  await expect(page.getByRole("button", { name: "New spiel" })).toBeVisible();
  await page.getByRole("button", { name: "New spiel" }).click();
  await expect(page.locator("#sheet2").getByRole("button", { name: "Add spiel" })).toBeVisible();
  expect(await page.evaluate(() => document.documentElement.scrollWidth <= document.documentElement.clientWidth)).toBe(true);
});

for (const theme of ["ice", "arena"]) {
  test(`root ${theme} Passport, Locker, contribution, and correction surfaces pass Axe`, async ({ page }) => {
    await freshRoot(page);
    for (const accent of ["House red", "House blue", "Granite"]) {
      await page.evaluate(({ value, accentName }) => {
        prefs.theme = value;
        prefs.accent = accentName;
        applyPrefs();
        syncSettings();
      }, { value: theme, accentName: accent });
      await expectNoAxeViolations(page, `${theme} ${accent} Passport`);
    }
    await page.evaluate(() => {
      prefs.accent = "House red";
      applyPrefs();
      syncSettings();
    });

    await page.getByRole("tab", { name: "Locker" }).click();
    await expectNoAxeViolations(page, `${theme} Locker`);
    await page.getByRole("button", { name: "New post" }).click();
    await expectNoAxeViolations(page, `${theme} contribution sheet`);
    await page.keyboard.press("Escape");

    await page.getByRole("tab", { name: "Spiels" }).click();
    await page.getByRole("button", { name: "New spiel" }).click();
    await expectNoAxeViolations(page, `${theme} create correction sheet`);
    await page.getByLabel("Spiel name").fill(`${theme} Axe Spiel`);
    await page.locator("#sheet2").getByRole("button", { name: "Add spiel" }).click();
    await expectNoAxeViolations(page, `${theme} correction list`);
    await page.getByRole("button", { name: `Edit ${theme} Axe Spiel` }).click();
    await expectNoAxeViolations(page, `${theme} edit correction sheet`);
  });
}
