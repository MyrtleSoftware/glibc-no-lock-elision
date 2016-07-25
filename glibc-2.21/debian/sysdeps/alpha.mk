libc_add-ons = $(add-ons)

libc = libc6.1

# build an ev67 optimized library
GLIBC_PASSES += alphaev67
DEB_ARCH_REGULAR_PACKAGES += libc6.1-alphaev67
alphaev67_add-ons = $(add-ons)
alphaev67_configure_target = alphaev67-linux-gnu
alphaev67_extra_cflags = -mcpu=ev67 -mtune=ev67 -O2
alphaev67_extra_config_options = $(extra_config_options)
alphaev67_slibdir = /lib/$(DEB_HOST_MULTIARCH)/ev67
