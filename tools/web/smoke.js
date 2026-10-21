// Boots the exported web build in headless Chromium on a phone-sized screen and
// checks that it starts: the engine reports its renderer, the page raises no
// error, and the screenshot shows a rendered scene rather than a blank canvas.
// It does not judge gameplay or feel.
//
// Usage: node tools/web/smoke.js build/web [screenshot-folder]
//   Needs the `playwright` package (NODE_PATH may point at it).
//   CHROMIUM_PATH picks a browser binary instead of Playwright's own.
const fs = require('fs');
const http = require('http');
const path = require('path');
const { chromium } = require('playwright');

const root = path.resolve(process.argv[2] || 'build/web');
const shots = path.resolve(process.argv[3] || 'build/web-smoke');
const TYPES = { '.html': 'text/html', '.js': 'text/javascript', '.wasm': 'application/wasm', '.png': 'image/png', '.pck': 'application/octet-stream' };
// A flat or blank 844x390 screenshot compresses to a few kilobytes.
const MIN_SCREENSHOT_BYTES = 30000;

function serve() {
	return new Promise((resolve) => {
		const server = http.createServer((request, response) => {
			const name = request.url.split('?')[0] === '/' ? '/index.html' : request.url.split('?')[0];
			const file = path.join(root, path.normalize(name));
			if (!file.startsWith(root) || !fs.existsSync(file)) { response.writeHead(404); response.end(); return; }
			response.writeHead(200, { 'Content-Type': TYPES[path.extname(file)] || 'application/octet-stream' });
			fs.createReadStream(file).pipe(response);
		});
		server.listen(0, '127.0.0.1', () => resolve(server));
	});
}

(async () => {
	fs.mkdirSync(shots, { recursive: true });
	const server = await serve();
	const url = `http://127.0.0.1:${server.address().port}/index.html`;
	const browser = await chromium.launch({
		executablePath: process.env.CHROMIUM_PATH || undefined,
		args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'],
	});
	const page = await browser.newPage({ viewport: { width: 844, height: 390 }, hasTouch: true, isMobile: true });
	const logs = [];
	const errors = [];
	page.on('console', (message) => logs.push(message.text()));
	page.on('pageerror', (error) => errors.push(error.message));
	await page.goto(url);

	const started = Date.now();
	while (!logs.some((line) => line.includes('Compatibility')) && Date.now() - started < 90000) {
		await page.waitForTimeout(500);
	}
	await page.waitForTimeout(15000); // Let the scene load and a few frames render.
	const shot = path.join(shots, 'web-smoke.png');
	await page.screenshot({ path: shot });
	const size = fs.statSync(shot).size;
	await browser.close();
	server.close();

	const failures = [];
	if (!logs.some((line) => line.includes('Godot Engine'))) failures.push('the engine never started');
	if (!logs.some((line) => line.includes('Compatibility'))) failures.push('no renderer was reported within 90 s');
	if (errors.length) failures.push(`page errors: ${errors.slice(0, 3).join(' | ')}`);
	if (size < MIN_SCREENSHOT_BYTES) failures.push(`the screenshot looks blank (${size} bytes)`);
	console.log(logs.slice(0, 6).join('\n'));
	console.log(`screenshot: ${shot} (${size} bytes)`);
	if (failures.length) { console.error('web smoke test FAILED: ' + failures.join('; ')); process.exit(1); }
	console.log('web smoke test passed');
})();
