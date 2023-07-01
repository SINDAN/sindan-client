// speedindex.js
// author: bashow
// 2020/09/23

// Requirements:
// brew install node
// npm i puppeteer
// npm i speedline

// How to use:
// node speedindex.js <url> <tmpfile>
// OUTPUT [speedindex]

const puppeteer = require('puppeteer');
const speedline = require('speedline');

var url = process.argv[2];
var traceJson = process.argv[3];

(async () => {
  const browser = await puppeteer.launch({
    headless: 'true',
    userDataDir: '/dev/null'
  });
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
