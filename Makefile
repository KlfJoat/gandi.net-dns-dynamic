NAME=gandi-dyndns
VERSION=0.5

# REMINDER:  MAKEFILE NEEDS TABS!!!
# cat -e -t -v Makefile

DIRS=bin
#INSTALL_DIRS=`find $(DIRS) -type d 2>/dev/null`
INSTALL_FILES=`find $(DIRS)/ -not -name "*~" -type f -printf "%f\n" 2>/dev/null`
config_file=$(NAME).conf

PREFIX?=$(HOME)/.local/bin

install:
	@if [ "$(shell id -u)" = 0 ]; then\
		@echo "You are root. Do not run this install as root, please";\
		exit 1;\
	fi
	@mkdir --parents $(PREFIX)
	for file in $(INSTALL_FILES); do install bin/$$file $(PREFIX)/$$file; done
# Don't overwrite config file
	@if test -f $(XDG_CONFIG_HOME)/$(config_file); then \
		echo "$(XDG_CONFIG_HOME)/$(config_file) exists; not overwriting!" ; \
	else \
		install --mode=600 config/$(config_file) $(XDG_CONFIG_HOME)/ ; \
	fi
	@mkdir --parents $(XDG_DATA_HOME)/systemd/user
	install --mode=644 units/$(NAME).* $(XDG_DATA_HOME)/systemd/user/
	systemctl --user enable --now $(NAME).timer

uninstall:
	@if [ "$(shell id -u)" = 0 ]; then\
		@echo "You are root. Do not run this uninstall as root, please";\
		exit 1;\
	fi
	for file in $(INSTALL_FILES); do rm -f $(PREFIX)/$$file; done
	systemctl --user disable --now $(NAME).timer
	rm $(XDG_DATA_HOME)/systemd/user/$(NAME).*

reinstall:
	@if [ "$(shell id -u)" = 0 ]; then\
		@echo "You are root. Do not run this reinstall as root, please";\
		exit 1;\
	fi
	for file in $(INSTALL_FILES); do install bin/$$file $(PREFIX)/$$file; done
	install --mode=644 units/$(NAME).* $(XDG_DATA_HOME)/systemd/user/
	systemctl --user daemon-reload


.PHONY: install uninstall reinstall all
