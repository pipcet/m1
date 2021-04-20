# m1
GNU/Linux on an Apple M1-based MacBook Pro

Platform name (SMC `RPlt`, ADT): J293

## Software

### Boot loader

I sometimes use m1n1 at https://github.com/AsahiLinux/m1n1, particularly for development.

### Preloader

Corellium preloader at https://github.com/corellium/preloader-m1.

### Linux kernel

Based on the Corellium repo at https://github.com/corellium/linux-m1, currently Linux 5.12.0-rc7

### Distribution

Debian GNU/Linux sid, https://www.debian.org.

### Windowing System

X.org, https://www.xorg.freedesktop.org.

## Hardware

### CPU: supported

Apple M1 SOC. Four "performance" cores plus four "efficiency" cores each implementing identical ARM64/AArch64-compatible instruction sets.

#### CPU power management: supported

### GPU: unsupported

Apple M1 SOC.

### Video output: supported, no acceleration

#### Frame buffer: supported

2560x1600 `x8r8g8b8` frame buffer, supported through the simple-framebuffer driver.

#### Bitblt: not supported(?)

I'm not sure about that one, as video operations seem very fast...

#### LCD backlight: disabling documented, no brightness control

### Video codec acceleration: not supported

### Camera: not supported
### Fingerprint reader: not supported
### Power button: documented, no interrupt yet

Long-press for poweroff works

SMC key `MBSe`, bit 0.

### Lid switch: documented, no interrupt yet

SMC key `MSLD`, bit 0, 1 for closed.

### Ambient Light Sensor: not supported
### Audio: not supported

### Keyboard: supported
#### keyboard backlight: supported, not yet merged
### Touch pad: supported
### Touch bar: not supported
#### Touch bar display: not supported
#### Touch bar touchscreen: not supported
#### Touch bar backlight: not supported

### USB host mode: supported
### USB power-receiving mode: not supported

Charging works if power supply is connected at boot time and never disconnected.

### Storage
#### NVME storage: supported
#### SPI NOR flash (boot ROM): supported
#### NVRAM: supported
#### RTC: supported
#### USB mass storage: supported

### Hardware sensors
#### Temperature sensors: documented
#### Power meters: documented
#### Voltage meters: documented
#### Battery status: documented
### Fans: read-only access documented
#### Fan status: documented
#### Fan control: not supported

### Audio: not supported

### Wireless
#### WiFi: supported (proprietary firmware blob)
#### Bluetooth: not supported
#### NFC: not supported (I'm not even sure it's present)

### Power management
#### System reboot: supported
#### System poweroff: supported
#### System suspend/resume: not supported

### RTC: supported
