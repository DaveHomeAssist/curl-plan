const { test, expect } = require("@playwright/test");

test("browser stress harness has no failing assertions", async ({ page }) => {
  const query = process.env.CURLPLAN_STRESS_NEGATIVE === "1" ? "?intentionalFailure=1" : "";
  await page.goto(`/tests/stress-test.html${query}`);

  const summary = page.locator("#summary .summary");
  await expect(summary).toBeVisible();
  await expect(summary).toHaveClass(/all-pass/);
  await expect(summary).toContainText("0 failed");
});
