# Because variables can be masked at anypoint by declaring
# PASS_VAR, we need to call all variables as $(call xx,VAR)
# This little bit of magic makes it possible:
xx=$(if $($(curpass)_$(1)),$($(curpass)_$(1)),$($(1)))

# We want to log output to a logfile but we also need to preserve the
# return code of the command being run.
# This little bit of magic makes it possible:
# $(call logme, [-a] <log file>, <cmd>)
define logme
(exec 3>&1; exit `( ( ( $(2) ) 2>&1 3>&-; echo $$? >&4) | tee $(1) >&3) 4>&1`)
endef

ifneq ($(filter stage1,$(DEB_BUILD_PROFILES)),)
    libc_extra_config_options = $(extra_config_options) --disable-sanity-checks \
                               --enable-hacker-mode
endif

ifdef WITH_SYSROOT
    libc_extra_config_options += --with-headers=$(WITH_SYSROOT)/$(includedir)
endif

$(patsubst %,mkbuilddir_%,$(GLIBC_PASSES)) :: mkbuilddir_% : $(stamp)mkbuilddir_%
$(stamp)mkbuilddir_%: $(stamp)patch $(KERNEL_HEADER_DIR)
	@echo Making builddir for $(curpass)
	test -d $(DEB_BUILDDIR) || mkdir -p $(DEB_BUILDDIR)
	touch $@

$(patsubst %,configure_%,$(GLIBC_PASSES)) :: configure_% : $(stamp)configure_%
$(stamp)configure_%: $(stamp)mkbuilddir_%
	@echo Configuring $(curpass)
	rm -f $(DEB_BUILDDIR)/configparms
	echo "CC = $(call xx,CC)"                 >> $(DEB_BUILDDIR)/configparms
	echo "CXX = $(call xx,CXX)"               >> $(DEB_BUILDDIR)/configparms
	echo "BUILD_CC = $(BUILD_CC)"             >> $(DEB_BUILDDIR)/configparms
	echo "BUILD_CXX = $(BUILD_CXX)"           >> $(DEB_BUILDDIR)/configparms
	echo "CFLAGS = $(HOST_CFLAGS)"            >> $(DEB_BUILDDIR)/configparms
	echo "ASFLAGS = $(HOST_CFLAGS)"           >> $(DEB_BUILDDIR)/configparms
	echo "BUILD_CFLAGS = $(BUILD_CFLAGS)"     >> $(DEB_BUILDDIR)/configparms
	echo "LDFLAGS = "                         >> $(DEB_BUILDDIR)/configparms
	echo "BASH := /bin/bash"                  >> $(DEB_BUILDDIR)/configparms
	echo "KSH := /bin/bash"                   >> $(DEB_BUILDDIR)/configparms
	echo "SHELL := /bin/bash"                 >> $(DEB_BUILDDIR)/configparms
	echo "LIBGD = no"                         >> $(DEB_BUILDDIR)/configparms
	echo "bindir = $(bindir)"                 >> $(DEB_BUILDDIR)/configparms
	echo "datadir = $(datadir)"               >> $(DEB_BUILDDIR)/configparms
	echo "localedir = $(localedir)"           >> $(DEB_BUILDDIR)/configparms
	echo "sysconfdir = $(sysconfdir)"         >> $(DEB_BUILDDIR)/configparms
	echo "libexecdir = $(libexecdir)"         >> $(DEB_BUILDDIR)/configparms
	echo "rootsbindir = $(rootsbindir)"       >> $(DEB_BUILDDIR)/configparms
	echo "includedir = $(call xx,includedir)" >> $(DEB_BUILDDIR)/configparms
	echo "docdir = $(docdir)"                 >> $(DEB_BUILDDIR)/configparms
	echo "mandir = $(mandir)"                 >> $(DEB_BUILDDIR)/configparms
	echo "sbindir = $(sbindir)"               >> $(DEB_BUILDDIR)/configparms
	echo "vardbdir = $(vardbdir)"             >> $(DEB_BUILDDIR)/configparms
	echo "libdir = $(call xx,libdir)"         >> $(DEB_BUILDDIR)/configparms
	echo "slibdir = $(call xx,slibdir)"       >> $(DEB_BUILDDIR)/configparms
	echo "rtlddir = $(call xx,rtlddir)"       >> $(DEB_BUILDDIR)/configparms

	# Define the installation directory for all calls to make. This avoid
	# broken glibc makefiles to spuriously trigger install rules trying to
	# overwrite system headers.
	echo "install_root = $(CURDIR)/debian/tmp-$(curpass)" >> $(DEB_BUILDDIR)/configparms

	# Prevent autoconf from running unexpectedly by setting it to false.
	# Also explicitly pass CC down - this is needed to get -m64 on
	# Sparc, et cetera.
	configure_build=$(call xx,configure_build); \
	if [ $(call xx,configure_target) = $$configure_build ]; then \
	  echo "Checking that we're running at least kernel version: $(call xx,MIN_KERNEL_SUPPORTED)"; \
	  if ! $(call kernel_check,$(call xx,MIN_KERNEL_SUPPORTED)); then \
	    configure_build=`echo $$configure_build | sed 's/^\([^-]*\)-\([^-]*\)$$/\1-dummy-\2/'`; \
	    echo "No.  Forcing cross-compile by setting build to $$configure_build."; \
	  fi; \
	fi; \
	$(call logme, -a $(log_build), echo -n "Build started: " ; date --rfc-2822 ; echo "---------------") ; \
	$(call logme, -a $(log_build), \
		cd $(DEB_BUILDDIR) && \
		CC="$(call xx,CC)" \
		CXX="$(call xx,CXX)" \
		AUTOCONF=false \
		MAKEINFO=: \
		$(CURDIR)/configure \
		--host=$(call xx,configure_target) \
		--build=$$configure_build --prefix=/usr --without-cvs \
		--enable-add-ons=$(standard-add-ons)"$(call xx,add-ons)" \
		--without-selinux \
		--enable-stackguard-randomization \
		--enable-obsolete-rpc \
		--with-pkgversion="Ubuntu GLIBC $(DEB_VERSION)" \
		--with-bugurl="https://bugs.launchpad.net/ubuntu/+source/glibc/+bugs" \
		$(if $(filter $(pt_chown),yes),--enable-pt_chown) \
		$(if $(filter $(threads),no),--disable-nscd) \
		$(call xx,with_headers) $(call xx,extra_config_options))
	touch $@

