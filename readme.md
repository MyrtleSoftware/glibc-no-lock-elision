# glibc without lock-elision

This shouldn't be needed with Ubuntu 16.04 or above, see the relavent launchpad issue: https://bugs.launchpad.net/ubuntu/+source/glibc/+bug/1642390

**Fiddling with libc has the potential to break your system. If you don't
understand 100% what's going on here, please talk to someone who does.**

**Tested only on Ubuntu 15.10.**

This is necessary for processors with the TSX feature to run Vivado 2016.2 and
other versions.

During synthesis, Vivado double frees a pthread mutex. This is illegal, but
without TSX glibc doesn't detect this. Disabling this feature with
`--disable-lock-elision` allows Vivado to continue on its buggy way,

## Do I need this

If Vivado is failing to synthesize with the error `Abnormal program termination
(11)` and a stack trace like the one in [err.log](err.log) then this could be
the package for you!

## Installing

### Ubuntu PPA

Philipp Wagner has created an Ubuntu PPA with this fix in which can be found
here: https://launchpad.net/~imphil/+archive/ubuntu/glibc-no-lockelision

### Prebuilt .deb files

Prebuilt versions of these files are available on the releases page of this
repo.

``` sh
sudo dpkg -i libc6_2.21-0ubuntu4.3_amd64.deb libc6-dev_2.21-0ubuntu4.3_amd64.deb libc6-dev-i386_2.21-0ubuntu4.3_amd64.deb libc6-i386_2.21-0ubuntu4.3_amd64.deb 
```

## To generate

### Install dependencies

Create a VM runing Ubuntu 15.10.

``` sh
sudo apt-get build-dep glibc
```

### Get the source

Either use the source in the [glibc-2.21](glibc-2.21) directory of this repo,
or create it yourself:

```
apt-get source glibc
cd glibc-2.21
```

Edit `debian/sysdeps/amd64.mk` changing `--enable-lock-elision` to
`--disable-lock-elision`.

You might also want to change `RUN_TESTSUITE` to `no` to save some time if
you're in a hurry.

You might also want to add `export DEB_BUILD_OPTIONS="parallel=8"` to the
beginning of the file to build multiple files in parallel.

### Build the .debs

``` sh
fakeroot dpkg-buildpackage -uc -us
```

The `.deb` files will have been placed in `..`

## Other program suffering from this issue

### The D2XX driver for some FTDI chips

The D2XX driver for some FTDI chips (http://www.ftdichip.com/Drivers/D2XX.htm) seems to have the very same problem. It crashes with this Stack Trace:

```
#0 __lll_unlock_elision (lock=0x7fffd8000de8, private=0) at ../sysdeps/unix/sysv/linux/x86/elision-unlock.c:29
#1 0x00007fffe5ef812f in EventDestroy (pE=0x7fffd8000de8) at Event.c:28
#2 0x00007fffe5ef257e in FT_Close (ftHandle=0x7fffd8000ae0) at ftd2xx.c:1813
#3 0x00007fffe6354d1d in LIBFTD2XX::Close(void*) () from /usr/local/lib64/digilent/adept/libdpcomm.so.2
#4 0x00007fffe6351ae6 in FTDIC::FEnumAndUpdateCache() () from /usr/local/lib64/digilent/adept/libdpcomm.so.2
#5 0x00007fffe634fb73 in FTDIC::FEnum(int, int, unsigned int, void*, DVCMG*) () from /usr/local/lib64/digilent/adept/libdpcomm.so.2
#6 0x00007fffe634deec in ENMMG::DoEnumThread() () from /usr/local/lib64/digilent/adept/libdpcomm.so.2
#7 0x00007fffe634d499 in EnumThread(void*) () from /usr/local/lib64/digilent/adept/libdpcomm.so.2
#8 0x00007fffeea1f70a in start_thread (arg=0x7fffdffff700) at pthread_create.c:333
#9 0x00007fffee03582d in clone () at ../sysdeps/unix/sysv/linux/x86_64/clone.S:109
```

Observed in Xilinx Impact while trying to program a Nexys Video.

### Digilent Inc's Waveforms 2015

See this thread: https://forum.digilentinc.com/topic/2936-waveforms-2015-segmentation-fault-ubuntu-16041-x86-64-analog-discovery-1-analog-discovery-2/

Digilent Inc's Waveforms 2015 crashes with this stack trace:

```
#0  __lll_unlock_elision (lock=0x7fff5c0281f8, private=0) at ../sysdeps/unix/sysv/linux/x86/elision-unlock.c:29
#1  0x00007fff6146b12f in EventDestroy () from /usr/lib64/digilent/adept/libftd2xx.so
#2  0x00007fff6146557e in FT_Close () from /usr/lib64/digilent/adept/libftd2xx.so
#3  0x00007fffed590a11 in ?? () from /usr/lib64/digilent/adept/libdpcomm.so.2
#4  0x00007fffed58b29b in ?? () from /usr/lib64/digilent/adept/libdpcomm.so.2
#5  0x00007fffed5876f8 in ?? () from /usr/lib64/digilent/adept/libdpcomm.so.2
#6  0x00007fffed5853d6 in ?? () from /usr/lib64/digilent/adept/libdpcomm.so.2
#7  0x00007fffed5848dc in ?? () from /usr/lib64/digilent/adept/libdpcomm.so.2
#8  0x00007ffff573b70a in start_thread (arg=0x7fff6267f700) at pthread_create.c:333
#9  0x00007ffff4bd082d in clone () at ../sysdeps/unix/sysv/linux/x86_64/clone.S:109
```
