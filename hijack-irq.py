base = 0x803b28000
print(f"base at {read64(0xb20000008):x}")
base = read64(0xb20000008)
offset = 0x4194000 - 8 
#code = [0xa9bf07e0,	0xd11003e0,	0x58000141,	0xf9000001,	0xd5382001,	0xd503201f,	0xa94007e0,	0xd503201f,	0x1400041c,	0xd503201f,	0xd503201f,	0xd503201f,	0x07b5a3da3, 0xaff2a7a3]
# code = [0xa9bf07e0,	0xd11003e0,	0x58000141,	0xd503201f,	0xd5382001,	0xd503201f,	0xa94007e0,	0xd503201f,	0x1400041c,	0xd503201f,	0xd503201f,	0xd503201f,	0x07b5a3da3, 0xaff2a7a3]
# code = [0xd503201f, 0xd503201f, 0xd503201f, 0xd503201f, 0xd503201f, 0xd503201f, 0xd503201f, 0xd503201f, 0x1400041c,	0xd503201f,	0xd503201f,	0xd503201f,	0x07b5a3da3, 0xaff2a7a3]

for irq in [0x6a, 0x35d, 0x359, 0x269, 0x0d]:
    write32(0x23b100000 + 0x3000 + 4 * irq, 0x80)

code = [0xa9bf07e0,0xd11003e0,0x9272c400,0x58000121,0xf9000001,0xd5382001,0xa94007e0,0x910043ff,0x1400041c,0xd503201f,0xd503201f,0xd503201f,0x7b5a3da3,0x2ff2a7a3]
if True:
    for i in range(len(code) - 1, 0, -1):
        write32(base + 0xc02080 + 4 * i, code[i])

write32(base + 0xc02080, 0x14000424);
for i in range(0, len(code)):
    print(f"{i:x} {read32(base + 0xc02080 + 4 * i):x}")

write32(base + 0xc02080, code[0])

stackbase = 0
if True:
    udelay(100000)
    off = 0x808000000
    for i in range(0 + off, 0xb00000000, 16384):
        val = read64(i)
        if val & 0xffff == 0x3da3:
            print(f"{i:x} {read64(i):x}")
            stackbase = i
            break

# 0xd5382021 - ttrb1_el1
# 0xd53c2001 - ttrb0_el2
# 0xd53c2021 - ttrb1_el2: no entry?
code = [0xa9bf07e0,	0xd11003e0,	0x9272c400,	0x58000121,	0xd53c2021,	0xf9000001,	0xa94007e0,	0x910043ff,	0x1400041c,	0xd503201f,	0xd503201f,	0xd503201f,	0x00000000,	0x0000000b]

write32(base + 0xc02080, 0x14000424);
if True:
    for i in range(len(code) - 1, 0, -1):
        write32(base + 0xc02080 + 4 * i, code[i])

for i in range(0, len(code)):
    print(f"{i:x} {read32(base + 0xc02080 + 4 * i):x}")

write32(base + 0xc02080, code[0])

for i in range(0, 100):
    read64(stackbase)

memptr = 0xb90000000

def malloc(size):
    global memptr
    ret = memptr
    memptr += size
    print(f"malloc returning {ret:x}")
    return ret

def install_page(va, pa, executable=False):
    off0 = ((va >> 14) >> 11 >> 11) & 2047
    off1 = ((va >> 14) >> 11) & 2047
    off2 = ((va >> 14)) & 2047
    level0 = read64(stackbase)
    level1 = read64(level0 + off0 * 8)
    if level1 & 3 == 0:
        write64(level0 + off0 * 8, malloc(16384) | 3)
        return install_page(va, pa, executable)
    level1 &= 0x000000fffffff000
    level2 = read64(level1 + off1 * 8)
    if level2 & 3 == 0:
        write64(level1 + off1 * 8, malloc(16384) | 3)
        return install_page(va, pa, executable)
    level2 &= ~3
    pte = 0x60000000000603
    if executable:
        pte = 0x40000000000683
    write64(level2 + off2 * 8, pte | pa)

level1 = 0xb90000000
level2 = level1 + 32768
level3 = level2 + 32768
page = malloc(16384)

level0 = read64(stackbase)
print(f"level0: {level0:x}")

# 0xfffffff800000000
#  bits 0-14: 0
#  bits 14-25: 0
#  bits 25-36: 100..
#  bits 36-47: 111..11

install_page(0xfffffff800000000, page, executable=True)
install_page(0xfffffff000000000, page, executable=False)
install_page(0xfffffff800004000, page, executable=False)
# write64(level2, page |         0x40000000000683)
# write64(level2 + 8 * 1, page | 0x60000000000603)
# write64(level1 + 1024 * 8, level2 | 3)
# write64(level0 + 2047 * 8, level1 | 3)

code = [0xa9bf07e0, 0xd2c00100, 0xb25c6c00, 0xd538c001, 0xf9000001, 0xa94007e0,0x910043ff,0x1400041d]

time.sleep(5)

print("word 0 is ", read64(0xb80000000))

print("writing code")
write32(base + 0xc02080, 0x14000424);
if False:
    for i in range(len(code) - 1, 0, -1):
        write32(base + 0xc02080 + 4 * i, code[i])

if False:
    write32(base + 0xc02080, code[0]);

print("written")
for i in range(0, 128):
    print(f"word 0 is {read64(page):x}")

write64(page, 0)
#while(read64(page) == 0):
#    print(f"word 0 is {read64(page):x}")

vbar_old = read64(page)
print(f"vbar_old is {vbar_old:x}")

