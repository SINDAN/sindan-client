all: install

.PHONY: install
install:
	/bin/bash template.sh
	cp sindan-client.service /etc/systemd/system/sindan-client.service
	cp sindan-client.timer /etc/systemd/system/sindan-client.timer
	systemctl daemon-reload
	systemctl enable sindan-client.service
	systemctl enable --now sindan-client.timer

.PHONY: uninstall
uninstall:
	systemctl disable sindan-client.service
	systemctl disable --now sindan-client.timer
	rm /etc/systemd/system/sindan-client.service
	rm /etc/systemd/system/sindan-client.timer
	systemctl daemon-reload
