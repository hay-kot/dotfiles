// pr-record sign-in-and-search.mjs --url http://localhost:5173
// prepare runs before the recording starts, so the sign-in is not in the video.
export const start = "/login";
export const posterAt = 3;
export const hide = ["[data-testid=dev-toolbar]"];

export async function prepare({ page }) {
  await page.getByLabel("Email").fill("demo@example.com");
  await page.getByLabel("Password").fill("demo-password");
  await page.getByRole("button", { name: "Sign in" }).click();
  await page.waitForURL("**/home");
}

export default async function ({ page, d }) {
  await d.click(page.getByPlaceholder("Search"));
  await d.type("soup");
  await page.getByText("Chicken Soup").waitFor();
  await d.sleep(600);
  await d.click(page.getByText("Chicken Soup"));
  await d.settled();
  await d.sleep(900);
  await d.scrollTo(600, 1200);
  await d.sleep(800);
}
