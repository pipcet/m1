# perl.tar.gz

This is a binary file containing the Perl interpreter and required libraries. It has been built on a Debian GNU/Linux sid system by running:

```
tar cvf ~/perl.tar /usr/bin/perl /lib/aarch64-linux-gnu/libdl.so.2 /lib/aarch64-linux-gnu/libm.so.6 /lib/aarch64-linux-gnu/libcrypt.so.1 /lib/ld-linux-aarch64.so.1 /lib/aarch64-linux-gnu/libdl-2.31.so /lib/aarch64-linux-gnu/libm-2.31.so /lib/aarch64-linux-gnu/libcrypt.so.1.1.0 /lib/aarch64-linux-gnu/ld-2.31.so /lib/aarch64-linux-gnu/libc.so.6 /lib/aarch64-linux-gnu/libc-2.31.so /lib/aarch64-linux-gnu/libpthread.so.0 /lib/aarch64-linux-gnu/libpthread-2.31.so
```

and compressed with

```
gzip ~/perl.tar
```