write32(base + 0xc02080, 0x14000424);

# code = [0xd503201f, 0xd503201f, 0xd503201f, 0xd503201f, 0xd503201f, 0xd503201f, 0xd503201f, 0xd503201f, 0xd503201f, 0xd503201f, 0xd503201f, 0xd503201f, 0xd503201f, 0xd503201f, 0xd503201f, 0xd503201f, 0xd503201f, 0xd503201f, 0xd503201f, 0xd503201f, 0xd503201f, 0xd503201f, 0xd503201f, 0xd503201f, 0xd503201f, 0xd503201f, 0xd503201f, 0xd503201f, 0xd503201f, 0xa94007e0, 0x910043ff, 0x17ffffe1];

code = [0x14000002,0x14000423,0xa9bf07e0,0xa9bf7bfd,0x58000100,0x58000121,0xd63f0000,0xa9407bfd,0xa94107e0,0x910083ff,0x17fffff7,0xd65f03c0,0x00000000,0xfffffff8,0x00000000,0x00000000]

print(len(code))

for off in range(0, 0x800, 0x80):
    for i in range(2, len(code)):
        write32(base + 0xc02000 + off + 4 * i, code[i])
    oldbr = read32(base + 0xc02000 + off)
    if oldbr & 0xff000000 == 0x14000000:
        newbr = oldbr - 1
        print(f"rewrote {oldbr:x} to {newbr:x}")
        write32(base + 0xc02000 + off + 0x4, newbr)
    write32(base+0xc02000 + off + 0x38, off)

if True:
    f = open("m1lli/asm-snippets/injector-page.S.elf.bin", "rb")
    writemem(page, f.read(1024 * 1024))
    # write32(page, 0xd65f03c0)
    write32(base + 0xc02080, code[0])
    write32(base + 0xc02000, code[0])
    write32(base + 0xc02400, code[0])
    write32(base + 0xc02200, code[0])
    # write32(base + 0xc02100, code[0])
    # write32(base + 0xc02180, code[0])

global_last_pa = 0

def scan_virtual_range(va):
    global global_last_pa
    off0 = ((va >> 14) >> 11 >> 11) & 2047
    off1 = ((va >> 14) >> 11) & 2047
    off2 = ((va >> 14)) & 2047
    level0 = read64(stackbase)
    pte1 = level1 = read64(level0 + off0 * 8)
    if level1 & 3 == 0:
        return (va + (1 << (14 + 11 + 11))) & ~((1 << 14 + 11 + 11) - 1)
    level1 &= 0x000000fffffff000
    pte2 = level2 = read64(level1 + off1 * 8)
    if level2 & 3 == 0:
        return (va + (1 << (14 + 11))) & ~((1 << 14 + 11) - 1)
    level2 &= 0x000000fffffff000
    pte3 = level3 = read64(level2 + off2 * 8)
    if level3 & 3 == 0:
        return (va + (1 << (14))) & ~((1 << 14) - 1)
    level3 &= 0x000000fffffff000
    if level3 & 0x800000000 != 0x800000000:
        print(f"va {va:x} maps to {pte3:x} (via {pte1:x}, {pte2:x})")
        if False and level3 & 0xfffff0000 == 0x23b100000:
            write64(level2 + off2 * 8, read64(level2 + off2 * 8) & ~3)
            print(f"(unmapped, AIC)")
        if False and level3 & 0xfffff0000 == 0x23d2b0000:
            write64(level2 + off2 * 8, read64(level2 + off2 * 8) & ~3)
            print(f"(unmapped, WDT/Reset)")
    global_last_pa = level3
    return (va + (1 << (14))) & ~((1 << 14) - 1)

# global_va = 0xffff000000000000
first_global_va =   0xffff7e0000000000
global_va = first_global_va
last_global_va = 0xfffffff000000000

while True:
    for irq in [0x6a, 0x35d, 0x359]:
        write32(0x23b100000 + 0x3000 + 4 * irq, 0x80)
    if False:
        for irq in [0x269, 0x0d]:
            write32(0x23b100000 + 0x3000 + 4 * irq, 0x80)
    for i in range(0,64):
        global_va = scan_virtual_range(global_va)
        if global_va >= last_global_va:
            global_va = first_global_va
        write64(page + 0x108, 0)
    print(f"{read64(page + 0x100):x} {read64(page + 0x108):x} {read64(page + 0x110):x} {read64(page + 0x118):x} {global_va:x} {global_last_pa:x} {read64(page + 0x128):x} FAR: {read64(page + 0x130):x} ELR: {read64(page + 0x138):x}")

print("done")

# vbar_el1 is 0xfffffe001ee2e000
# ttbr0_el1 is 807cac000
# ttbr1_el1 is 807cb0000

# level1 1800000b80000003
# level2 b80004003

"""
level0 8079ac000
level1 1800000b80000003
level2 b80004003
level3 b80008003

level1 18000008079b8003
level2 80a5f4003
level3 60000801f44603

level1 1800000b80000003
level2 b80004003
level3 60000800000603
"""

# TCR:  10800226511a511
# T0SZ 0x11
# IRGN0 1
# ORGN0 1
# T1SZ 0x11 : region size is 2^(64 - 17) = 2^(47) bytes. We start at level 1.
# 47 = 14 + 23?
# IRGN1 1
# ORGN1 1
# SH1 2 : outer sharable
# TG1 1 : granule size is 16 KB
# IPS 2 : IPS is 40 bits
# TBI0 1
# TBI1 0
# HA 0
# HD 0
# HPD0 0
# HPD1 0
# RES0 0
# E0PD1 1
