base = 0x803b28000
print(f"base at {read64(0xb20000008):x}")
base = read64(0xb20000008)
offset = 0x4194000 - 8 
#code = [0xa9bf07e0,	0xd11003e0,	0x58000141,	0xf9000001,	0xd5382001,	0xd503201f,	0xa94007e0,	0xd503201f,	0x1400041c,	0xd503201f,	0xd503201f,	0xd503201f,	0x07b5a3da3, 0xaff2a7a3]
# code = [0xa9bf07e0,	0xd11003e0,	0x58000141,	0xd503201f,	0xd5382001,	0xd503201f,	0xa94007e0,	0xd503201f,	0x1400041c,	0xd503201f,	0xd503201f,	0xd503201f,	0x07b5a3da3, 0xaff2a7a3]
# code = [0xd503201f, 0xd503201f, 0xd503201f, 0xd503201f, 0xd503201f, 0xd503201f, 0xd503201f, 0xd503201f, 0x1400041c,	0xd503201f,	0xd503201f,	0xd503201f,	0x07b5a3da3, 0xaff2a7a3]

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

code = [0xa9bf07e0,	0xd11003e0,	0x9272c400,	0x58000121,	0xd5382021,	0xf9000001,	0xa94007e0,	0x910043ff,	0x1400041c,	0xd503201f,	0xd503201f,	0xd503201f,	0x00000000,	0x0000000b]

write32(base + 0xc02080, 0x14000424);
if True:
    for i in range(len(code) - 1, 0, -1):
        write32(base + 0xc02080 + 4 * i, code[i])

for i in range(0, len(code)):
    print(f"{i:x} {read32(base + 0xc02080 + 4 * i):x}")

write32(base + 0xc02080, code[0])

for i in range(0, 100):
    read64(stackbase)

level1 = 0xb80000000
level2 = level1 + 32768
level3 = level2 + 32768

level0 = read64(stackbase)
print(f"level0: {level0:x}")

# 0xfffffff800000000
#  bits 0-14: 0
#  bits 14-25: 0
#  bits 25-36: 100..
#  bits 36-47: 111..11

write64(level2, 0x60000b80000603)
write64(level1 + 1024 * 8, level2 | 3)
write64(level0 + 2047 * 8, level1 | 3)

code = [0xa9bf07e0, 0xd2c00100, 0xb25c6c00, 0xf9000000, 0xa94007e0,0x910043ff,0x1400041e,0xd503201f,0xd503201f,0x00000000,0x0000000b]

time.sleep(5)

print("word 0 is ", read64(0xb80000000))

if False:
    print(f"level0 {level0:x}")
    for off0 in range(0, 2048):
        pte = read64(level0 + 8 * off0)
        if pte != 0:
            print(f"level1 {pte:x}")
            level1 = pte & 0x000000fffffff000
            for off1 in range(0, 2048):
                pte1 = read64(level1 + 8 * off1)
                if pte1 != 0:
                    print(f"level2 {pte1:x}")
                    level2 = pte1 & 0xfffffff000
                    for off2 in range(0, 2048):
                        pte2 = read64(level2 + 8 * off2)
                        if pte2 != 0:
                            print(f"off {(((((off0 << 11) + off1) << 11) + off2) << 14):x} level3 {pte2:x}")

for i in range(0, 128):
    print(f"word 0 is {read64(0xb80000000):x}")

print("writing code")
write32(base + 0xc02080, 0x14000424);
if True:
    for i in range(len(code) - 1, 0, -1):
        write32(base + 0xc02080 + 4 * i, code[i])

write32(base + 0xc02080, code[0]);
print("written")
for i in range(0, 128):
    print(f"word 0 is {read64(0xb80000000):x}")

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