$(patsubst %,build_%,$(GLIBC_PASSES)) :: build_% : $(stamp)build_%
$(stamp)build_%: $(stamp)configure_%
	@echo Building $(curpass)

ifneq ($(filter stage1,$(DEB_BUILD_PROFILES)),)
	$(MAKE) cross-compiling=yes -C $(DEB_BUILDDIR) $(NJOBS) csu/subdir_lib
else
	$(call logme, -a $(log_build), $(MAKE) -C $(DEB_BUILDDIR) $(NJOBS))
	$(call logme, -a $(log_build), echo "---------------" ; echo -n "Build ended: " ; date --rfc-2822)
	if [ $(curpass) = libc ]; then \
	    I18NPATH=$(CURDIR)/localedata GCONV_PATH=$(DEB_BUILDDIR)/iconvdata localedef --quiet -c -f UTF-8 -i C $(CURDIR)/build-tree/C.UTF-8 ; \
	fi
	if [ $(curpass) = libc ]; then \
	  $(MAKE) -C $(DEB_BUILDDIR) $(NJOBS) \
	    objdir=$(DEB_BUILDDIR) install_root=$(CURDIR)/build-tree/locales-all \
	    localedata/install-locales; \
	  sync; \
	  rdfind -outputname /dev/null -makesymlinks true -removeidentinode false $(CURDIR)/build-tree/locales-all/usr/lib/locale ; \
	  symlinks -r -s -c $(CURDIR)/build-tree/locales-all/usr/lib/locale ; \
	fi
endif
	touch $@

$(patsubst %,check_%,$(GLIBC_PASSES)) :: check_% : $(stamp)check_%
$(stamp)check_%: $(stamp)build_%
	@set -e ; \
	if [ -n "$(findstring nocheck,$(DEB_BUILD_OPTIONS))" ]; then \
	  echo "Tests have been disabled via DEB_BUILD_OPTIONS." | tee $(log_results) ; \
	elif [ $(call xx,configure_build) != $(call xx,configure_target) ] && \
	     ! $(DEB_BUILDDIR)/elf/ld.so $(DEB_BUILDDIR)/libc.so >/dev/null 2>&1 ; then \
	  echo "Flavour cross-compiled, tests have been skipped." | tee $(log_results) ; \
	elif ! $(call kernel_check,$(call xx,MIN_KERNEL_SUPPORTED)); then \
	  echo "Kernel too old, tests have been skipped." | tee $(log_results) ; \
	elif [ $(call xx,RUN_TESTSUITE) != "yes" ]; then \
	  echo "Testsuite disabled for $(curpass), skipping tests."; \
	  echo "Tests have been disabled." > $(log_results) ; \
	else \
	  echo Testing $(curpass) / $(log_results); \
	  find $(DEB_BUILDDIR) -name '*.out' -exec rm {} ';' ; \
	  LD_PRELOAD="" LANG="" TIMEOUTFACTOR="50" $(MAKE) -C $(DEB_BUILDDIR) $(NJOBS) -k check 2>&1 | tee $(log_test); \
	  chmod +x debian/testsuite-checking/convertlog.sh ; \
	  debian/testsuite-checking/convertlog.sh $(log_test) | tee $(log_results) ; \
	  if test -f $(log_expected) ; then \
	    chmod +x debian/testsuite-checking/compare.sh ; \
	    debian/testsuite-checking/compare.sh $(log_expected) $(log_results) $(DEB_BUILDDIR) ; \
	  else \
	    echo "*************************** WARNING ***************************" ; \
	    echo "Please generate expected testsuite results for this arch ($(log_expected))!" ; \
	    echo "*************************** WARNING ***************************" ; \
	  fi ; \
	fi
	@n=$$(grep '^FAIL: ' $(log_test) | wc -l || true); \
	  echo "TEST SUMMARY $(log_test) ($$n matching lines)"; \
	  grep '^FAIL: ' $(log_test) || true; \
	  echo "END TEST SUMMARY $(log_test)"
	touch $@

