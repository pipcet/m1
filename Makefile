CROSS_COMPILE ?= aarch64-linux-gnu-
M1N1DEVICE ?= $(shell ls /dev/ttyACM* | tail -1)
MKDIR ?= mkdir -p
CP ?= cp
CAT ?= cat
TAR ?= tar
PWD = $(shell pwd)
SUDO ?= $(and $(filter pip,$(shell whoami)),sudo)

# INCLUDE_DEBOOTSTRAP = t
INCLUDE_MODULES = t

all: build/stage1.macho build/stage2.macho build/stage3.macho build/linux.macho build/m1n1.tar.gz

%/:
	$(MKDIR) $@

build m1lli/scripts build/m1n1 build/debootstrap:
	$(MKDIR) $@

clean:
	rm -rf build m1lli/asm-snippets/*.*.* m1lli/asm-snippets/.all linux/o

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

build/%.dtb: build/%.image
	$(MAKE) linux/o/$*/arch/arm64/boot/dts/apple/apple-m1-j293.dtb.dts.dtb
	$(CP) linux/o/$*/arch/arm64/boot/dts/apple/apple-m1-j293.dtb.dts.dtb $@

build/tunable.dtp: m1lli/asm-snippets/maximal-dt.dts.dtb.dts.dtp
	egrep '(tunable|thunderbolt-drom)' < $< > $@

build/linux.image: m1lli/asm-snippets/maximal-dt.dts.dtb.h

build/stage2.cpiospec: build/stage2/initfs/boot/initfs

define perstage
build/$(stage)/initfs:
	$$(MKDIR) $$@

build/$(stage)/initfs/:
	$$(MKDIR) $$@

build/$(stage)/initfs/%/:
	$$(MKDIR) $$@

build/$(stage)/initfs/perl.tar.gz: binaries/perl.tar.gz | build/$(stage)/initfs
	cp $$< $$@

build/$(stage)/initfs/%: build/% | build/$(stage)/initfs
	cp $$< $$@

build/$(stage)/initfs/bin/%: build/% | build/$(stage)/initfs/bin/
	cp $$< $$@
	chmod a+x $$@

build/$(stage)/initfs/boot/fdt: m1lli/asm-snippets/maximal-dt.dts.dtb | build/$(stage)/initfs/boot/
	cp $$< $$@

build/$(stage)/initfs/init: m1lli/$(stage)/init | build/$(stage)/initfs/
	cp $$< $$@
	chmod a+x $$@

build/$(stage).cpiospec: \
	m1lli/$(stage)/fixed.cpiospec \
	build/$(stage)/initfs/perl.tar.gz \
	build/$(stage)/initfs/m1lli-scripts.tar \
	build/$(stage)/initfs/bin/busybox \
	build/$(stage)/initfs/bin/kexec \
	build/$(stage)/initfs/boot/Image \
	build/$(stage)/initfs/boot/tunable.dtp \
	build/$(stage)/initfs/init \
	build/$(stage)/initfs/m1lli \
	build/$(stage)/initfs/m1n1.macho.image \
	build/$(stage)/initfs/bin/commfile \
	build/$(stage)/initfs/bin/dtc \
	build/$(stage)/initfs/bin/fdtoverlay \
	build/$(stage)/initfs/bin/memtool \
	build/$(stage)/initfs/boot/fdt
	(cat $$<; \
	 ($$(foreach file,$$(patsubst build/$(stage)/initfs/%,%,$$(wordlist 2,$$(words $$^),$$^)),echo dir $$(dir $$(patsubst %/,%,$$(file))) 755 0 0; echo file $$(file) ../../../build/$(stage)/initfs/$$(file) 755 0 0;))) | sort | uniq > $$@
endef

build/debootstrap.initfs: build/debootstrap/.stage1
	(cd build/debootstrap; sudo find . -print0 | cpio --null -o --format=newc) | gzip > $@

ifneq ($(INCLUDE_MODULES),)
build/linux/initfs/modules/brcmfmac.ko: build/modules.tar  | build/linux/initfs/modules/
	cp linux/o/linux/drivers/net/wireless/broadcom/brcm80211/brcmfmac/brcmfmac.ko $@

