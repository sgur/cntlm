#
# You can tweak these three variables to make things install where you
# like, but do not touch more unless you know what you are doing. ;)
#
DESTDIR    	:=
SYSCONFDIR 	:= $(DESTDIR)/etc
BINDIR     	:= $(DESTDIR)/usr/sbin
MANDIR     	:= $(DESTDIR)/usr/share/man

#
# Careful now...
# __BSD_VISIBLE is for FreeBSD AF_* constants
# _ALL_SOURCE is for AIX 5.3 LOG_PERROR constant
#
NAME		:= cntlm
CC		:= gcc
VER		:= $(shell cat VERSION)
OS		:= $(shell uname -s)
OSLDFLAGS	:= $(shell [ $(OS) = "SunOS" ] && echo "-lrt -lsocket -lnsl")
ARCH		:= $(shell uname -m)
LDFLAGS		:= -lpthread $(OSLDFLAGS)
CYGWIN_REQS	:= cygwin1.dll cyggcc_s-1.dll cygstdc++-6.dll cygrunsrv.exe 
MSYS2_REQS	:= msys-2.0.dll cygrunsrv.exe

ifeq ($(DEBUG),1)
	CFLAGS	+= -g  -std=c99 -Wall -pedantic -D__BSD_VISIBLE -D_ALL_SOURCE -D_XOPEN_SOURCE=600 -D_POSIX_C_SOURCE=200112 -D_ISOC99_SOURCE -D_REENTRANT -D_BSD_SOURCE -DVERSION=\"'$(VER)'\"
else
	CFLAGS	+= -O3 -std=c99 -D__BSD_VISIBLE -D_ALL_SOURCE -D_XOPEN_SOURCE=600 -D_POSIX_C_SOURCE=200112 -D_ISOC99_SOURCE -D_REENTRANT -D_BSD_SOURCE -DVERSION=\"'$(VER)'\"
endif

ifneq ($(filter CYGWIN% MSYS%,$(OS)),)
	OBJS=utils.o ntlm.o xcrypt.o config.o socket.o acl.o auth.o http.o forward.o direct.o scanner.o pages.o main.o sspi.o win/resources.o
else
	OBJS=utils.o ntlm.o xcrypt.o config.o socket.o acl.o auth.o http.o forward.o direct.o scanner.o pages.o main.o sspi.o
endif

$(NAME): configure-stamp $(OBJS)
	@echo "Linking $@"
	@$(CC) $(CFLAGS) -o $@ $(OBJS) $(LDFLAGS)

main.o: main.c
	@echo "Compiling $<"
	@if [ -z "$(SYSCONFDIR)" ]; then \
		$(CC) $(CFLAGS) -c main.c -o $@; \
	else \
		$(CC) $(CFLAGS) -DSYSCONFDIR=\"$(SYSCONFDIR)\" -c main.c -o $@; \
	fi

%.o: %.c
	@echo "Compiling $<"
	@$(CC) $(CFLAGS) -c -o $@ $<

configure-stamp:
	./configure

win/resources.o: win/resources.rc
	@echo Win32: adding ICON resource
	@windres $^ -o $@

install: $(NAME)
	# Special handling for install(1)
	if [ "`uname -s`" = "AIX" ]; then \
		install -M 755 -S -f $(BINDIR) $(NAME); \
		install -M 644 -f $(MANDIR)/man1 doc/$(NAME).1; \
		install -M 600 -c $(SYSCONFDIR) doc/$(NAME).conf; \
	elif [ "`uname -s`" = "Darwin" ]; then \
		install -d -m 755 -s $(NAME) $(BINDIR)/$(NAME); \
		install -d -m 644 doc/$(NAME).1 $(MANDIR)/man1/$(NAME).1; \
		[ -f $(SYSCONFDIR)/$(NAME).conf -o -z "$(SYSCONFDIR)" ] \
			|| install -d -m 600 doc/$(NAME).conf $(SYSCONFDIR)/$(NAME).conf; \
	else \
		install -D -m 755 -s $(NAME) $(BINDIR)/$(NAME); \
		install -D -m 644 doc/$(NAME).1 $(MANDIR)/man1/$(NAME).1; \
		[ -f $(SYSCONFDIR)/$(NAME).conf -o -z "$(SYSCONFDIR)" ] \
			|| install -D -m 600 doc/$(NAME).conf $(SYSCONFDIR)/$(NAME).conf; \
	fi
	@echo; echo "Cntlm will look for configuration in $(SYSCONFDIR)/$(NAME).conf"

tgz:
	mkdir -p tmp
	rm -rf tmp/$(NAME)-$(VER)
	svn export . tmp/$(NAME)-$(VER)
	tar zcvf $(NAME)-$(VER).tar.gz -C tmp/ $(NAME)-$(VER)
	rm -rf tmp/$(NAME)-$(VER)
	rmdir tmp 2>/dev/null || true

tbz2:
	mkdir -p tmp
	rm -rf tmp/$(NAME)-$(VER)
	svn export . tmp/$(NAME)-$(VER)
	tar jcvf $(NAME)-$(VER).tar.bz2 -C tmp/ $(NAME)-$(VER)
	rm -rf tmp/$(NAME)-$(VER)
	rmdir tmp 2>/dev/null || true

deb:
	sed -i "s/^\(cntlm *\)([^)]*)/\1($(VER))/g" debian/changelog
	if [ `id -u` = 0 ]; then \
		debian/rules binary; \
		debian/rules clean; \
	else \
		fakeroot debian/rules binary; \
		fakeroot debian/rules clean; \
	fi
	mv ../cntlm_$(VER)*.deb .