$(patsubst %,install_%,$(GLIBC_PASSES)) :: install_% : $(stamp)install_%
$(stamp)install_%: $(stamp)check_%
	@echo Installing $(curpass)
	rm -rf $(CURDIR)/debian/tmp-$(curpass)
ifneq ($(filter stage1,$(DEB_BUILD_PROFILES)),)
	$(call logme, -a $(log_build), $(MAKE) -C $(DEB_BUILDDIR) $(NJOBS)	\
	    cross-compiling=yes install_root=$(CURDIR)/debian/tmp-$(curpass)	\
	    install-bootstrap-headers=yes install-headers )

	install -d $(CURDIR)/debian/tmp-$(curpass)/lib
	install -m 644 $(DEB_BUILDDIR)/csu/crt[1in].o $(CURDIR)/debian/tmp-$(curpass)/lib
	${CC} -nostdlib -nostartfiles -shared -x c /dev/null \
	        -o $(CURDIR)/debian/tmp-$(curpass)/lib/libc.so
else
	: # FIXME: why just needed for ARM multilib?
	case "$(curpass)" in \
	        armhf) \
			libgcc_dirs=/lib/arm-linux-gnueabihf; \
			if [ -n "$$WITH_BUILD_SYSROOT" ]; then \
			  libgcc_dirs="$$WITH_BUILD_SYSROOT/usr/arm-linux-gnueabi/lib/arm-linux-gnueabihf $$WITH_BUILD_SYSROOT/usr/lib/gcc-cross/arm-linux-gnueabi/4.7/hf"; \
			fi; \
			;; \
	        armel) \
			libgcc_dirs=/lib/arm-linux-gnueabi; \
			if [ -n "$$WITH_BUILD_SYSROOT" ]; then \
			  libgcc_dirs="$$WITH_BUILD_SYSROOT/usr/arm-linux-gnueabihf/lib/arm-linux-gnueabi $$WITH_BUILD_SYSROOT/usr/lib/gcc-cross/arm-linux-gnueabihf/4.7/sf"; \
			fi; \
			;; \
	esac; \
	if [ -n "$$libgcc_dirs" ]; then \
	  for d in $$libgcc_dirs; do \
	    if [ -f $$d/libgcc_s.so.1 ]; then \
	      cp -p $$d/libgcc_s.so.1 $(DEB_BUILDDIR)/; \
	      break; \
	    fi; \
	  done; \
	fi
	$(MAKE) -C $(DEB_BUILDDIR) \
	  install_root=$(CURDIR)/debian/tmp-$(curpass) install

	# Generate gconv-modules.cache
	case $(curpass)-$(call xx,slibdir) in libc-* | *-/lib32 | *-/lib64 | *-/libo32 | *-/libx32) \
	  /usr/sbin/iconvconfig --nostdlib --prefix=$(CURDIR)/debian/tmp-$(curpass) \
				-o $(CURDIR)/debian/tmp-$(curpass)/$(call xx,libdir)/gconv/gconv-modules.cache \
				$(call xx,libdir)/gconv \
	  ;; \
	esac

	# Generate the list of SUPPORTED locales
	if [ $(curpass) = libc ]; then \
	  $(MAKE) -f debian/generate-supported.mk IN=localedata/SUPPORTED \
	    OUT=debian/tmp-$(curpass)/usr/share/i18n/SUPPORTED; \
	fi

	# Create the multiarch directories, and the configuration file in /etc/ld.so.conf.d
	if [ $(curpass) = libc ]; then \
	  mkdir -p debian/tmp-$(curpass)/etc/ld.so.conf.d; \
	  conffile="debian/tmp-$(curpass)/etc/ld.so.conf.d/$(DEB_HOST_MULTIARCH).conf"; \
	  echo "# Multiarch support" > $$conffile; \
	  echo "$(call xx,slibdir)" >> $$conffile; \
	  echo "$(call xx,libdir)" >> $$conffile; \
	  if [ "$(DEB_HOST_GNU_TYPE)" != "$(DEB_HOST_MULTIARCH)" ]; then \
	    echo "/lib/$(DEB_HOST_GNU_TYPE)" >> $$conffile; \
	    echo "/usr/lib/$(DEB_HOST_GNU_TYPE)" >> $$conffile; \
	  fi; \
	  mkdir -p debian/tmp-$(curpass)/usr/include/$(DEB_HOST_MULTIARCH); \
	  mv debian/tmp-$(curpass)/usr/include/bits debian/tmp-$(curpass)/usr/include/$(DEB_HOST_MULTIARCH); \
	  mv debian/tmp-$(curpass)/usr/include/gnu debian/tmp-$(curpass)/usr/include/$(DEB_HOST_MULTIARCH); \
	  mv debian/tmp-$(curpass)/usr/include/sys debian/tmp-$(curpass)/usr/include/$(DEB_HOST_MULTIARCH); \
	  mv debian/tmp-$(curpass)/usr/include/fpu_control.h debian/tmp-$(curpass)/usr/include/$(DEB_HOST_MULTIARCH); \
	  mv debian/tmp-$(curpass)/usr/include/a.out.h debian/tmp-$(curpass)/usr/include/$(DEB_HOST_MULTIARCH); \
	  mv debian/tmp-$(curpass)/usr/include/ieee754.h debian/tmp-$(curpass)/usr/include/$(DEB_HOST_MULTIARCH); \
	fi

	# For our biarch libc, add an ld.so.conf.d configuration; this
	# is needed because multiarch libc Replaces: libc6-i386 for ld.so, and
	# the multiarch ld.so doesn't look at the (non-standard) /lib32, so we
	# need path compatibility when biarch and multiarch packages are both
	# installed.
	case $(call xx,slibdir) in /lib32 | /lib64 | /libo32 | /libx32) \
	  mkdir -p debian/tmp-$(curpass)/etc/ld.so.conf.d; \
	  conffile="debian/tmp-$(curpass)/etc/ld.so.conf.d/zz_$(curpass)-biarch-compat.conf"; \
	  echo "# Legacy biarch compatibility support" > $$conffile; \
	  echo "$(call xx,slibdir)" >> $$conffile; \
	  echo "$(call xx,libdir)" >> $$conffile; \
	  ;; \
	esac

	# handle the non-default multilib for arm targets
	case $(curpass) in arm*) \
	  mkdir -p debian/tmp-$(curpass)/etc/ld.so.conf.d; \
	  conffile="debian/tmp-$(curpass)/etc/ld.so.conf.d/zz_$(curpass)-biarch-compat.conf"; \
	  echo "# Multiarch support" > $$conffile; \
	  echo "$(call xx,slibdir)" >> $$conffile; \
	  echo "$(call xx,libdir)" >> $$conffile; \
	esac

	# ARM: add dynamic linker name for the non-default multilib in ldd
	if [ $(curpass) = libc ]; then \
	  case $(DEB_HOST_ARCH) in \
	    armel) \
	      sed -i '/RTLDLIST=/s,=\(.*\),="\1 /lib/ld-linux-armhf.so.3",' debian/tmp-$(curpass)/usr/bin/ldd;; \
	    armhf) \
	      sed -i '/RTLDLIST=/s,=\(.*\),="\1 /lib/ld-linux.so.3",' debian/tmp-$(curpass)/usr/bin/ldd;; \
	  esac; \
	fi

	# Create the ld.so symlink to the multiarch directory
	if [ $(curpass) = libc ]; then \
	  rtld_so="$$(LANG=C LC_ALL=C readelf -l debian/tmp-$(curpass)/usr/bin/iconv | grep 'interpreter' | sed -e 's/.*interpreter: \(.*\)]/\1/g')" ; \
	  rtld_so="$$(basename $$rtld_so)" ; \
	  link_name="debian/tmp-$(curpass)/lib/$$rtld_so" ; \
	  target="$(call xx,slibdir)/$$(readlink debian/tmp-$(curpass)/$(call xx,slibdir)/$$rtld_so)" ; \
	  ln -s $$target $$link_name ;  \
	fi
	
	$(call xx,extra_install)
endif
	touch $@

$(stamp)source: $(stamp)patch
	mkdir -p $(build-tree)
	tar -c -J -C .. \
		-f $(build-tree)/glibc-$(GLIBC_VERSION).tar.xz \
		$(GLIBC_SOURCES)
	mkdir -p debian/glibc-source/usr/src/glibc
	tar cf - --files-from debian/glibc-source.filelist \
	  | tar -x -C debian/glibc-source/usr/src/glibc -f -

	touch $@

.NOTPARALLEL: $(patsubst %,check_%,$(GLIBC_PASSES))
