// speedtest.js
// author: bashow
// 2020/07/18

// sudo apt18nstall chromium-browser
// sudo apt install npm

// npm i puppeteer
// npm i speedline

// node speedtest.js
// OUTPUT speedtest/IPv[4/6]_[RTT/JIT/DL/UL]

const puppeteer = require('puppeteer');
const fs = require('fs');

(async () => {
  const browser = await puppeteer.launch();
  const page = await browser.newPage();

  try {
    await page.goto('https://inonius.net/speedtest/', {
      waitUntil: 'networkidle0'
    });

    await page.waitFor(40000);

    let frames = page.frames();

    if (frames.find( f => f.url().indexOf("test-ipv6") > 0) ) {
      var ipv6frame = frames.find(
          f =>
            f.url().indexOf("test-ipv6") > 0);

      const ipv6rttItem = await ipv6frame.$('#pingText');
      const ipv6rtt = await (await ipv6rttItem.getProperty('textContent')).jsonValue();

      const ipv6jitItem = await ipv6frame.$('#jitText');
      const ipv6jit = await (await ipv6jitItem.getProperty('textContent')).jsonValue();

      const ipv6dlItem = await ipv6frame.$('#dlText');
      const ipv6dl = await (await ipv6dlItem.getProperty('textContent')).jsonValue();

      const ipv6ulItem = await ipv6frame.$('#ulText');
      const ipv6ul = await (await ipv6ulItem.getProperty('textContent')).jsonValue();

      fs.writeFile('speedtest/IPv6_RTT', ipv6rtt, (error) => { /* handle error */ });
      fs.writeFile('speedtest/IPv6_JIT', ipv6jit, (error) => { /* handle error */ });
      fs.writeFile('speedtest/IPv6_DL', ipv6dl, (error) => { /* handle error */ });
      fs.writeFile('speedtest/IPv6_UL', ipv6ul, (error) => { /* handle error */ });

    }

    if (frames.find( f => f.url().indexOf("test-ipv4") > 0) ) {
      var ipv4frame = frames.find(
          f =>
            f.url().indexOf("test-ipv4") > 0);

      const ipv4rttItem = await ipv4frame.$('#pingText');
      const ipv4rtt = await (await ipv4rttItem.getProperty('textContent')).jsonValue();

      const ipv4jitItem = await ipv4frame.$('#jitText');
      const ipv4jit = await (await ipv4jitItem.getProperty('textContent')).jsonValue();

      const ipv4dlItem = await ipv4frame.$('#dlText');
      const ipv4dl = await (await ipv4dlItem.getProperty('textContent')).jsonValue();

      const ipv4ulItem = await ipv4frame.$('#ulText');
      const ipv4ul = await (await ipv4ulItem.getProperty('textContent')).jsonValue();

      fs.writeFile('speedtest/IPv4_RTT', ipv4rtt, (error) => { /* handle error */ });
      fs.writeFile('speedtest/IPv4_JIT', ipv4jit, (error) => { /* handle error */ });
      fs.writeFile('speedtest/IPv4_DL', ipv4dl, (error) => { /* handle error */ });
      fs.writeFile('speedtest/IPv4_UL', ipv4ul, (error) => { /* handle error */ });

    }

  } catch (e) {
        console.error(e);
  }

  // await page.screenshot({path: 'screenshot.png'});
  await browser.close();

})();