rpm:
	sed -i "s/^\(Version:[\t ]*\)\(.*\)/\1$(VER)/g" rpm/cntlm.spec
	if [ `id -u` = 0 ]; then \
		rpm/rules binary; \
		rpm/rules clean; \
	else \
		fakeroot rpm/rules binary; \
		fakeroot rpm/rules clean; \
	fi

win: win/setup.iss $(NAME) win/cntlm_manual.pdf win/cntlm.ini win/LICENSE.txt $(NAME)-$(VER)-win32.exe $(NAME)-$(VER)-win32.zip

win-msys2: win/setup.iss $(NAME) win/cntlm_manual.html win/cntlm.ini win/LICENSE.txt $(NAME)-$(VER)-msys2-$(ARCH).exe

$(NAME)-$(VER)-win32.exe:
	@echo Win32: preparing binaries for GUI installer
	@cp $(patsubst %, /bin/%, $(CYGWIN_REQS)) win/
ifeq ($(DEBUG),1)
	@echo Win32: copy DEBUG executable
	@cp -p cntlm.exe win/
else
	@echo Win32: copy release executable
	@strip -o win/cntlm.exe cntlm.exe
endif
	@echo Win32: generating GUI installer
	@win/Inno5/ISCC.exe /Q win/setup.iss #/Q win/setup.iss

$(NAME)-$(VER)-win32.zip: 
	@echo Win32: creating ZIP release for manual installs
	@ln -s win $(NAME)-$(VER)
	zip -9 $@ $(patsubst %, $(NAME)-$(VER)/%, cntlm.exe $(CYGWIN_REQS) cntlm.ini LICENSE.txt cntlm_manual.pdf) 
	@rm -f $(NAME)-$(VER)

$(NAME)-$(VER)-msys2-$(ARCH).exe:
	@echo MSYS2: preparing binaries for GUI installer
	@cp $(patsubst %, /usr/bin/%, $(MSYS2_REQS)) win/
	@echo MSYS2: copy release executable
	@strip -o win/cntlm.exe cntlm.exe
	@echo MSYS2: generating GUI installer
	@win/Inno5/ISCC.exe win/setup.iss

win/cntlm.ini: doc/cntlm.conf 
	@cat doc/cntlm.conf | unix2dos > $@

win/LICENSE.txt: COPYRIGHT LICENSE
	@cat COPYRIGHT LICENSE | unix2dos > $@

win/cntlm_manual.html: doc/cntlm.1 
	@echo Win32: generating HTML manual
	@rm -f $@
	@groff -t -e -mandoc -Thtml doc/cntlm.1 > $@

win/cntlm_manual.pdf: doc/cntlm.1 
	@echo Win32: generating PDF manual
	@rm -f $@
	@groff -t -e -mandoc -Tps doc/cntlm.1 | ps2pdf - $@

win/setup.iss: win/setup.iss.in
ifeq ($(filter CYGWIN% MSYS%,$(OS)),)
	@echo
	@echo "* This build target must be run from a Cywgin shell on Windows *"
	@echo
	@exit 1
endif
ifneq ($(findstring MSYS,$(OS)),)
  ifeq ($(ARCH), x86_64)
	@sed -e "s/\$$VERSION/$(VER)/g" \
		-e "s/\$$ARCH/msys2-$(ARCH)/g" \
		-e "s/\$$64BIT_MODE/x64/g" \
		-e "s/\$$HELP_EXT/html/g" \
		-e "s/\$$DLL_TYPE/msys2/g" \
		$^ > $@
  else
	@sed -e "s/\$$VERSION/$(VER)/g" \
		-e "s/\$$ARCH/msys2-$(ARCH)/g" \
		-e "s/\$$64BIT_MODE//g" \
		-e "s/\$$HELP_EXT/html/g" \
		-e "s/\$$DLL_TYPE/msys2/g" \
		$^ > $@
  endif
else
	@sed -e "s/\$$VERSION/$(VER)/g" \
		-e "s/\$$ARCH/win32/g" \
		-e "s/\$$64BIT_MODE//g" \
		-e "s/\$$HELP_EXT/pdf/g" \
		-e "s/\$$DLL_TYPE/cygwin/g" \
		$^ > $@
endif

uninstall:
	rm -f $(BINDIR)/$(NAME) $(MANDIR)/man1/$(NAME).1 2>/dev/null || true

clean:
	@rm -f config/endian config/gethostname config/strdup config/socklen_t config/*.exe
	@rm -f *.o cntlm cntlm.exe configure-stamp build-stamp config/config.h win/resources.o
	rm -f $(patsubst %, win/%, $(CYGWIN_REQS) $(MSYS2_REQS) cntlm.exe cntlm.ini LICENSE.txt setup.iss cntlm_manual.pdf cntlm_manual.html)
	@if [ -h Makefile ]; then rm -f Makefile; mv Makefile.gcc Makefile; fi

distclean: clean
ifeq ($(filter CYGWIN% MSYS%,$(OS)),)
	if [ `id -u` = 0 ]; then \
		debian/rules clean; \
		rpm/rules clean; \
	else \
		fakeroot debian/rules clean; \
		fakeroot rpm/rules clean; \
	fi
endif
	@rm -f *.exe *.deb *.rpm *.tgz *.tar.gz *.tar.bz2 *.zip *.exe tags ctags pid 2>/dev/null

.PHONY: all install tgz tbz2 deb rpm win uninstall clean distclean
