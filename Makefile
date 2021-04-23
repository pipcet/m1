CROSS_COMPILE ?= aarch64-linux-gnu-
M1N1DEVICE ?= /dev/ttyACM0
MKDIR ?= mkdir -p
CP ?= cp
CAT ?= cat
TAR ?= tar
PWD = $(shell pwd)
SUDO ?= $(and $(filter pip,$(shell whoami)),sudo)

build:
	$(MKDIR) build

build/m1n1:
	$(MKDIR) build/m1n1

stamp:
	$(MKDIR) stamp
	touch stamp/kexec-tools stamp/busybox stamp/linux stamp/kexec-tools stamp/mesa stamp/m1n1 stamp/m1lli

stamp/%: | stamp
	touch stamp/$*

stampserver: misc/stampserver.pl | stamp
	inotifywait -m -r . | perl misc/stampserver.pl

reconfigure-busybox!: FORCE
	$(CP) misc/busybox-config/m1lli busybox/.config
	$(MAKE) -C busybox menuconfig
	$(CP) misc/busybox-config/m1lli misc/busybox-config/m1lli.old
	$(CP) busybox/.config misc/busybox-config/m1lli
	diff -u misc/busybox-config/m1lli.old misc/busybox-config/m1lli

reconfigure-linux/%!: FORCE
	$(MKDIR) linux/o
	$(CP) misc/linux-config/$* linux/o/.config
	$(MAKE) -C linux ARCH=arm64 CROSS_COMPILE=$(CROSS_COMPILE) O=o menuconfig
	$(CP) misc/linux-config/$* misc/linux-config/$*.old
	$(CP) linux/o/.config misc/linux-config/$*
	diff -u misc/linux-config/$*.old misc/linux-config/$*

build/Image build/m1.dtb: stamp/linux misc/linux-config/o | build
	$(MKDIR) linux/o
	$(CP) misc/linux-config/o linux/o/.config
	$(MAKE) -C linux ARCH=arm64 CROSS_COMPILE=$(CROSS_COMPILE) O=o oldconfig
	diff -u misc/linux-config/o linux/o/.config
	$(MAKE) -C linux ARCH=arm64 CROSS_COMPILE=$(CROSS_COMPILE) O=o
	$(CP) linux/o/arch/arm64/boot/Image build/Image
	$(CP) linux/o/arch/arm64/boot/dts/apple/apple-m1-j293.dtb build/m1.dtb

build/Image-% build/m1-%.dtb: stamp/linux misc/linux-config/o-% | build
	$(MKDIR) linux/o-$*
	$(CP) misc/linux-config/o-$* linux/o-$*/.config
	$(MAKE) -C linux ARCH=arm64 CROSS_COMPILE=$(CROSS_COMPILE) O=o-$* oldconfig
	diff -u misc/linux-config/o-$* linux/o-$*/.config
	$(MAKE) -C linux ARCH=arm64 CROSS_COMPILE=$(CROSS_COMPILE) O=o-$*
	$(CP) linux/o-$*/arch/arm64/boot/Image build/Image-$*
	$(CP) linux/o-$*/arch/arm64/boot/dts/apple/apple-m1-j293.dtb build/m1-$*.dtb

build/Image-minimal: build/Image build/m1lli build/busybox build/kexec build/commfile misc/init misc/init-cpio-spec

build/Image-m1lli: build/Image build/m1lli build/busybox build/kexec build/commfile misc/init misc/init-cpio-spec

build/modules.tar: build/Image | build
	$(MKDIR) build/modules
	$(MAKE) -C linux ARCH=arm64 CROSS_COMPILE=$(CROSS_COMPILE) O=o MODLIB=$(PWD)/build/modules modules_install
	(cd build; $(TAR) cf modules.tar modules)

build/linux.macho: build/Image build/m1.dtb stamp/preloader-m1 | build
	$(CP) build/Image preloader-m1
	$(CP) build/m1.dtb preloader-m1/apple-m1-j293.dtb
	$(MAKE) -C preloader-m1
	$(CP) preloader-m1/linux.macho build/linux.macho

build/linux-%.macho: build/Image-% build/m1-%.dtb stamp/preloader-m1 | build
	$(CP) build/Image-$* preloader-m1/Image
	$(CP) build/m1-$*.dtb preloader-m1/apple-m1-j293.dtb
	$(MAKE) -C preloader-m1
	$(CP) preloader-m1/linux.macho build/linux-$*.macho

build/m1n1/m1n1.macho: stamp/m1n1 | build/m1n1
	$(MAKE) -C m1n1
	$(CP) m1n1/build/m1n1.macho build/m1n1/m1n1.macho

