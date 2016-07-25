# Should each of these have per-package options?

$(patsubst %,binaryinst_%,$(DEB_ARCH_REGULAR_PACKAGES) $(DEB_INDEP_REGULAR_PACKAGES)) :: binaryinst_% : $(stamp)binaryinst_%

# Make sure the debug packages are built last, since other packages may add
# files to them.
debug-packages = $(filter %-dbg,$(DEB_ARCH_REGULAR_PACKAGES))
non-debug-packages = $(filter-out %-dbg,$(DEB_ARCH_REGULAR_PACKAGES))
$(patsubst %,$(stamp)binaryinst_%,$(debug-packages)):: $(patsubst %,$(stamp)binaryinst_%,$(non-debug-packages))

ifeq ($(filter stage1,$(DEB_BUILD_PROFILES)),)
DH_STRIP_DEBUG_PACKAGE=--dbg-package=$(libc)-dbg
endif

$(patsubst %,$(stamp)binaryinst_%,$(DEB_ARCH_REGULAR_PACKAGES) $(DEB_INDEP_REGULAR_PACKAGES)):: $(patsubst %,$(stamp)install_%,$(GLIBC_PASSES)) debhelper
	@echo Running debhelper for $(curpass)
	dh_testroot
	dh_installdirs -p$(curpass)
	dh_install -p$(curpass)
	dh_installman -p$(curpass)
	dh_installinfo -p$(curpass)
	dh_installdebconf -p$(curpass)
	if [ $(curpass) = glibc-doc ] ; then \
		dh_installchangelogs -p$(curpass) ; \
	else \
		dh_installchangelogs -p$(curpass) debian/changelog.upstream ; \
	fi
	dh_installinit -p$(curpass)
	dh_installdocs -p$(curpass) 
	dh_lintian -p $(curpass)
	dh_link -p$(curpass)
	dh_bugfiles -p$(curpass)

	if test "$(curpass)" = "libc-bin"; then			\
	  mv debian/$(curpass)/sbin/ldconfig			\
	    debian/$(curpass)/sbin/ldconfig.real;		\
	  install -m755 -o0 -g0 debian/local/sbin/ldconfig	\
	    debian/$(curpass)/sbin/ldconfig;			\
	fi

	# extra_debhelper_pkg_install is used for debhelper.mk only.
	# when you want to install extra packages, use extra_pkg_install.
	$(call xx,extra_debhelper_pkg_install)
	$(call xx,extra_pkg_install)

ifeq ($(filter nostrip,$(DEB_BUILD_OPTIONS)),)
	# libpthread must be stripped specially; GDB needs the
	# non-dynamic symbol table in order to load the thread
	# debugging library.  We keep a full copy of the symbol
	# table in libc6-dbg but basic thread debugging should
	# work even without that package installed.

	# strip *.o files as dh_strip does not (yet?) do it.
	if test "$(NOSTRIP_$(curpass))" != 1; then				\
	  if test "$(NODEBUG_$(curpass))" != 1; then				\
	    dh_strip -p$(curpass) -Xlibpthread $(DH_STRIP_DEBUG_PACKAGE);	\
	    (cd debian/$(curpass);						\
	      find . -name libpthread-\*.so -exec objcopy			\
	        --only-keep-debug '{}' ../$(libc)-dbg/usr/lib/debug/'{}'	\
	        ';' || true;							\
	      find . -name libpthread-\*.so -exec objcopy			\
	        --add-gnu-debuglink=../$(libc)-dbg/usr/lib/debug/'{}'		\
	        '{}' ';' || true);						\
	    find debian/$(curpass) -name libpthread-\*.so -exec			\
	      strip --strip-debug --remove-section=.comment			\
	      --remove-section=.note '{}' ';' || true;				\
	    									\
	    (cd debian/$(curpass);						\
	      find . -name \*crt\*.o -exec objcopy				\
	        --only-keep-debug '{}' ../$(libc)-dbg/usr/lib/debug/'{}'	\
	        ';' || true;							\
	      find . -name \*crt\*.o -exec objcopy				\
	        --add-gnu-debuglink=../$(libc)-dbg/usr/lib/debug/'{}'		\
	        '{}' ';' || true);						\
	    find debian/$(curpass) -name \*crt\*.o -exec			\
	      strip --strip-debug --remove-section=.comment			\
	      --remove-section=.note '{}' ';' || true;				\
	  else									\
	    dh_strip -p$(curpass) -Xlibpthread;					\
	  fi									\
	fi

	# ARM archs always use multiarch locations, don't let libc6-dbg conflict
	if test "$(curpass)" = "$(libc)-dbg"; then				\
	  if test "$(DEB_HOST_ARCH)" = "armel"; then				\
	    rm -rf debian/$(curpass)/usr/lib/debug/lib/arm-linux-gnueabihf;	\
	    rm -rf debian/$(curpass)/usr/lib/debug/usr/lib/arm-linux-gnueabihf;	\
	  fi;									\
	  if test "$(DEB_HOST_ARCH)" = "armhf"; then				\
	    rm -rf debian/$(curpass)/usr/lib/debug/lib/arm-linux-gnueabi;	\
	    rm -rf debian/$(curpass)/usr/lib/debug/usr/lib/arm-linux-gnueabi;	\
	  fi;									\
	fi
