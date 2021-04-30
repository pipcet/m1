CROSS_COMPILE ?= aarch64-linux-gnu-
M1N1DEVICE ?= /dev/ttyACM0
MKDIR ?= mkdir -p
CP ?= cp
CAT ?= cat
TAR ?= tar
PWD = $(shell pwd)
SUDO ?= $(and $(filter pip,$(shell whoami)),sudo)

all: build/stage1.macho build/stage2.macho build/linux.macho build/m1n1.tar.gz

build m1lli/scripts build/m1n1:
	$(MKDIR) $@

clean:
	rm -rf build m1lli/asm-snippets/*.*.* linux/o

stamp:
	$(MKDIR) stamp
	touch stamp/kexec-tools stamp/busybox stamp/linux stamp/kexec-tools stamp/mesa stamp/m1n1 stamp/m1lli

stamp/%: | stamp
	touch stamp/$*

# echo $((1024*1024)) | sudo tee /proc/sys/fs/inotify/max_user_watches
stampserver: misc/stampserver.pl | stamp
	inotifywait -m -r . | perl misc/stampserver.pl

reconfigure-busybox!:
	$(CP) m1lli/busybox/busybox.config busybox/.config
	$(MAKE) -C busybox menuconfig
	$(CP) m1lli/busybox/busybox.config m1lli/busybox/busybox.config.old
	$(CP) busybox/.config m1lli/busybox/busybox.config
	diff -u m1lli/busybox/busybox.config.old m1lli/busybox/busybox.config

oldconfig-linux/%!: m1lli/%/linux.config
	$(MKDIR) linux/o/$*
	$(CP) m1lli/$*/linux.config linux/o/$*/.config
	$(MAKE) -C linux ARCH=arm64 CROSS_COMPILE=$(CROSS_COMPILE) O=o/$* oldconfig
	$(CP) m1lli/$*/linux.config m1lli/$*/linux.config.old
	$(CP) linux/o/$*/.config m1lli/$*/linux.config
	diff -u m1lli/$*/linux.config.old m1lli/$*/linux.config || true

# $(MAKE) -C linux ARCH=arm64 CROSS_COMPILE=$(CROSS_COMPILE) O=o tinyconfig
reconfigure-linux/%!: m1lli/%/linux.config
	$(MKDIR) linux/o/$*
	$(CP) m1lli/$*/linux.config linux/o/$*/.config
	$(MAKE) -C linux ARCH=arm64 CROSS_COMPILE=$(CROSS_COMPILE) O=o/$* menuconfig
	$(CP) m1lli/$*/linux.config m1lli/$*/linux.config.old
	$(CP) linux/o/$*/.config m1lli/$*/linux.config
	diff -u m1lli/$*/linux.config.old m1lli/$*/linux.config

build/%.image: stamp/linux m1lli/%/linux.config | build
	$(MKDIR) linux/o/$*
	$(CP) m1lli/$*/linux.config linux/o/$*/.config
	$(MAKE) -C linux ARCH=arm64 CROSS_COMPILE=$(CROSS_COMPILE) O=o/$* oldconfig
	diff -u m1lli/$*/linux.config linux/o/$*/.config
	$(MAKE) -C linux ARCH=arm64 CROSS_COMPILE=$(CROSS_COMPILE) O=o/$* Image dtbs
	$(CP) linux/o/$*/arch/arm64/boot/Image build/$*.image
	$(MAKE) linux/o/$*/arch/arm64/boot/dts/apple/apple-m1-j293.dtb.dts.dtb
	$(CP) linux/o/$*/arch/arm64/boot/dts/apple/apple-m1-j293.dtb.dts.dtb build/$*.dtb

build/%.dtb: build/%.image
	true

build/linux.image: m1lli/asm-snippets/maximal-dt.dts.dtb.h

build/stage2.image: build/linux.image build/m1lli build/busybox build/kexec build/commfile misc/init m1lli/stage2/init m1lli/stage2/init-cpio-spec m1lli/stage1/linux-initrd-spec binaries/perl.tar.gz build/m1lli-scripts.tar build/linux.dtb build/dtc build/fdtoverlay build/linux.macho m1lli/asm-snippets/maximal-dt.dts.dtb.h

build/stage1.image: build/stage2.image build/m1lli build/busybox build/kexec build/commfile misc/init m1lli/stage1/init m1lli/stage1/linux-initrd-spec binaries/perl.tar.gz build/m1lli-scripts.tar build/stage2.dtb build/dtc build/fdtoverlay build/linux.macho m1lli/asm-snippets/maximal-dt.dts.dtb.h