build/m1n1/m1n1.elf: stamp/m1n1 | build/m1n1
	$(MAKE) -C m1n1
	$(CP) m1n1/build/m1n1.elf build/m1n1/m1n1.elf

build/m1n1ux.macho: build/m1n1/m1n1.macho build/linux.macho | build
	$(CAT) $^ > $@

build/kexec: stamp/kexec-tools | build
	(cd kexec-tools; ./bootstrap)
	(cd kexec-tools; LDFLAGS=-static CC=aarch64-linux-gnu-gcc BUILD_CC=gcc ./configure --target=aarch64-linux-gnu --host=x86_64-pc-linux-gnu TARGET_CC=aarch64-linux-gnu-gcc LD=aarch64-linux-gnu-ld)
	$(MAKE) -C kexec-tools
	$(CP) kexec-tools/build/sbin/kexec build/kexec

build/busybox: misc/busybox-config/m1lli stamp/busybox | build
	$(CP) misc/busybox-config/m1lli busybox/.config
	$(MAKE) -C busybox oldconfig
	$(MAKE) -C busybox
	$(CP) busybox/busybox build/busybox

build/m1lli: m1lli/src/m1lli.c
	aarch64-linux-gnu-gcc -static -Os -o build/m1lli m1lli/src/m1lli.c

build/commfile: m1lli/src/commfile.c
	aarch64-linux-gnu-gcc -static -Os -o build/commfile m1lli/src/commfile.c

build/script: misc/script
	$(CP) misc/script build/script
	chmod u+x build/script

build/m1n1/script: misc/script-m1n1
	$(CP) misc/script-m1n1 build/m1n1/script
	chmod u+x build/m1n1/script

build/m1lli.tar: build/Image build/script
	(cd build; tar cvf m1lli.tar Image script)

build/m1lli.tar.gz: build/m1lli.tar
	gzip < build/m1lli.tar > build/m1lli.tar.gz

build/m1lli-m1lli.tar: build/Image-m1lli build/script
	(cd build; mkdir m1lli-m1lli; cp Image-m1lli m1lli-m1lli/Image; cp script m1lli-m1lli/script; cd m1lli-m1lli; tar cvf m1lli-m1lli.tar Image script; cd ..; cp m1lli-m1lli/m1lli-m1lli.tar .)

build/m1lli-m1lli.tar.gz: build/m1lli-m1lli.tar
	gzip < build/m1lli-m1lli.tar > build/m1lli-m1lli.tar.gz

build/m1n1/m1n1.tar: build/m1n1/m1n1.elf build/m1n1/script
	(cd build/m1n1; tar cvf m1n1.tar m1n1.elf script)

build/m1n1/m1n1.tar.gz: build/m1n1/m1n1.tar
	gzip < build/m1n1/m1n1.tar > build/m1n1/m1n1.tar.gz

m1lli-boot!: build/m1lli.tar.gz misc/commfile-server.pl FORCE
	$(SUDO) perl misc/commfile-server.pl build/m1lli.tar.gz

m1lli-linux!: build/m1lli.tar.gz misc/commfile-server.pl FORCE
	$(SUDO) perl misc/commfile-server.pl build/m1lli.tar.gz

m1n1-m1lli!: build/linux-m1lli.macho FORCE
	M1N1DEVICE=$(M1N1DEVICE) python3 ./m1n1/proxyclient/chainload.py ./build/linux-m1lli.macho

m1lli-m1lli!: build/m1lli-m1lli.tar.gz FORCE
	$(SUDO) perl ./misc/commfile-server.pl ./build/m1lli-m1lli.tar.gz

m1n1-boot!: build/linux.macho FORCE
	M1N1DEVICE=$(M1N1DEVICE) python3 ./m1n1/proxyclient/chainload.py ./build/linux.macho

m1n1-shell!: FORCE
	M1N1DEVICE=$(M1N1DEVICE) python3 ./m1n1/proxyclient/shell.py

m1n1-m1n1!: build/m1n1/m1n1.macho FORCE
	M1N1DEVICE=$(M1N1DEVICE) python3 ./m1n1/proxyclient/chainload.py ./build/m1n1/m1n1.macho

m1lli-m1n1!: build/m1n1/m1n1.tar.gz misc/commfile-server.pl FORCE
	perl misc/commfile-server.pl build/m1n1/m1n1.tar.gz

misc/linux-config/%.pospart: misc/linux-config/%
	egrep -v '^#' < misc/linux-config/$* > misc/linux-config/$*.pospart

.PHONY: FORCE