endif

	dh_compress -p$(curpass)
	dh_fixperms -p$(curpass) -Xpt_chown
	# Use this instead of -X to dh_fixperms so that we can use
	# an unescaped regular expression.  ld.so must be executable;
	# libc.so and NPTL's libpthread.so print useful version
	# information when executed.
	find debian/$(curpass) -type f \( -regex '.*/ld.*so' \
		-o -regex '.*/libpthread-.*so' \
		-o -regex '.*/libc-.*so' \) \
		-exec chmod a+x '{}' ';'
	dh_makeshlibs -X/usr/lib/debug -p$(curpass) -V "$(call xx,shlib_dep)"
	# Add relevant udeb: lines in shlibs files
	chmod a+x debian/shlibs-add-udebs
	./debian/shlibs-add-udebs $(curpass)

	dh_installdeb -p$(curpass)
	dh_shlibdeps -p$(curpass)
	dh_gencontrol -p$(curpass)
	if [ $(curpass) = nscd ] ; then \
		sed -i -e "s/\(Depends:.*libc[0-9.]\+\)-[a-z0-9]\+/\1/" debian/nscd/DEBIAN/control ; \
	fi
	dh_md5sums -p$(curpass)

	# We adjust the compression format depending on the package:
	# - libc* contains highly compressible data, but packages needed during
	#   debootstrap have to be compressed with gzip
	# - other packages use dpkg's default xz format
	case $(curpass) in \
	$(libc) | multiarch-support | libc-bin ) \
		dh_builddeb -p$(curpass) -- -Zgzip -z9 ;; \
	locales-all ) \
		dh_builddeb -p$(curpass) -- -Zxz -z7 ;; \
	*) \
		dh_builddeb -p$(curpass) ;; \
	esac

	touch $@

$(patsubst %,binaryinst_%,$(DEB_UDEB_PACKAGES)) :: binaryinst_% : $(stamp)binaryinst_%
$(patsubst %,$(stamp)binaryinst_%,$(DEB_UDEB_PACKAGES)): debhelper $(patsubst %,$(stamp)install_%,$(GLIBC_PASSES))
	@echo Running debhelper for $(curpass)
	dh_testroot
	dh_installdirs -p$(curpass)
	dh_install -p$(curpass)
	dh_strip -p$(curpass)
	
	# when you want to install extra packages, use extra_pkg_install.
	$(call xx,extra_pkg_install)

	dh_compress -p$(curpass)
	dh_fixperms -p$(curpass)
	find debian/$(curpass) -type f \( -regex '.*/ld.*so' \
		-o -regex '.*/libpthread-.*so' \
		-o -regex '.*/libc-.*so' \) \
		-exec chmod a+x '{}' ';'
	dh_installdeb -p$(curpass)
	# dh_shlibdeps -p$(curpass)
	dh_gencontrol -p$(curpass)
	dh_builddeb -p$(curpass)

	touch $@

debhelper: $(stamp)debhelper-common $(patsubst %,$(stamp)debhelper_%,$(GLIBC_PASSES))
$(stamp)debhelper-common: 
	for x in `find debian/debhelper.in -maxdepth 1 -type f`; do \
	  y=debian/`basename $$x`; \
	  cp $$x $$y; \
	  sed -e "s#BUILD-TREE#$(build-tree)#" -i $$y; \
	  sed -e "s#LIBC#$(libc)#" -i $$y; \
	  sed -e "s#EXIT_CHECK##" -i $$y; \
	  sed -e "s#DEB_HOST_ARCH#$(DEB_HOST_ARCH)#" -i $$y; \
	  sed -e "/NSS_CHECK/r debian/script.in/nsscheck.sh" -i $$y; \
	  sed -e "/NOHWCAP/r debian/script.in/nohwcap.sh" -i $$y; \
	  sed -e "s#CURRENT_VER#$(DEB_VERSION)#" -i $$y; \
	  case $$y in \
	    *.install) \
	      sed -e "s/^#.*//" -i $$y ; \
	      $(if $(filter $(pt_chown),no),sed -e "/pt_chown/d" -i $$y ;) \
	      ;; \
	  esac; \
	done

	# Substitute __PROVIDED_LOCALES__.
	perl -i -pe 'BEGIN {undef $$/; open(IN, "debian/tmp-libc/usr/share/i18n/SUPPORTED"); $$j=<IN>;} s/__PROVIDED_LOCALES__/$$j/g;' debian/locales.config debian/locales.postinst

	# Generate common substvars files.
	: > tmp.substvars
