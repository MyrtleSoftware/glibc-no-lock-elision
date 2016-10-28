# glibc without lock-elision

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
