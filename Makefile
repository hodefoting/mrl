PREFIX ?= /usr/local

default:
	@echo only the install target in the Makefile works

install:
	install -d $(DESTDIR)$(PREFIX)/bin
	install mrl-* $(DESTDIR)$(PREFIX)/bin 
	install -d $(DESTDIR)$(PREFIX)/share/lua/5.1
	install *.lua $(DESTDIR)$(PREFIX)/share/lua/5.1 

