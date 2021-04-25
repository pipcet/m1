CROSS_COMPILE ?= aarch64-linux-gnu-
M1N1DEVICE ?= /dev/ttyACM0
MKDIR ?= mkdir -p
CP ?= cp
CAT ?= cat
TAR ?= tar
PWD = $(shell pwd)
SUDO ?= $(and $(filter pip,$(shell whoami)),sudo)

all: build/l1lli.macho build/m1lli.macho build/linux.macho build/m1n1/m1n1.tar.gz

# directories

build:
	$(MKDIR) build

build/m1n1:
	$(MKDIR) build/m1n1

stamp:
	$(MKDIR) stamp
	touch stamp/kexec-tools stamp/busybox stamp/linux stamp/kexec-tools stamp/mesa stamp/m1n1 stamp/m1lli

stamp/%: | stamp
	touch stamp/$*

# echo $((1024*1024)) | sudo tee /proc/sys/fs/inotify/max_user_watches
stampserver: misc/stampserver.pl | stamp
	inotifywait -m -r . | perl misc/stampserver.pl

reconfigure-busybox!:
	$(CP) misc/busybox-config/m1lli busybox/.config
	$(MAKE) -C busybox menuconfig
	$(CP) misc/busybox-config/m1lli misc/busybox-config/m1lli.old
	$(CP) busybox/.config misc/busybox-config/m1lli
	diff -u misc/busybox-config/m1lli.old misc/busybox-config/m1lli

reconfigure-linux/%!:
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
	$(MAKE) linux/o/arch/arm64/boot/dts/apple/apple-m1-j293.dtb.dts.dtb
	$(CP) linux/o/arch/arm64/boot/dts/apple/apple-m1-j293.dtb.dts.dtb build/m1.dtb

build/Image-% build/m1-%.dtb: stamp/linux misc/linux-config/o-% | build
	$(MKDIR) linux/o-$*
	$(CP) misc/linux-config/o-$* linux/o-$*/.config
	$(MAKE) -C linux ARCH=arm64 CROSS_COMPILE=$(CROSS_COMPILE) O=o-$* oldconfig
	diff -u misc/linux-config/o-$* linux/o-$*/.config
	$(MAKE) -C linux ARCH=arm64 CROSS_COMPILE=$(CROSS_COMPILE) O=o-$*
	$(CP) linux/o-$*/arch/arm64/boot/Image build/Image-$*
	$(MAKE) linux/o-$*/arch/arm64/boot/dts/apple/apple-m1-j293.dtb.dts.dtb
	$(CP) linux/o-$*/arch/arm64/boot/dts/apple/apple-m1-j293.dtb.dts.dtb build/m1-$*.dtb

build/Image-m1lli: build/Image build/m1lli build/busybox build/kexec build/commfile misc/init m1lli/stage2/init m1lli/l1lli/linux-initrd-spec binaries/perl.tar.gz build/m1lli-scripts.tar build/m1.dtb build/dtc build/fdtoverlay build/linux.macho

build/Image-l1lli: build/Image-m1lli build/m1lli build/busybox build/kexec build/commfile misc/init m1lli/l1lli/init m1lli/l1lli/linux-initrd-spec binaries/perl.tar.gz build/m1lli-scripts.tar build/m1.dtb build/dtc build/fdtoverlay build/linux.macho

build/m1lli-scripts.tar: m1lli/scripts/adt-convert.pl m1lli/scripts/adt-finalize.pl m1lli/scripts/adt-transform.pl m1lli/scripts/fdt-to-props.pl m1lli/scripts/fdtdiff.pl m1lli/scripts/props-to-fdt.pl m1lli/scripts/adt2fdt m1lli/scripts/copy-fdt-props.pl
	(cd m1lli/scripts; tar cv adt-convert.pl adt-finalize.pl adt-transform.pl fdt-to-props.pl fdtdiff.pl props-to-fdt.pl adt2fdt copy-fdt-props.pl) > build/m1lli-scripts.tar

m1lli/scripts/%.pl: m1lli/src/%.pl
	$(CP) m1lli/src/$*.pl m1lli/scripts/$*.pl

