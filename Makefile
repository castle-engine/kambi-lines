# Simple install.
# You may as well symlink to /usr/local/share/kambi_lines, for system-wide install.
install:
	rm -f $(HOME)/.kambi_lines.data
	ln -s $(shell pwd) $(HOME)/.kambi_lines.data