build/m1lli-scripts.tar: m1lli/scripts/adt-convert.pl m1lli/scripts/adt-transform.pl m1lli/scripts/fdt-to-props.pl m1lli/scripts/fdtdiff.pl m1lli/scripts/props-to-fdt.pl m1lli/scripts/adt2fdt
	(cd m1lli/scripts; tar cv adt-convert.pl adt-finalize.pl adt-transform.pl fdt-to-props.pl fdtdiff.pl props-to-fdt.pl adt2fdt copy-fdt-props.pl) > build/m1lli-scripts.tar

m1lli/scripts/%.pl: m1lli/src/%.pl | m1lli/scripts
	$(CP) $< $@

m1lli/scripts/adt2fdt: m1lli/src/adt2fdt.cc
	aarch64-linux-gnu-g++ -Os -static -o m1lli/scripts/adt2fdt m1lli/src/adt2fdt.cc

m1lli/scripts/adt2fdt.native: m1lli/src/adt2fdt.cc
	g++ -Os -o $@ $<

build/modules.tar: build/linux.image | build
	rm -rf build/modules
	$(MKDIR) build/modules
	$(MAKE) -C linux ARCH=arm64 CROSS_COMPILE=$(CROSS_COMPILE) O=o/linux INSTALL_MOD_PATH=$(PWD)/build/modules modules_install
	(cd build/modules; $(TAR) cf ../modules.tar .)