m1lli/scripts/adt2fdt: m1lli/src/adt2fdt.cc
	aarch64-linux-gnu-g++ -Os -static -o m1lli/scripts/adt2fdt m1lli/src/adt2fdt.cc

m1lli/scripts/adt2fdt-native: m1lli/src/adt2fdt.cc
	g++ -Os -o m1lli/scripts/adt2fdt-native m1lli/src/adt2fdt.cc

build/modules.tar: build/Image | build
	$(MKDIR) build/modules
	$(MAKE) -C linux ARCH=arm64 CROSS_COMPILE=$(CROSS_COMPILE) O=o MODLIB=$(PWD)/build/modules modules_install
	(cd build; $(TAR) cf modules.tar modules)

build/linux.macho: build/Image build/m1.dtb $(wildcard preloader-m1/*.c) $(wildcard preloader-m1/*.h) $(wildcard preloader-m1/*.S) $(wildcard preloader-m1/Makefile) | build
	$(CP) build/Image preloader-m1
	$(CP) build/m1.dtb preloader-m1/apple-m1-j293.dtb
	$(MAKE) -C preloader-m1
	$(CP) preloader-m1/linux.macho build/linux.macho

build/%.macho: build/Image-% build/m1-%.dtb $(wildcard preloader-m1/*.c) $(wildcard preloader-m1/*.h) $(wildcard preloader-m1/*.S) $(wildcard preloader-m1/Makefile) | build
	$(CP) build/Image-$* preloader-m1/Image
	$(CP) build/m1-$*.dtb preloader-m1/apple-m1-j293.dtb
	$(MAKE) -C preloader-m1
	$(CP) preloader-m1/linux.macho build/$*.macho

build/m1n1/m1n1.macho: stamp/m1n1 | build/m1n1
	$(MAKE) -C m1n1
	$(CP) m1n1/build/m1n1.macho build/m1n1/m1n1.macho

build/m1n1/m1n1.elf: stamp/m1n1 | build/m1n1
	$(MAKE) -C m1n1
	$(CP) m1n1/build/m1n1.elf build/m1n1/m1n1.elf

build/m1n1/m1n1.image: build/machoImage build/m1n1/m1n1.macho | build/m1n1
	$(CAT) build/machoImage build/m1n1/m1n1.macho > build/m1n1/m1n1.image

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
	(cd build; $(MKDIR) m1lli-m1lli; cp Image-m1lli m1lli-m1lli/Image; cp script m1lli-m1lli/script; cd m1lli-m1lli; tar cvf m1lli-m1lli.tar Image script; cd ..; cp m1lli-m1lli/m1lli-m1lli.tar .)

build/m1lli-m1lli.tar.gz: build/m1lli-m1lli.tar
	gzip < build/m1lli-m1lli.tar > build/m1lli-m1lli.tar.gz

build/m1lli-l1lli.tar: build/Image-l1lli build/script
	(cd build; $(MKDIR) m1lli-l1lli; cp Image-l1lli m1lli-l1lli/Image; cp script m1lli-l1lli/script; cd m1lli-l1lli; tar cvf m1lli-l1lli.tar Image script; cd ..; cp m1lli-l1lli/m1lli-l1lli.tar .)

build/m1lli-l1lli.tar.gz: build/m1lli-l1lli.tar
	gzip < build/m1lli-l1lli.tar > build/m1lli-l1lli.tar.gz

build/m1n1/m1n1.tar: build/m1n1/m1n1.image.macho.image build/m1n1/m1n1.elf build/m1n1/script
	cp build/m1n1/m1n1.macho.image build/m1n1/m1n1.macho
	(cd build/m1n1; tar cvf m1n1.tar m1n1.image m1n1.elf script)

build/m1n1/m1n1.tar.gz: build/m1n1/m1n1.tar
	gzip < build/m1n1/m1n1.tar > build/m1n1/m1n1.tar.gz

m1lli-linux!: build/m1lli.tar.gz misc/commfile-server.pl
	$(SUDO) perl misc/commfile-server.pl build/m1lli.tar.gz

m1lli-m1lli!: build/m1lli-m1lli.tar.gz
	$(SUDO) perl ./misc/commfile-server.pl ./build/m1lli-m1lli.tar.gz

m1lli-l1lli!: build/m1lli-l1lli.tar.gz
	$(SUDO) perl ./misc/commfile-server.pl ./build/m1lli-l1lli.tar.gz

m1n1-shell!:
	M1N1DEVICE=$(M1N1DEVICE) python3 ./m1n1/proxyclient/shell.py

m1n1-linux!: build/linux.macho
	M1N1DEVICE=$(M1N1DEVICE) python3 ./m1n1/proxyclient/chainload.py ./build/linux.macho

m1n1-m1lli!: build/m1lli.macho
	M1N1DEVICE=$(M1N1DEVICE) python3 ./m1n1/proxyclient/chainload.py ./build/m1lli.macho

m1n1-lilli!: build/l1lli.macho
	M1N1DEVICE=$(M1N1DEVICE) python3 ./m1n1/proxyclient/chainload.py ./build/l1lli.macho

m1n1-m1n1!: build/m1n1/m1n1.macho
	M1N1DEVICE=$(M1N1DEVICE) python3 ./m1n1/proxyclient/chainload.py ./build/m1n1/m1n1.macho

m1lli-m1n1!: build/m1n1/m1n1.tar.gz misc/commfile-server.pl
	$(SUDO) perl misc/commfile-server.pl build/m1n1/m1n1.tar.gz

misc/linux-config/%.pospart: misc/linux-config/%
	egrep -v '^#' < misc/linux-config/$* > misc/linux-config/$*.pospart

build/machoImage: build/machoImage.elf
	objcopy -O binary -S --only-section .text --only-section .data --only-section .got --only-section .last build/machoImage.elf build/machoImage

build/machoImage.elf: m1lli/machoImage/machoImage.c
	aarch64-linux-gnu-gcc -static -nostdlib -nolibc -Os -fPIC -o build/machoImage.elf m1lli/machoImage/machoImage.c

build/Image-macho: m1lli/machoImage/Image-macho.c
	gcc -o build/Image-macho m1lli/machoImage/Image-macho.c

%.image.macho: %.image build/machoImage
	cat build/machoImage $*.image > $*.image.macho

%.macho.image: %.macho build/Image-macho
	build/Image-macho $*.macho $*.macho.image

dtc:
	$(MKDIR) dtc
	(cd dtc; ln -s ../linux/scripts/dtc/* .; rm Makefile; rm -f libfdt)
	(cd dtc; mkdir libfdt; cd libfdt; ln -s ../../linux/scripts/dtc/libfdt/* .)
	cp misc/dtc-Makefile dtc/Makefile

build/dtc build/fdtoverlay: dtc
	$(MAKE) -C dtc
	$(CP) dtc/dtc dtc/fdtoverlay build/

%.dtb.dts: %.dtb build/dtc
	build/dtc -O dts -I dtb < $*.dtb > $*.dtb.dts

%.dts.dtp: %.dts m1lli/src/fdt-to-props.pl
	perl m1lli/src/fdt-to-props.pl < $*.dts > $*.dts.dtp

%.dtp.dts: %.dtp m1lli/src/props-to-fdt.pl
	perl m1lli/src/fdt-to-props.pl < $*.dtp > $*.dtp.dts

%.dts.dtb: %.dts build/dtc
	build/dtc -O dtb -I dts < $*.dts > $*.dts.dtb

%.adtb.dtp: %.adtb m1lli/scripts/adt2fdt-native
	m1lli/scripts/adt2fdt-native $*.adtb > $*.adtb.dtp

# This shortens dates. Update in 2999.
README.html: README.org $(wildcard */README.org) $(wildcard */*/README.org)
	emacs README.org --batch -Q -f org-html-export-to-html
	sed -i -e 's/\(2[0-9][0-9][0-9]\)-[0-9][0-9]-[0-9][0-9] [A-Z][a-z][a-z] [0-9][0-9]:[0-9][0-9]/\1/g' README.html

.PHONY: %!
