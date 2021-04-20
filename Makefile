CROSS_COMPILE ?= aarch64-linux-gnu-
M1N1DEVICE ?= /dev/ttyACM0
MKDIR ?= mkdir -p
CP ?= cp
CAT ?= cat

build:
	$(MKDIR) build

build/Image build/m1.dtb: FORCE | build
	$(MKDIR) linux/o
	$(CP) misc/linux-config linux/o/.config
	$(MAKE) -C linux ARCH=arm64 CROSS_COMPILE=$(CROSS_COMPILE) O=o oldconfig
	diff -u misc/linux-config linux/o/.config
	$(MAKE) -C linux ARCH=arm64 CROSS_COMPILE=$(CROSS_COMPILE) O=o
	$(CP) linux/o/arch/arm64/boot/Image build/Image
	$(CP) linux/o/arch/arm64/boot/dts/apple/apple-m1-j274.dtb build/m1.dtb

build/linux.macho: build/Image build/m1.dtb | build
	$(CP) build/Image preloader-m1
	$(CP) build/m1.dtb preloader-m1/apple-m1-j274.dtb
	$(MAKE) -C preloader-m1
	$(CP) preloader-m1/linux.macho build/linux.macho

build/m1n1.macho: FORCE | build
	$(MAKE) -C m1n1
	$(CP) m1n1/build/m1n1.macho build/m1n1.macho

build/m1n1ux.macho: build/m1n1.macho build/linux.macho | build
	$(CAT) $^ > $@

m1n1-boot!: build/linux.macho
	M1N1DEVICE=$(M1N1DEVICE) python3 ./m1n1/proxyclient/chainload.py ./build/linux.macho

.PHONY: FORCE
