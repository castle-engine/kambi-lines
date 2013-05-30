.PHONY: compile
compile:
	./compile.sh

# Simple install.
# You may as well symlink to /usr/local/share/kambi_lines, for system-wide install.
install:
	rm -f $(HOME)/.local/share/kambi_lines
	ln -s $(shell pwd) $(HOME)/.local/share/kambi_lines

# Run also "dircleaner . clean" here to really clean
.PHONY: clean
clean:
	rm -f kambi_lines kambi_lines.exe
	rm -Rf kambi_lines.app
	rm -f KAMBI_LINES.hsc KAMBI_LINES.ini
