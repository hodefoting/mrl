PREFIX ?= /usr/local

default:
	@echo only the install target in the Makefile works

install:
	install -d $(DESTDIR)$(PREFIX)/bin
	install -t $(DESTDIR)$(PREFIX)/bin mrl-*
	install -d $(DESTDIR)$(PREFIX)/share/lua/5.1
	install -t $(DESTDIR)$(PREFIX)/share/lua/5.1 *.lua