build/linux/initfs/modules/brcmutil.ko: build/modules.tar | build/linux/initfs/modules/
	cp linux/o/linux/drivers/net/wireless/broadcom/brcm80211/brcmutil/brcmutil.ko $@

build/linux.cpiospec: build/linux/initfs/modules/brcmfmac.ko
build/linux.cpiospec: build/linux/initfs/modules/brcmutil.ko

build/stage3.cpiospec: \
	build/stage3/initfs/modules/applespi.ko \
	build/stage3/initfs/modules/pcie-apple-m1-nvme.ko
endif

build/stage1.cpiospec: build/stage1/initfs/boot/stage2.dtb

build/stage2.cpiospec: build/stage2/initfs/boot/linux.dtb

ifneq ($(INCLUDE_STAGE_3),)
build/stage2.cpiospec: build/stage2/initfs/boot/stage3.dtb
endif

$(foreach stage,stage1 stage2 stage3 linux parasite usbparasite harbinger,$(eval $(perstage)))

build/%/initfs/boot/tunable.dtp: build/tunable.dtp | build/%/initfs/boot/
	cmp $< $@ || cp $< $@

build/stage1/initfs/boot/stage2.dtb: build/stage2.dtb | build/stage1/initfs/boot/
	cmp $< $@ || cp $< $@

build/stage2/initfs/boot/stage3.dtb: build/stage3.dtb | build/stage2/initfs/boot/
	cmp $< $@ || cp $< $@

build/stage2/initfs/boot/linux.dtb: build/linux.dtb | build/stage2/initfs/boot/
	cp $< $@

build/stage2/initfs/boot/tunable.dtp: build/tunable.dtp | build/stage2/initfs/boot/
	cp $< $@

build/harbinger/initfs/boot/Image: build/m1n1.macho.image | build/harbinger/initfs/boot/
	cp $< $@

build/stage1/initfs/boot/Image: build/stage2.image | build/stage1/initfs/boot/
	cp $< $@

build/stage2/initfs/boot/Image: build/linux.image | build/stage2/initfs/boot/
	cp $< $@

build/stage2/initfs/boot/initfs: build/linux.initfs | build/stage2/initfs/boot/
	cp $< $@

build/stage2/initfs/boot/debootstrap.initfs: build/debootstrap.initfs | build/stage2/initfs/boot/
	cp $< $@

ifneq ($(INCLUDE_STAGE_3),)
build/stage2/initfs/boot/stage3.image: build/stage3.image | build/stage3/initfs/boot/
	cp $< $@
endif

build/parasite/initfs/boot/Image: | build/parasite/initfs/boot/
	touch $@

build/usbparasite/initfs/boot/Image: | build/usbparasite/initfs/boot/
	touch $@

build/stage3/initfs/boot/Image: build/linux.image | build/stage3/initfs/boot/
	cp $< $@

build/linux/initfs/boot/Image: | build/linux/initfs/boot/
	touch $@

build/stage3.image: m1lli/stage3/init build/linux.dtb build/linux.macho m1lli/asm-snippets/maximal-dt.dts.dtb.h build/memtool build/m1n1.macho.image build/stage3.cpiospec

build/stage2.image: m1lli/stage2/init build/linux.dtb build/linux.macho m1lli/asm-snippets/maximal-dt.dts.dtb.h build/memtool build/m1n1.macho.image build/stage2.cpiospec

build/stage1.image: build/stage2.image build/stage2.dtb build/dtc build/fdtoverlay build/linux.macho m1lli/asm-snippets/maximal-dt.dts.dtb.h build/stage1.cpiospec

build/parasite.image: build/dtc build/fdtoverlay m1lli/asm-snippets/maximal-dt.dts.dtb.h build/parasite.cpiospec

build/usbparasite.image: build/dtc build/fdtoverlay m1lli/asm-snippets/maximal-dt.dts.dtb.h build/usbparasite.cpiospec

build/usbparasite.cpiospec: \
	build/usbparasite/initfs/bin/scanmem \
	build/usbparasite/initfs/bin/pt \
	build/usbparasite/initfs/bin/wait4mmio \
	build/usbparasite/initfs/bin/mmio \
	build/usbparasite/initfs/bin/wait4pt

build/usbparasite/initfs/bin/scanmem: m1lli/scripts/scanmem
	cp $< $@