ifeq ($(filter stage2,$(DEB_BUILD_PROFILES)),)
	echo 'libgcc:Depends=libgcc1 [!hppa !m68k], libgcc2 [m68k], libgcc4 [hppa]' >> tmp.substvars
endif

	for pkg in $(DEB_ARCH_REGULAR_PACKAGES) $(DEB_INDEP_REGULAR_PACKAGES) $(DEB_UDEB_PACKAGES); do \
	  cp tmp.substvars debian/$$pkg.substvars; \
	done
	rm -f tmp.substvars

	touch $@

ifneq ($(filter stage1,$(DEB_BUILD_PROFILES)),)
$(patsubst %,debhelper_%,$(GLIBC_PASSES)) :: debhelper_% : $(stamp)debhelper_%
$(stamp)debhelper_%: $(stamp)debhelper-common $(stamp)install_%
	libdir=$(call xx,libdir) ; \
	slibdir=$(call xx,slibdir) ; \
	rtlddir=$(call xx,rtlddir) ; \
	curpass=$(curpass) ; \
	templates="libc-dev" ;\
	pass="" ; \
	suffix="" ;\
	for t in $$templates ; do \
	  for s in debian/$$t$$pass.* ; do \
	    t=`echo $$s | sed -e "s#libc\(.*\)$$pass#$(libc)\1$$suffix#"` ; \
	    if [ "$$s" != "$$t" ] ; then \
	      cp $$s $$t ; \
	    fi ; \
	    sed -e "s#TMPDIR#debian/tmp-$$curpass#g" -i $$t; \
	    sed -e "s#RTLDDIR#$$rtlddir#g" -i $$t; \
	    sed -e "s#SLIBDIR#$$slibdir#g" -i $$t; \
	    sed -e "s#LIBDIR#$$libdir#g" -i $$t; \
	  done ; \
	done

	sed -e "/$$libdir.*.a /d" -i debian/$(libc)-dev.install
else
$(patsubst %,debhelper_%,$(GLIBC_PASSES)) :: debhelper_% : $(stamp)debhelper_%
$(stamp)debhelper_%: $(stamp)debhelper-common $(stamp)install_%
	libdir=$(call xx,libdir) ; \
	slibdir=$(call xx,slibdir) ; \
	rtlddir=$(call xx,rtlddir) ; \
	curpass=$(curpass) ; \
	rtld_so=`LANG=C LC_ALL=C readelf -l debian/tmp-$$curpass/usr/bin/iconv | grep "interpreter" | sed -e 's/.*interpreter: \(.*\)]/\1/g'`; \
	case "$$curpass:$$slibdir" in \
	  libc:*) \
	    templates="libc libc-dev libc-pic libc-udeb libnss-dns-udeb libnss-files-udeb" \
	    pass="" \
	    suffix="" \
	    ;; \
	  *:/lib32 | *:/lib64 | *:/libo32 | *:/libx32 | *:/lib/arm-linux-gnueabi*) \
	    templates="libc libc-dev" \
	    pass="-alt" \
	    suffix="-$(curpass)" \
	    ;; \
	  *:*) \
	    templates="libc" \
	    pass="-otherbuild" \
	    suffix="-$(curpass)" \
	    ;; \
	esac ; \
	for t in $$templates ; do \
	  for s in debian/$$t$$pass.* ; do \
	    t=`echo $$s | sed -e "s#libc\(.*\)$$pass#$(libc)\1$$suffix#"` ; \
	    if [ "$$s" != "$$t" ] ; then \
	      cp $$s $$t ; \
	    fi ; \
	    sed -e "s#TMPDIR#debian/tmp-$$curpass#g" -i $$t; \
	    sed -e "s#RTLDDIR#$$rtlddir#g" -i $$t; \
	    sed -e "s#SLIBDIR#$$slibdir#g" -i $$t; \
	    sed -e "s#LIBDIR#$$libdir#g" -i $$t; \
	    sed -e "s#FLAVOR#$$curpass#g" -i $$t; \
	    sed -e "s#RTLD_SO#$$rtld_so#g" -i $$t ; \
	    sed -e "s#MULTIARCHDIR#$$DEB_HOST_MULTIARCH#g" -i $$t ; \
	  done ; \
	done
endif

	touch $@

clean::
	dh_clean 

	rm -f debian/*.install
	rm -f debian/*.install.*
	rm -f debian/*.manpages
	rm -f debian/*.links
	rm -f debian/*.postinst
	rm -f debian/*.preinst
	rm -f debian/*.postinst
	rm -f debian/*.prerm
	rm -f debian/*.postrm
	rm -f debian/*.info
	rm -f debian/*.init
	rm -f debian/*.config
	rm -f debian/*.templates
	rm -f debian/*.dirs
	rm -f debian/*.docs
	rm -f debian/*.doc-base
	rm -f debian/*.generated
	rm -f debian/*.lintian-overrides
	rm -f debian/*.NEWS
	rm -f debian/*.README.Debian
	rm -f debian/*.triggers

	rm -f $(stamp)binaryinst*