build/linux.macho: build/linux.image build/linux.dtb $(wildcard preloader-m1/*.c) $(wildcard preloader-m1/*.h) $(wildcard preloader-m1/*.S) $(wildcard preloader-m1/Makefile) | build
	$(CP) build/linux.image preloader-m1/Image
	$(CP) build/linux.dtb preloader-m1/apple-m1-j293.dtb
	$(MAKE) -C preloader-m1
	$(CP) preloader-m1/linux.macho build/linux.macho

build/%.macho: build/%.image build/m1-%.dtb $(wildcard preloader-m1/*.c) $(wildcard preloader-m1/*.h) $(wildcard preloader-m1/*.S) $(wildcard preloader-m1/Makefile) | build
	$(CP) build/$*.image preloader-m1/Image
	$(CP) build/m1-$*.dtb preloader-m1/apple-m1-j293.dtb
	$(MAKE) -C preloader-m1
	$(CP) preloader-m1/linux.macho build/$*.macho

build/m1n1.macho: stamp/m1n1 | build/m1n1
	$(MAKE) -C m1n1
	$(CP) m1n1/build/m1n1.macho $@

build/m1n1.elf: stamp/m1n1 | build/m1n1
	$(MAKE) -C m1n1
	$(CP) m1n1/build/m1n1.elf $@

build/m1n1.image: build/macho-to-image build/m1n1.macho | build/m1n1
	$(CAT) $< build/m1n1.macho > $@

build/m1n1ux.macho: build/m1n1.macho build/linux.macho | build
	$(CAT) $^ > $@

build/kexec: stamp/kexec-tools | build
	(cd kexec-tools; ./bootstrap)
	(cd kexec-tools; LDFLAGS=-static CC=aarch64-linux-gnu-gcc BUILD_CC=gcc ./configure --target=aarch64-linux-gnu --host=x86_64-pc-linux-gnu TARGET_CC=aarch64-linux-gnu-gcc LD=aarch64-linux-gnu-ld STRIP=aarch64-linux-gnu-strip)
	$(MAKE) -C kexec-tools
	$(CP) kexec-tools/build/sbin/kexec build/kexec

build/busybox: m1lli/busybox/busybox.config stamp/busybox | build
	$(CP) $< busybox/.config
	$(MAKE) -C busybox oldconfig
	$(MAKE) -C busybox
	$(CP) busybox/busybox build/busybox

build/m1lli: m1lli/src/m1lli.c
	aarch64-linux-gnu-gcc -static -Os -o build/m1lli m1lli/src/m1lli.c

build/commfile: m1lli/src/commfile.c
	aarch64-linux-gnu-gcc -static -Os -o build/commfile m1lli/src/commfile.c

build/%.image.m1lli.d: m1lli/%/m1lli-script
	$(MKDIR) $@

build/%.image.m1lli.d/script: m1lli/%/m1lli-script build/%.m1lli.d
	$(CP) $< $@
	chmod u+x $@

build/%.image.m1lli.d/Image: build/%.image
	$(CP) $< $@

build/script: misc/script-m1n1
	$(CP) misc/script-m1n1 build/script
	chmod u+x build/script

build/m1lli.tar: build/linux.image build/script
	(cd build; cp linux.image Image; tar cvf $< Image script)

build/m1lli.tar.gz: build/m1lli.tar
	gzip < build/m1lli.tar > build/m1lli.tar.gz

%.image.m1lli: build/%.image.m1lli.d/script build/%.image.m1lli.d/Image
	(cd $(dir $<); tar czv .) > $@

m1lli/%.m1lli!: %.m1lli
	$(SUDO) perl misc/commfile-server.pl $<

build/linux.m1lli: build/m1lli.tar.gz
	$(CP) build/m1lli.tar.gz build/linux.m1lli

build/%-m1lli.tar: build/%.image build/script
	$(MKDIR) build/$*-m1lli
	$(CP) $< build/$*-m1lli/Image
	$(CP) build/script build/$*-m1lli/script
	(cd build; cd $*-m1lli; tar cvf ../$*-m1lli.tar Image script)

build/%-m1lli.tar.gz: build/%-m1lli.tar
	gzip < $< > $@

build/%.m1lli: build/%-m1lli.tar.gz
	$(CP) $< $@

build/m1n1.tar: build/m1n1.image.macho.image build/m1n1.elf build/script
	cp build/m1n1.macho.image build/m1n1.macho
	(cd build/m1n1; tar cvf m1n1.tar m1n1.image m1n1.elf script)

build/m1n1.tar.gz: build/m1n1.tar
	gzip < build/m1n1.tar > build/m1n1.tar.gz

m1lli-%!: build/%-m1lli.m1lli
	$(SUDO) perl ./misc/commfile-server.pl $<

m1n1-shell!:
	M1N1DEVICE=$(M1N1DEVICE) python3 ./m1n1/proxyclient/shell.py

m1n1-%!: build/%.macho
	M1N1DEVICE=$(M1N1DEVICE) python3 ./m1n1/proxyclient/chainload.py $<

m1n1-m1n1!: build/m1n1.macho
	M1N1DEVICE=$(M1N1DEVICE) python3 ./m1n1/proxyclient/chainload.py ./build/m1n1.macho

m1lli-m1n1!: build/m1n1.tar.gz misc/commfile-server.pl
	$(SUDO) perl misc/commfile-server.pl build/m1n1.tar.gz

misc/linux-config/%.pospart: misc/linux-config/%
	egrep -v '^#' < misc/linux-config/$* > misc/linux-config/$*.pospart

build/image-to-macho: m1lli/macho-image/image-to-macho.c m1lli/asm-snippets/.all
	gcc -Os -o $@ $<

build/machoImage: build/machoImage.elf
	objcopy -O binary -S --only-section .text --only-section .data --only-section .got --only-section .last build/machoImage.elf build/machoImage

build/machoImage.elf: m1lli/machoImage/machoImage.c
	aarch64-linux-gnu-gcc -static -nostdlib -nolibc -Os -fPIC -o $@ $<

build/machoImage.s: m1lli/machoImage/machoImage.c
	aarch64-linux-gnu-gcc -S -static -nostdlib -nolibc -Os -fPIC -o $@ $<

build/linux-to-macho: m1lli/macho-linux/linux-to-macho.c
	gcc -o $@ $<

m1lli/asm-snippets/.all: \
	m1lli/asm-snippets/bring-up-phys..h \
	m1lli/asm-snippets/enable-all-clocks..h \
	m1lli/asm-snippets/fillrect..h \
	m1lli/asm-snippets/jump-to-start-of-page..h \
	m1lli/asm-snippets/mini-m1lli..h \
	m1lli/asm-snippets/mov-x0-0..h \
	m1lli/asm-snippets/perform-alignment..h \
	m1lli/asm-snippets/perform-alignment-2..h \
	m1lli/asm-snippets/perform-alignment-3..h \
	m1lli/asm-snippets/perform-alignment-4..h \
	m1lli/asm-snippets/reboot-physical..h \
	m1lli/asm-snippets/reboot-physical-2..h \
	m1lli/asm-snippets/remap-to-physical..h \
	m1lli/asm-snippets/x8r8g8b8..h
	touch $@

%.macho.image: %.macho build/machoImage
	cat build/machoImage $< > $@

%.image.macho: %.image build/image-to-macho
	build/image-to-macho $< $@

dtc:
	$(MKDIR) $@
	(cd dtc; ln -s ../linux/scripts/dtc/* .; rm Makefile; rm -f libfdt)
	(cd dtc; mkdir libfdt; cd libfdt; ln -s ../../linux/scripts/dtc/libfdt/* .)
	cp misc/dtc-Makefile $@/Makefile

build/dtc.native build/fdtoverlay.native:
	$(MKDIR) linux/o/scripts
	$(CP) m1lli/linux/linux.config linux/o/scripts/.config
	(cd linux; make O=o/scripts ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- oldconfig)
	(cd linux; make O=o/scripts ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- scripts)
	$(CP) linux/o/scripts/scripts/dtc/dtc build/dtc.native
	$(CP) linux/o/scripts/scripts/dtc/fdtoverlay build/fdtoverlay.native
build/dtc build/fdtoverlay: dtc
	$(MAKE) -C dtc
	$(CP) dtc/dtc dtc/fdtoverlay build/

%.dtb.dts: %.dtb build/dtc.native
	build/dtc.native -O dts -I dtb < $< > $@

%.dts.dtp: %.dts m1lli/src/fdt-to-props.pl
	perl m1lli/src/fdt-to-props.pl < $< > $@

%.dtp.dts: %.dtp m1lli/src/props-to-fdt.pl
	perl m1lli/src/fdt-to-props.pl < $< > $@

%.dts.dtb: %.dts build/dtc.native
	build/dtc.native -O dtb -I dts < $< > $@

%.adtb.dtp: %.adtb m1lli/scripts/adt2fdt.native
	m1lli/scripts/adt2fdt.native $< > $@

# This shortens dates. Update in 2999.
README.html: README.org $(wildcard */README.org) $(wildcard */*/README.org)
	emacs README.org --batch -Q -f org-html-export-to-html
	sed -i -e 's/\(2[0-9][0-9][0-9]\)-[0-9][0-9]-[0-9][0-9] [A-Z][a-z][a-z] [0-9][0-9]:[0-9][0-9]/\1/g' README.html

hammer!:
	while true; do make -j12 build/stage1.image.macho && (M1N1DEVICE=$(M1N1DEVICE) python3 ./m1n1/proxyclient/chainload.py ./build/stage1.image.macho); sleep 1; done

m1lli/asm-snippets/%.c.S: m1lli/asm-snippets/%.c
	aarch64-linux-gnu-gcc -march=armv8.4-a -Os -S -o $@ $<

m1lli/asm-snippets/%.o.S: m1lli/asm-snippets/%.S
	aarch64-linux-gnu-gcc -Os -c -o $@ $<

m1lli/asm-snippets/%.S.elf: m1lli/asm-snippets/%.S
	aarch64-linux-gnu-gcc -Os -static -nostdlib -o $@ $<

m1lli/asm-snippets/%.elf.bin: m1lli/asm-snippets/%.elf
	objcopy -O binary -S --only-section .pretext.0 --only-section .text --only-section .data --only-section .got --only-section .last --only-section .text.2 $< $@

m1lli/asm-snippets/%.bin.s: m1lli/asm-snippets/%.bin
	objdump -maarch64 -D -bbinary $< > $@

#m1lli/asm-snippets/%.h: m1lli/asm-snippets/%
#:	(NAME=$$(echo $* | sed -e 's/\..*//' -e 's/-/_/g'); echo "unsigned int $$NAME[] = {";  cat m1lli/asm-snippets/$* | od -tx4 --width=4 -Anone -v | sed -e 's/ \(.*\)/\t0x\1,/'; echo "};") > m1lli/asm-snippets/$*.h

m1lli/asm-snippets/%.s.h: m1lli/asm-snippets/%.s
	(NAME=$$(echo $* | sed -e 's/\..*//' -e 's/-/_/g'); echo "unsigned int $$NAME[] = {";  cat $< | tail -n +8 | sed -e 's/\t/ /g' | sed -e 's/^\(.*\):[ \t]*\([0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]\)[ \t]*\(.*\)$$/\t0x\2 \/\* \1: \3 \*\/,/g'; echo "};") > $@

m1lli/asm-snippets/%.dtb.h: m1lli/asm-snippets/%.dtb
	(echo "{";  cat $< | od -tx4 --width=4 -Anone -v | sed -e 's/ \(.*\)/\t0x\1,/'; echo "};") > $@

m1lli/asm-snippets/%..h: m1lli/asm-snippets/%.c.S.elf.bin.s.h
	$(CP) $< $@

m1lli/asm-snippets/%..h: m1lli/asm-snippets/%.S.elf.bin.s.h
	$(CP) $< $@

# GitHub integration

.github-init:
	bash github/artifact-init
	touch $@

artifacts artifacts/up artifacts/down: | .github-init
	$(MKDIR) $@

artifact-timestamp:
	touch $@
	sleep 1

artifacts/up/%.image: build/%.image artifact-timestamp | artifacts/up
	$(CP) $< $@

artifact-push!:
	(cd artifacts/up; for file in *; do if [ "$$file" -nt ../../artifact-timestamp ]; then name=$$(basename "$$file"); (cd ../..; bash github/ul-artifact "$$name" "artifacts/up/$$name"); fi; done)

.SECONDARY:
.PHONY: %!
