# m1
GNU/Linux on an Apple M1-based MacBook Pro

Platform name (SMC `RPlt`, ADT): J293

Boot loader: (sometimes) m1n1

Kernel: based on the Corellium repo, Linux 5.12.0-rc7

Distribution: Debian GNU/Linux sid

Hardware support status:

* CPU: supported
* GPU: not supported
* frame buffer: supported
* bitblt: not supported(?)
* keyboard: supported
* touchpad: supported
* touchbar: not supported
* keyboard backlight: supported
* LED backlight: enable/disable, no brightness control
* audio: not supported
* WiFi: supported with proprietary firmware
* Bluetooth: not supported
* USB: supported
* ambient light sensor: not supported
* temperature sensors: supported through SMC
* battery status: supported through SMC
* battery charging: not supported (charging works if power supply is connected at boot time, but having unplugged it once, the system will not charge again until next rebooted)
* NVME: supported
* fan control: not supported
* camera: not supported
* audio: not supported
* suspend to RAM: not supported
* poweroff: supported
* reboot: supported
* RTC: supported
* NVRAM: supported
* SPI NOR flash: supported
* docking station features: untested, no docking station
