# necessary packages
 uuid-runtime (for uuidgen)
 wireless-tools (for iwgetid, iwconfig)
 ndisc6 (for rdisc6)
 dnsutils (for dig)
 curl (for curl)

# crontab
*/5 * * * * root cd <sindan_linux directory> && ./sindan.sh 1>/dev/null 2>/dev/null
*/1 * * * * root cd <sindan_linux directory> && ./sendlog.sh 1>/dev/null 2>/dev/null
