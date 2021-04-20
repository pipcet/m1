CROSS_COMPILE ?= aarch64-linux-gnu-
M1N1DEVICE ?= /dev/ttyACM0
MKDIR ?= mkdir -p
CP ?= cp
CAT ?= cat
TAR ?= tar
PWD = $(shell pwd)

build:
	$(MKDIR) build

reconfigure-linux/%!: FORCE
	$(MKDIR) linux/o
	$(CP) misc/linux-config/$* linux/o/.config
	$(MAKE) -C linux ARCH=arm64 CROSS_COMPILE=$(CROSS_COMPILE) O=o menuconfig
	$(CP) misc/linux-config/$* misc/linux-config/$*.old
	$(CP) linux/o/.config misc/linux-config/$*
	diff -u misc/linux-config/$*.old misc/linux-config/$*

build/Image build/m1.dtb: FORCE | build
	$(MKDIR) linux/o
	$(CP) misc/linux-config/o linux/o/.config
	$(MAKE) -C linux ARCH=arm64 CROSS_COMPILE=$(CROSS_COMPILE) O=o oldconfig
	diff -u misc/linux-config/o linux/o/.config
	$(MAKE) -C linux ARCH=arm64 CROSS_COMPILE=$(CROSS_COMPILE) O=o
	$(CP) linux/o/arch/arm64/boot/Image build/Image
	$(CP) linux/o/arch/arm64/boot/dts/apple/apple-m1-j274.dtb build/m1.dtb

build/Image-% build/m1-%.dtb: FORCE | build
	$(MKDIR) linux/o-$*
	$(CP) misc/linux-config/o-$* linux/o-$*/.config
	$(MAKE) -C linux ARCH=arm64 CROSS_COMPILE=$(CROSS_COMPILE) O=o-$* oldconfig
	diff -u misc/linux-config/o-$* linux/o-$*/.config
	$(MAKE) -C linux ARCH=arm64 CROSS_COMPILE=$(CROSS_COMPILE) O=o-$*
	$(CP) linux/o-$*/arch/arm64/boot/Image build/Image-$*
	$(CP) linux/o-$*/arch/arm64/boot/dts/apple/apple-m1-j274.dtb build/m1-$*.dtb

build/Image-minimal: build/Image
build/Image-m1lli: build/Image

build/linux.macho: build/Image build/m1.dtb | build
	$(CP) build/Image preloader-m1
	$(CP) build/m1.dtb preloader-m1/apple-m1-j274.dtb
	$(MAKE) -C preloader-m1
	$(CP) preloader-m1/linux.macho build/linux.macho

build/modules.tar: build/Image | build
	$(MKDIR) build/modules
	$(MAKE) -C linux ARCH=arm64 CROSS_COMPILE=$(CROSS_COMPILE) O=o MODLIB=$(PWD)/build/modules modules_install
	(cd build; $(TAR) cf modules.tar modules)

build/linux-%.macho: build/Image-% build/m1-%.dtb | build
	$(CP) build/Image-$* preloader-m1/Image
	$(CP) build/m1-$*.dtb preloader-m1/apple-m1-j274.dtb
	$(MAKE) -C preloader-m1
	$(CP) preloader-m1/linux.macho build/linux-$*.macho

build/m1n1.macho: FORCE | build
	$(MAKE) -C m1n1
	$(CP) m1n1/build/m1n1.macho build/m1n1.macho

build/m1n1ux.macho: build/m1n1.macho build/linux.macho | build
	$(CAT) $^ > $@

build/kexec: FORCE | build
	(cd kexec-tools; ./bootstrap)
	(cd kexec-tools; LDFLAGS=-static CC=aarch64-linux-gnu-gcc BUILD_CC=gcc ./configure --target=aarch64-linux-gnu --host=x86_64-pc-linux-gnu TARGET_CC=aarch64-linux-gnu-gcc LD=aarch64-linux-gnu-ld)
	$(MAKE) -C kexec-tools
	cp kexec-tools/build/sbin/kexec build/kexec

build/busybox: misc/busybox-config/m1lli | build
	cp misc/busybox-config/m1lli busybox/.config
	$(MAKE) -C busybox oldconfig
	$(MAKE) -C busybox
	$(CP) busybox/busybox build/busybox

m1n1-boot!: build/linux.macho
	M1N1DEVICE=$(M1N1DEVICE) python3 ./m1n1/proxyclient/chainload.py ./build/linux.macho

.PHONY: FORCE