build/usbparasite/initfs/bin/pt: m1lli/scripts/pt m1lli/asm-snippets/.all
	cp $< $@

build/usbparasite/initfs/bin/wait4mmio: m1lli/scripts/wait4mmio
	cp $< $@

build/usbparasite/initfs/bin/mmio: m1lli/scripts/mmio
	cp $< $@

build/usbparasite/initfs/bin/wait4pt: m1lli/scripts/wait4pt
	cp $< $@

build/harbinger.image: m1lli/harbinger/init build/harbinger.cpiospec

build/linux.initfs: build/linux.cpiospec build/linux.image
	(cd linux/o/linux; ../../usr/gen_initramfs.sh -o $(shell pwd)/$@ ../../../$<)

build/m1lli-scripts.tar: m1lli/scripts/adt-convert.pl m1lli/scripts/adt-transform.pl m1lli/scripts/fdt-to-props.pl m1lli/scripts/fdtdiff.pl m1lli/scripts/props-to-fdt.pl m1lli/scripts/adt2fdt m1lli/scripts/adtdump m1lli/scripts/adtp
	(cd m1lli/scripts; tar c adt-convert.pl adt-transform.pl fdt-to-props.pl fdtdiff.pl props-to-fdt.pl adt2fdt adtp) > build/m1lli-scripts.tar

m1lli/scripts/%.pl: m1lli/src/%.pl | m1lli/scripts
	$(CP) $< $@

m1lli/scripts/adt2fdt: m1lli/src/adt2fdt.cc
	aarch64-linux-gnu-g++ -Os -static -o $@ $<

m1lli/scripts/adtp: m1lli/src/adtp.cc
	aarch64-linux-gnu-g++ -Os -static -o $@ $<

m1lli/scripts/adtdump: m1lli/src/adtdump.c
	aarch64-linux-gnu-gcc -Os -static -o $@ $<

m1lli/scripts/adt2fdt.native: m1lli/src/adt2fdt.cc
	g++ -Os -o $@ $<

m1lli/scripts/adtp.native: m1lli/src/adtp.cc
	g++ -Os -o $@ $<

m1lli/scripts/scanmem: m1lli/src/scanmem.c m1lli/src/ptstuff.h m1lli/asm-snippets/.all
	aarch64-linux-gnu-gcc -Os -static -o $@ -pthread $<

m1lli/scripts/pt: m1lli/src/pt.c m1lli/src/ptstuff.h m1lli/asm-snippets/.all
	aarch64-linux-gnu-gcc -Os -static -o $@ $<

m1lli/scripts/wait4mmio: m1lli/src/wait4mmio.c m1lli/src/ptstuff.h m1lli/asm-snippets/.all
	aarch64-linux-gnu-gcc -Os -static -o $@ $<

m1lli/scripts/mmio: m1lli/mmio/mmio.cc m1lli/asm-snippets/.all
	aarch64-linux-gnu-g++ -Os -static -o $@ $<

m1lli/scripts/wait4pt: m1lli/src/wait4pt.c m1lli/src/ptstuff.h m1lli/asm-snippets/.all
	aarch64-linux-gnu-gcc -Os -static -o $@ $<

build/memtool: stamp/memtool
	(cd memtool; autoreconf -fi)
	(cd memtool; ./configure --host=aarch64-linux-gnu)
	$(MAKE) -C memtool
	$(CP) memtool/memtool $@

build/modules.tar: build/linux.image | build
	rm -rf build/modules
	$(MAKE) -C linux ARCH=arm64 CROSS_COMPILE=$(CROSS_COMPILE) O=o/linux modules
	$(MKDIR) build/modules
	$(MAKE) -C linux ARCH=arm64 CROSS_COMPILE=$(CROSS_COMPILE) O=o/linux INSTALL_MOD_PATH=$(PWD)/build/modules modules_install
	(cd build/modules; $(TAR) cf ../modules.tar .)

