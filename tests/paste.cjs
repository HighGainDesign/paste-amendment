// Run with Node and Playwright available via NODE_PATH. No test framework needed.
// Removing propagation interception should fail these real browser paste checks.
const { chromium } = require('playwright');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const http = require('node:http');

(async () => {
  const channel = process.env.PASTE_AMENDMENT_TEST_CHANNEL === 'chromium' ? undefined : 'chrome';
  const browser = await chromium.launch({ channel, headless: true });
  const server = http.createServer((req, res) => {
    const fixture = req.url === '/frame.html' ? 'frame.html' : 'blocked-paste.html';
    res.setHeader('Content-Type', 'text/html; charset=utf-8');
    res.end(fs.readFileSync(path.join(__dirname, fixture)));
  });
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  try {
    const context = await browser.newContext();
    const script = path.join(__dirname, '../extension/content.js');
    if (fs.existsSync(script)) await context.addInitScript({ path: script });
    const page = await context.newPage();
    await page.goto(`http://127.0.0.1:${server.address().port}/blocked-paste.html`);
    const modifier = process.platform === 'darwin' ? 'Meta' : 'Control';
    const source = page.locator('#source');
    await source.focus();
    await page.keyboard.press(`${modifier}+a`);
    await page.keyboard.press(`${modifier}+c`);

    // Real trusted paste must insert text, not merely un-cancel a synthetic event.
    for (const id of ['inline', 'capture', 'beforeinput', 'keyboard', 'password', 'normal', 'added', 'shadowed']) {
      const field = page.locator(`#${id}`);
      await field.focus();
      await page.keyboard.press(`${modifier}+v`);
      assert.equal(await field.inputValue(), 'Paste works ✓', `${id}: native paste remains blocked`);
      console.log(`PASS native paste: ${id}`);
    }
    const editable = page.locator('#editable');
    await editable.focus();
    await page.keyboard.press(`${modifier}+v`);
    assert.equal(await editable.innerText(), 'Paste works ✓');
    console.log('PASS native paste: contenteditable');
    const framed = page.frameLocator('iframe').locator('#framed');
    await framed.focus();
    await page.keyboard.press(`${modifier}+v`);
    assert.equal(await framed.inputValue(), 'Paste works ✓');
    console.log('PASS native paste: iframe');

    const normal = page.locator('#normal');
    await normal.fill('replace me');
    await normal.focus();
    await page.keyboard.press(`${modifier}+a`);
    await page.keyboard.press(`${modifier}+v`);
    assert.equal(await normal.inputValue(), 'Paste works ✓');
    await page.keyboard.press(`${modifier}+z`);
    assert.equal(await normal.inputValue(), 'replace me', 'native undo must survive');
    await normal.fill('');
    const inputEvents = await page.evaluate(() => window.inputEvents);
    await normal.pressSequentially('abc');
    assert.equal(await normal.inputValue(), 'abc');
    assert.equal(await page.evaluate(() => window.inputEvents), inputEvents + 3);
    console.log('PASS selection replacement, undo, typing, input notifications');

    const untouched = await page.evaluate(() => {
      const results = {};
      for (const id of ['readonly', 'disabled', 'checkbox', 'noneditable']) {
        const el = document.querySelector(`#${id}`);
        let called = false;
        el.addEventListener('paste', e => { called = true; e.preventDefault(); }, { once: true });
        el.dispatchEvent(new ClipboardEvent('paste', { bubbles: true, cancelable: true, composed: true }));
        results[id] = called;
      }
      const field = document.querySelector('#normal');
      let seen = 0;
      field.addEventListener('keydown', () => seen++, { once: true });
      field.dispatchEvent(new KeyboardEvent('keydown', { key: 'a', bubbles: true }));
      let inputSeen = false;
      field.addEventListener('beforeinput', () => { inputSeen = true; }, { once: true });
      field.dispatchEvent(new InputEvent('beforeinput', { inputType: 'insertText', bubbles: true }));
      return { ...results, otherKey: seen === 1, ordinaryBeforeinput: inputSeen };
    });
    assert.deepEqual(untouched, { readonly: true, disabled: true, checkbox: true, noneditable: true, otherKey: true, ordinaryBeforeinput: true });
    console.log('PASS noneditable controls and ordinary event handlers preserved');
  } finally {
    await browser.close();
    await new Promise(resolve => server.close(resolve));
  }
})().catch(error => { console.error(error); process.exitCode = 1; });
