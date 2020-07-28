// speedindex.js
// author: bashow
// 2020/03/24

// Requirements:
// sudo apt install chromium-browser
// sudo apt install npm
// npm i puppeteer-core
// npm i speedline

// How to use:
// node speedindex.js <url>
// OUTPUT [speedindex]

const puppeteer = require('puppeteer-core');
const speedline = require('speedline');

var url = process.argv[2];
var traceJson = process.argv[3];

(async () => {
  const browser = await puppeteer.launch({
                          executablePath: '/usr/bin/chromium-browser',
                          args: ['--no-sandbox']});
  const page = await browser.newPage();
  await page.setDefaultNavigationTimeout(60000);
  await page.tracing.start({
    path: traceJson,
    screenshots: true
  })

  await page.goto(url);
  await page.tracing.stop();
  await browser.close();

  speedline(traceJson).then(res => {
      console.log(res.speedIndex)
  });

})();
