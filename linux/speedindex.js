// speedindex.js
// author: bashow
// 2021/12/08

// Requirements:
// sudo apt install chromium-browser
// sudo apt install npm
// npm i puppeteer-core
// npm i speedline

// How to use:
// node speedindex.js <url> <timeout>
// OUTPUT [speedindex]

const puppeteer = require('puppeteer-core');
const speedline = require('speedline');

var url = process.argv[2];
var timeOut = process.argv[3];
var traceJson = process.argv[4];

(async () => {
  const browser = await puppeteer.launch({
                          executablePath: '/usr/bin/chromium-browser',
                          userDataDir: '/dev/null',
                          args: ['--no-sandbox']});
  const page = await browser.newPage();
  try {
    await page.tracing.start({
      path: traceJson,
      screenshots: true
    })

    await page.goto(url, {
      waitUntil:'load',
      timeout: parseInt(timeOut, 10)
    });
    await page.tracing.stop();
    speedline(traceJson).then(res => {
      console.log(res.speedIndex)
    });
  } catch (e) {
    console.log(-1)
    // throw e;
  } finally {
    await browser.close();
  }
})();