build/%.macho: build/%.image build/m1-%.dtb $(wildcard preloader-m1/*.c) $(wildcard preloader-m1/*.h) $(wildcard preloader-m1/*.S) $(wildcard preloader-m1/Makefile) | build
	$(CP) build/$*.image preloader-m1/Image
	$(CP) build/m1-$*.dtb preloader-m1/apple-m1-j293.dtb
	$(MAKE) -C preloader-m1
	$(CP) preloader-m1/linux.macho build/$*.macho

build/m1-stage1.dtb: m1lli/stage1/preloader.dts build/dtc.native
	build/dtc.native -Idts -Odtb $< > $@

build/m1-linux.dtb: m1lli/stage1/preloader.dts build/dtc.native
	build/dtc.native -Idts -Odtb $< > $@

build/m1n1.macho: stamp/m1n1 build/dtc.native | build/m1n1
	$(MAKE) DTC=$(shell pwd)/build/dtc.native -C m1n1
	$(CP) m1n1/build/m1n1.macho $@

build/m1n1.elf: stamp/m1n1 | build/m1n1
	$(MAKE) -C m1n1
	$(CP) m1n1/build/m1n1.elf $@

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

build/m1n1.image: build/m1n1.macho.image
	$(CP) $< $@

build/%.image.m1lli.d: m1lli/%/script
	$(MKDIR) $@

build/%.image.m1lli.d/script: m1lli/%/script build/%.image.m1lli.d
	$(CP) $< $@
	chmod u+x $@

build/%.image.m1lli.d/Image: build/%.image
	$(CP) $< $@

build/script: misc/script-m1n1
	$(CP) misc/script-m1n1 build/script
	chmod u+x build/script

build/m1lli.tar: build/linux.image build/script
	(cd build; cp linux.image Image; tar cf $< Image script)

build/m1lli.tar.gz: build/m1lli.tar
	gzip < build/m1lli.tar > build/m1lli.tar.gz

m1lli/%.image.macho: m1lli/%
	ln -sf $(notdir $<) $@

build/%.image.m1lli: build/%.image.m1lli.d/script build/%.image.m1lli.d/Image
	(cd $(dir $<); tar cz .) > $@

m1lli/%.m1lli!: %.m1lli
	$(SUDO) perl misc/commfile-server.pl $<

build/%-m1lli.tar: build/%.image m1lli/%/script
	$(MKDIR) build/$*-m1lli
	$(CP) $< build/$*-m1lli/Image
	$(CP) m1lli/$*/script build/$*-m1lli/script
	(cd build; cd $*-m1lli; tar cf ../$*-m1lli.tar Image script)

build/%-m1lli.tar.gz: build/%-m1lli.tar
	gzip < $< > $@

build/%.m1lli: build/%-m1lli.tar.gz
	$(CP) $< $@

m1lli-%!: build/%.m1lli{m1lli}
	$(SUDO) perl ./misc/commfile-server.pl $<

m1n1-wait!:
	while [ x"$(M1N1DEVICE)" = "x" ]; do sleep 1; done
	true

m1n1-shell!:
	M1N1DEVICE=$(M1N1DEVICE) python3 ./m1n1/proxyclient/shell.py

m1n1-%!: build/%.macho
	M1N1DEVICE=$(M1N1DEVICE) python3 ./m1n1/proxyclient/chainload.py $<

m1n1-m1n1!: build/m1n1.macho
	M1N1DEVICE=$(M1N1DEVICE) python3 ./m1n1/proxyclient/chainload.py ./build/m1n1.macho

m1lli-m1n1!: build/m1n1.tar.gz misc/commfile-server.pl
	$(SUDO) perl misc/commfile-server.pl build/m1n1.tar.gz

%.macho{m1n1}: %.macho
	M1N1DEVICE=$(M1N1DEVICE) python3 ./m1n1/proxyclient/chainload.py --sepfw $<

%.macho{m1n1.parasite}: %.macho
	M1N1DEVICE=$(M1N1DEVICE) python3 ./m1n1/proxyclient/chainload-linux.py $<

%.macho{m1n1.high}: %.macho
	M1N1DEVICE=$(M1N1DEVICE) python3 ./m1n1/proxyclient/chainload.py --high $<

macos{m1n1}: m1lli/asm-snippets/.all build/usbparasite.image.macho build/m1n1.macho
#	M1N1DEVICE=$(M1N1DEVICE) python3 ./m1n1/proxyclient/shell.py < m1lli/scripts/disable-irqs
	M1N1DEVICE=$(M1N1DEVICE) python3 ./m1n1/proxyclient/chainload.py --sepfw --debug ~/m1/macos/kernelcache

macos{m1n1.nodebug}: m1lli/asm-snippets/.all build/usbparasite.image.macho build/m1n1.macho
#	M1N1DEVICE=$(M1N1DEVICE) python3 ./m1n1/proxyclient/shell.py < m1lli/scripts/disable-irqs
	M1N1DEVICE=$(M1N1DEVICE) python3 ./m1n1/proxyclient/chainload.py --sepfw ~/m1/macos/kernelcache

macos{m1n1.asahi}: m1lli/asm-snippets/.all build/m1n1.macho
#	M1N1DEVICE=$(M1N1DEVICE) python3 ./m1n1/proxyclient/shell.py < m1lli/scripts/disable-irqs
	M1N1DEVICE=$(M1N1DEVICE) python3 ./m1n1/proxyclient/chainload-asahi.py --xnu ~/m1/macos/kernelcache

%.m1lli{m1lli}: %.m1lli
	$(SUDO) perl misc/commfile-server.pl $<

%/linux.config.pospart: %/linux.config
	(egrep -v '^#' | egrep '.') < $< > $@

build/image-to-macho: m1lli/macho-image/image-to-macho.c m1lli/asm-snippets/.all
	gcc -Os -o $@ $<

build/macho-to-image: m1lli/macho-image/macho-to-image.c m1lli/asm-snippets/.all
	gcc -Os -o $@ $<

build/machoImage: build/machoImage.elf
	aarch64-linux-gnu-objcopy -O binary -S --only-section .text --only-section .data --only-section .got --only-section .last build/machoImage.elf build/machoImage

build/machoImage.elf: m1lli/machoImage/machoImage.c
	aarch64-linux-gnu-gcc -static -nostdlib -nolibc -Os -fPIC -o $@ $<

build/machoImage.s: m1lli/machoImage/machoImage.c
	aarch64-linux-gnu-gcc -S -static -nostdlib -nolibc -Os -fPIC -o $@ $<

build/linux-to-macho: m1lli/macho-linux/linux-to-macho.c
	gcc -o $@ $<

m1lli/asm-snippets/.all: \
	m1lli/asm-snippets/actual-vbar..h \
	m1lli/asm-snippets/actual-vbar-2..h \
	m1lli/asm-snippets/adr-dot-minus-0x2000..h \
	m1lli/asm-snippets/blank-screen-physical..h \
	m1lli/asm-snippets/br-x24..h \
	m1lli/asm-snippets/br24..h \
	m1lli/asm-snippets/bring-up-phys-2..h \
	m1lli/asm-snippets/bring-up-phys..h \
	m1lli/asm-snippets/cpu-init..h \
	m1lli/asm-snippets/delay-boot-linux..h \
	m1lli/asm-snippets/delay-loop..h \
	m1lli/asm-snippets/delay-then-boot-m1n1..h \
	m1lli/asm-snippets/disable-timers..h \
	m1lli/asm-snippets/enable-all-clocks..h \
	m1lli/asm-snippets/expose-ttbr..h \
	m1lli/asm-snippets/expose-ttbr-2..h \
	m1lli/asm-snippets/expose-ttbr-3..h \
	m1lli/asm-snippets/expose-ttbr-to-stack..h \
	m1lli/asm-snippets/fadescreen..h \
	m1lli/asm-snippets/fillrect..h \
	m1lli/asm-snippets/get-physical-address..h \
	m1lli/asm-snippets/hijack-irq-2..h \
	m1lli/asm-snippets/hijack-irq-3..h \
	m1lli/asm-snippets/hijack-irq-4..h \
	m1lli/asm-snippets/hijack-irq-5..h \
	m1lli/asm-snippets/hijack-irq-6..h \
	m1lli/asm-snippets/hijack-irq-7..h \
	m1lli/asm-snippets/hijack-irq-8..h \
	m1lli/asm-snippets/hijack-irq..h \
	m1lli/asm-snippets/image-header..h \
	m1lli/asm-snippets/infloop..h \
	m1lli/asm-snippets/inject..h \
	m1lli/asm-snippets/inject2..h \
	m1lli/asm-snippets/inject3..h \
	m1lli/asm-snippets/inject4..h \
	m1lli/asm-snippets/injector-page..h \
	m1lli/asm-snippets/injector-page-2..h \
	m1lli/asm-snippets/irq-handler-store-magic-cookie..h \
	m1lli/asm-snippets/irq-handler-store-ttbr..h \
	m1lli/asm-snippets/jump-back-by-0x2000..h \
	m1lli/asm-snippets/jump-back-by-0x4000..h \
	m1lli/asm-snippets/jump-to-start-of-page..h \
	m1lli/asm-snippets/macho-boot..h \
	m1lli/asm-snippets/macho-boot-2..h \
	m1lli/asm-snippets/mini-m1lli..h \
	m1lli/asm-snippets/mmiotrace..h \
	m1lli/asm-snippets/mov-x0-0..h \
	m1lli/asm-snippets/new-irq-handler-part1..h \
	m1lli/asm-snippets/new-irq-handler-part2..h \
	m1lli/asm-snippets/new-vbar-entry..h \
	m1lli/asm-snippets/new-vbar-entry-special..h \
	m1lli/asm-snippets/new-vbar-entry-for-mrs..h \
	m1lli/asm-snippets/nop..h \
	m1lli/asm-snippets/optimized-putc..h \
	m1lli/asm-snippets/perform-alignment-2..h \
	m1lli/asm-snippets/perform-alignment-3..h \
	m1lli/asm-snippets/perform-alignment-4..h \
	m1lli/asm-snippets/perform-alignment..h \
	m1lli/asm-snippets/reboot-physical-2..h \
	m1lli/asm-snippets/reboot-physical..h \
	m1lli/asm-snippets/redeye..h \
	m1lli/asm-snippets/remap-to-physical..h \
	m1lli/asm-snippets/restartm1n1-2..h \
	m1lli/asm-snippets/restartm1n1..h \
	m1lli/asm-snippets/restore-boot-args..h \
	m1lli/asm-snippets/save-boot-args..h \
	m1lli/asm-snippets/setvbar..h \
	m1lli/asm-snippets/turn-on-kb-backlight..h \
	m1lli/asm-snippets/vbar..h \
	m1lli/asm-snippets/vbar2..h \
	m1lli/asm-snippets/vbarstub..h \
	m1lli/asm-snippets/wait-for-confirmation..h \
	m1lli/asm-snippets/wait-for-confirmation-receiver..h \
	m1lli/asm-snippets/wait-for-confirmation-receiver-part2..h \
	m1lli/asm-snippets/x8r8g8b8..h
	touch $@

%.macho.image: %.macho build/macho-to-image
	build/macho-to-image $< $@

%.image.macho: %.image build/image-to-macho
	build/image-to-macho $< $@

dtc/.done:
	$(MKDIR) dtc
	(cd dtc; ln -s ../linux/scripts/dtc/* .; rm Makefile; rm -f libfdt)
	(cd dtc; mkdir libfdt; cd libfdt; ln -s ../../linux/scripts/dtc/libfdt/* .)
	cp misc/dtc-Makefile dtc/Makefile
	touch $@

build/dtc.native build/fdtoverlay.native:
	$(MKDIR) linux/o/scripts
	$(CP) m1lli/linux/linux.config linux/o/scripts/.config
	(cd linux; make O=o/scripts ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- oldconfig)
	(cd linux; make O=o/scripts ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- scripts)
	$(CP) linux/o/scripts/scripts/dtc/dtc build/dtc.native
	$(CP) linux/o/scripts/scripts/dtc/fdtoverlay build/fdtoverlay.native

build/dtc build/fdtoverlay: dtc/.done
	$(MAKE) -C dtc
	$(CP) dtc/dtc dtc/fdtoverlay build/

%.dtb.dts: %.dtb build/dtc.native
	build/dtc.native -O dts -I dtb < $< > $@

%.dts.dtp: %.dts m1lli/scripts/fdt-to-props.pl
	perl m1lli/scripts/fdt-to-props.pl < $< > $@

%.dtp.dts: %.dtp m1lli/scripts/props-to-fdt.pl
	perl m1lli/scripts/props-to-fdt.pl < $< > $@

%.dts.dtb: %.dts build/dtc.native
	build/dtc.native -O dtb -I dts < $< > $@

%.adtb.dtp: %.adtb m1lli/scripts/adtp.native
	m1lli/scripts/adtp.native $< > $@

# This shortens dates. Update in 2999.
README.html: README.org $(wildcard */README.org) $(wildcard */*/README.org)
	emacs README.org --batch -Q -f org-html-export-to-html
	sed -i -e 's/\(2[0-9][0-9][0-9]\)-[0-9][0-9]-[0-9][0-9] [A-Z][a-z][a-z] [0-9][0-9]:[0-9][0-9]/\1/g' README.html

hammer!:
	while true; do make -j12 build/stage1.image.macho && (M1N1DEVICE=$(M1N1DEVICE) python3 ./m1n1/proxyclient/chainload.py ./build/stage1.image.macho); sleep 1; done

m1lli/asm-snippets/%.c.S: m1lli/asm-snippets/%.c
	aarch64-linux-gnu-gcc -fno-builtin -ffunction-sections -march=armv8.5-a -Os -S -o $@ $<

m1lli/asm-snippets/%.o.S: m1lli/asm-snippets/%.S
	aarch64-linux-gnu-gcc -Os -c -o $@ $<

m1lli/asm-snippets/%.S.elf: m1lli/asm-snippets/%.S
	aarch64-linux-gnu-gcc -Os -static -march=armv8.5-a -nostdlib -o $@ $<

m1lli/asm-snippets/%.elf.bin: m1lli/asm-snippets/%.elf
	aarch64-linux-gnu-objcopy -O binary -S --only-section .pretext.0 --only-section .text --only-section .data --only-section .got --only-section .last --only-section .text.2 $< $@

m1lli/asm-snippets/%.bin.s: m1lli/asm-snippets/%.bin
	aarch64-linux-gnu-objdump -maarch64 --disassemble-zeroes -D -bbinary $< > $@

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

build/debootstrap/.stage1: | build/debootstrap/
	sudo DEBOOTSTRAP_DIR=$(shell pwd)/debootstrap ./debootstrap/debootstrap --foreign --arch=arm64 --include=dash,wget,busybox,busybox-static,network-manager,openssh-client,net-tools,libpam-systemd sid build/debootstrap http://deb.debian.org/debian
	touch $@

build/debootstrap/.stage15: build/debootstrap/.stage1 m1lli/debootstrap/init
	for a in build/debootstrap/var/cache/apt/archives/*.deb; do sudo dpkg -x $$a build/debootstrap; done
	sudo cp m1lli/debootstrap/init build/debootstrap/init
	sudo chmod a+x build/debootstrap/init
	sudo touch $@

build/debian-initfs.gz: build/debootstrap/.stage15
	(cd build/debootstrap; sudo find . | cpio -Hnewc -o) | gzip > $@

build/stage2/initfs/boot/debian-initfs.gz: build/debian-initfs.gz
	$(CP) $< $@

build/stage2/initfs/bin/debian: m1lli/stage2/bin/debian
	$(CP) $< $@
	chmod a+x $@

build/stage2/initfs/bin/kernel: m1lli/stage2/bin/kernel
	$(CP) $< $@
	chmod a+x $@

ifneq ($(INCLUDE_DEBOOTSTRAP),)
build/stage2.cpiospec: build/stage2/initfs/boot/debian-initfs.gz
build/stage2.cpiospec: build/stage2/initfs/bin/debian
endif
build/stage2.cpiospec: build/stage2/initfs/bin/kernel

# build/debootstrap.img.stage15: build/debootstrap/.stage15
# 	dd if=/dev/zero of=$@ bs=1M count=1024
# 	mkfs.ext4 $@
# 	sudo rmdir mnt
# 	mkdir mnt
# 	sudo mount -o loop $@ mnt
# 	sudo cp -av build/debootstrap/* mnt/
# 	sudo umount mnt
# 	touch $@

# build/debootstrap.img.stage2: build/debootstrap.img.stage15 build/debian-initfs.gz
# 	cp $< $@.tmp
# 	(echo "mount -t proc proc proc; mount -t sysfs sys sys; mount -t devtmpfs dev dev; depmod -a; modprobe virtio_blk; modprobe ext4; mkdir mnt; mount /dev/virtio0 /mnt "echo "echo root:!:0:0::/root:/bin/sh > /etc/passwd"; echo /debootstrap/debootstrap --second-stage) | cat
# 	qemu-system-aarch64 -drive id=rootimg,format=raw,if=none,file=$@.tmp -kernel ./build/debootstrap/boot/vmlinuz-*-arm64 -initrd ./build/debian-initfs.gz -M virt -m 2g -append 'console=ttyAMA0 TERM=dumb 1' -serial stdio -vnc :91 -cpu cortex-a57 -net user -device virtio-blk-device,drive=rootimg -net user -netdev user,id=unet -device virtio-net-device,netdev=unet

# PACKAGES_TO_REMOVE=debconf-i18n libbluetooth3 

build/debootstrap/.stage2: build/debootstrap/.stage1 | build/debootstrap/
	sudo chroot $(shell pwd)/build/debootstrap ./debootstrap/debootstrap --second-stage
	touch $@

build/debootstrap-stage1.tar.gz: build/debootstrap/.stage1 | build/
	(cd build/debootstrap; sudo tar czf ../$(notdir $@) .)

build/debootstrap-stage2.tar.gz: build/debootstrap/.stage2 | build/
	(cd build/debootstrap; sudo tar czf ../$(notdir $@) .)

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

artifacts/up/%.macho: build/%.macho artifact-timestamp | artifacts/up
	$(CP) $< $@

artifacts/up/%.tar.gz: build/%.tar.gz artifact-timestamp | artifacts/up
	$(CP) $< $@

artifact-push!:
	(cd artifacts/up; for file in *; do if [ "$$file" -nt ../../artifact-timestamp ]; then name=$$(basename "$$file"); (cd ../..; bash github/ul-artifact "$$name" "artifacts/up/$$name"); fi; done)
	rm -f artifacts/up/*

ship/m1-debian.macho: build/stage1.image.macho
	$(CP) $< $@

ship/%!: ship/m1-debian.macho | ship/ github/release/
	$(MAKE) github/release/list!
	for name in $$(cd ship; ls *); do for id in $$(jq ".[] | if .name == \"$$name\" then .id else 0 end" < github/assets/$*.json); do [ $$id != "0" ] && curl -sSL -XDELETE -H "Authorization: token $$GITHUB_TOKEN" "https://api.github.com/repos/$$GITHUB_REPOSITORY/releases/assets/$$id"; echo; done; done
	(for name in ship/*; do bname=$$(basename "$$name"); curl -sSL -XPOST -H "Authorization: token $$GITHUB_TOKEN" --header "Content-Type: application/octet-stream" "https://uploads.github.com/repos/$$GITHUB_REPOSITORY/releases/$$(cat github/release/\"$*\")/assets?name=$$bname" --upload-file $$name; echo; done)

github/release/list!: | github/release/
	curl -sSL https://api.github.com/repos/$$GITHUB_REPOSITORY/releases?per_page=100 | jq '.[] | [(.).tag_name,(.).id] | .[]' | while read tag; do read id; echo $$id > github/release/$$tag; done
	curl -sSL https://api.github.com/repos/$$GITHUB_REPOSITORY/releases/tags/latest | jq '.[.tag_name,.id] | .[]' | while read tag; do read id; echo $$id > github/release/$$tag; done
	ls -l github/release/

release!:
	this_release_date="$$(date --iso)"; \
	node ./github/release.js $$this_release_date $$this_release_date > github/release.json; \
	curl -sSL -XPOST -H "Authorization: token $$GITHUB_TOKEN" "https://api.github.com/repos/$$GITHUB_REPOSITORY/releases" --data '@github/release.json'; \
	sleep 1m; \
	$(MAKE) ship/$$this_release_date!

qemu!:
	git clone git://git.qemu.org/qemu.git qemu
	(cd qemu; ./configure --target-list=aarch64-linux-user --static --prefix=/usr)
	(cd qemu; make -kj3)
	(cd qemu; sudo make install)
	for i in /proc/sys/fs/binfmt_misc/*; do echo 0 | sudo tee $a; done || true
	(cd qemu; sudo bash scripts/qemu-binfmt-conf.sh || true)

%/checkout!:
	git submodule update --depth=1 --single-branch --init --recursive $*

.SECONDARY:
.PHONY: %! %}
