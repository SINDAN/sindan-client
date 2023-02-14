// speedtest.js
// author: bashow
// 2020/07/18

// Requirements:
// sudo apt install chromium-browser
// sudo apt install npm
// npm i puppeteer-core
// npm i speedline

// Hot to use:
// node speedtest.js <url>

const puppeteer = require('puppeteer-core');

var url = process.argv[2];

(async () => {
  const browser = await puppeteer.launch({
                          executablePath: '/usr/bin/chromium-browser',
                          userDataDir: '/dev/null',
                          args: ['--no-sandbox']});
  const page = await browser.newPage();
  await page.setDefaultNavigationTimeout(100000);

  try {
    await page.goto(url, { waitUntil: 'networkidle0' });

    await page.waitForSelector('#shareArea', { visible: true, timeout: 100000 });

    let frames = page.frames();

    if (frames.find( f => f.url().indexOf("ipv6") > 0) ) {
      var ipv6frame = frames.find(
          f =>
            f.url().indexOf("ipv6") > 0);

      const ipv6rttItem = await ipv6frame.$('#pingText');
      const ipv6rtt = await (await ipv6rttItem.getProperty('textContent')).jsonValue();

      const ipv6jitItem = await ipv6frame.$('#jitText');
      const ipv6jit = await (await ipv6jitItem.getProperty('textContent')).jsonValue();

      const ipv6dlItem = await ipv6frame.$('#dlText');
      const ipv6dl = await (await ipv6dlItem.getProperty('textContent')).jsonValue();

      const ipv6ulItem = await ipv6frame.$('#ulText');
      const ipv6ul = await (await ipv6ulItem.getProperty('textContent')).jsonValue();

      console.log('IPv6_RTT:' + ipv6rtt);
      console.log('IPv6_JIT:' + ipv6jit);
      console.log('IPv6_DL:' + ipv6dl);
      console.log('IPv6_UL:' + ipv6ul);
    }

    if (frames.find( f => f.url().indexOf("ipv4") > 0) ) {
      var ipv4frame = frames.find(
          f =>
            f.url().indexOf("ipv4") > 0);

      const ipv4rttItem = await ipv4frame.$('#pingText');
      const ipv4rtt = await (await ipv4rttItem.getProperty('textContent')).jsonValue();

      const ipv4jitItem = await ipv4frame.$('#jitText');
      const ipv4jit = await (await ipv4jitItem.getProperty('textContent')).jsonValue();

      const ipv4dlItem = await ipv4frame.$('#dlText');
      const ipv4dl = await (await ipv4dlItem.getProperty('textContent')).jsonValue();

      const ipv4ulItem = await ipv4frame.$('#ulText');
      const ipv4ul = await (await ipv4ulItem.getProperty('textContent')).jsonValue();

      console.log('IPv4_RTT:' + ipv4rtt);
      console.log('IPv4_JIT:' + ipv4jit);
      console.log('IPv4_DL:' + ipv4dl);
      console.log('IPv4_UL:' + ipv4ul);
    }

  } catch (e) {
        console.error(e);
  }

  // await page.screenshot({path: 'screenshot.png'});
  await browser.close();

})();

