DIR_ORIGIN               = ../src
DIR_CONF_INSTALL         = /etc
DIR_SRV_LAUNCHER_INSTALL = /etc/init.d
DIR_EXE_INSTALL          = /usr/bin

all: clean install

install:
	PS4="CMD:\${0}:pid=\${$}: "
	set -x

	test -d $(DESTDIR)$(DIR_SRV_LAUNCHER_INSTALL) || install --directory --owner=root --group=root --mode=755 --verbose $(DESTDIR)$(DIR_EXE_INSTALL)

	test -d $(DESTDIR)$(DIR_SRV_LAUNCHER_INSTALL) || install --directory --owner=root --group=root --mode=755 --verbose $(DESTDIR)$(DIR_SRV_LAUNCHER_INSTALL)

	test -d $(DESTDIR)/etc/rc3.d/                 || install --directory --owner=root --group=root --mode=755 --verbose   $(DESTDIR)/etc/rc3.d/

	install --owner=root --group=root --mode=755 --verbose $(DIR_ORIGIN)/bt-proximity-screen-locker.sh $(DESTDIR)$(DIR_EXE_INSTALL)/bt-proximity-screen-locker.sh

	install --owner=root --group=root --mode=755 --verbose $(DIR_ORIGIN)/bt-proximity-screen-locker $(DESTDIR)$(DIR_SRV_LAUNCHER_INSTALL)/bt-proximity-screen-locker

	ln -s $(DIR_SRV_LAUNCHER_INSTALL)/bt-proximity-screen-locker $(DESTDIR)/etc/rc3.d/S07bt-proximity-screen-locker

	if which systemctl ; then (systemctl enable bt-proximity-screen-locker ; systemctl disable bt-proximity-screen-locker) || true ; fi

	if which systemctl ; then systemctl start bt-proximity-screen-locker || true ; fi

uninstall:
	PS4="CMD:\${0}:pid=\${$}: "
	set -x

	$(DESTDIR)$(DIR_SRV_LAUNCHER_INSTALL)/bt-proximity-screen-locker stop || true
	if which systemctl ; then systemctl disable bt-proximity-screen-locker || true ; fi
	rm -f $(DESTDIR)$(DIR_EXE_INSTALL)/bt-proximity-screen-locker.sh
	rm -f $(DESTDIR)$(DIR_SRV_LAUNCHER_INSTALL)/bt-proximity-screen-locker
	rm -f $(DESTDIR)/etc/rc3.d/S07bt-proximity-screen-locker

clean:
	echo "INFO:${0}:pid=${$}: Nothing to be done for cleanup after this DEB package build."
