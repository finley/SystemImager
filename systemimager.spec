#
# $Id$
#
%define name     systemimager
#
# "ver" below, is automatically set to the current version (as defined 
# by the VERSION file) when "make source_tarball" is executed.
# Therefore, it can be set to any three digit number here.
#
%define ver      0.0.0
# Set rel to 1 when is is a final release otherwise, set it to a 0.x number
# This is convenient when final release need to upgrade "beta" releases.
%define rel      0.19%{?dist}
%define packager Bernard Li <bernard@vanhpc.org>
#define prefix   /usr
%define _build_all 1
%define _boot_flavor standard
# Set this to 1 to build only the boot rpm
# it can also be done in the .rpmmacros file
#define _build_only_boot 1
%{?_build_only_boot:%{expand: %%define _build_all 0}}

%define _unpackaged_files_terminate_build 0

# prevent RPM from stripping files (eg. bittorrent binaries)
%define __spec_install_post /usr/lib/rpm/brp-compress
# prevent RPM files to be changed by prelink
%{?__prelink_undo_cmd:%undefine __prelink_undo_cmd}

%define is_suse %(test -f /etc/SuSE-release && echo 1 || echo 0)
%define is_ppc64 %([ "`uname -m`" = "ppc64" ] && echo 1 || echo 0)
%define is_ps3 %([ `grep PS3 /proc/cpuinfo >& /dev/null; echo $?` -eq 0 ] && echo 1 || echo 0) 

%if %is_ppc64
%define _build_arch ppc64
%endif

%if %is_ps3
%define _build_arch ppc64-ps3
%endif

%if %is_suse
%define python_xml python-xml
%else
%define python_xml PyXML
%endif

# Still use the correct lib even on fc-18+ where --target noarch sets %_libdir to /usr/lib even on x86_64 arch.
%define static_libcrypt_a /usr/lib/libcrypt.a
%if "%(arch)" == "x86_64"
%define static_libcrypt_a /usr/lib64/libcrypt.a
%endif

Summary: Software that automates Linux installs, software distribution, and production deployment.
Name: %name
Version: %ver
Release: %rel
License: GPL
Group: Applications/System
Source0: http://download.sourceforge.net/systemimager/%{name}-%{ver}.tar.bz2
BuildRoot: /tmp/%{name}-%{ver}-root
BuildArch: noarch
Packager: %packager
URL: http://wiki.systemimager.org/
Distribution: System Installation Suite
BuildRequires: docbook-utils, dos2unix, flex, libtool, readline-devel, /usr/bin/wget, openssl-devel, gcc, gcc-c++, ncurses-devel, bc, rsync >= 2.4.6
BuildRequires: libuuid-devel, device-mapper-devel, gperf, binutils-devel, pam-devel, quilt
BuildRequires: lzop, glib2-devel >= 2.22.0
Requires: rsync >= 2.4.6, syslinux >= 1.48, libappconfig-perl, dosfstools, /usr/bin/perl
#AutoReqProv: no

%description
SystemImager is software that automates Linux installs, software
distribution, and production deployment.  SystemImager makes it easy to
do installs, software distribution, content or data distribution,
configuration changes, and operating system updates to your network of
Linux machines. You can even update from one Linux release version to
another!  It can also be used to ensure safe production deployments.
By saving your current production image before updating to your new
production image, you have a highly reliable contingency mechanism.  If
the new production enviroment is found to be flawed, simply roll-back
to the last production image with a simple update command!  Some
typical environments include: Internet server farms, database server
farms, high performance clusters, computer labs, and corporate desktop
environments.

%if %{_build_all}

%package server
Summary: Software that automates Linux installs, software distribution, and production deployment.
Version: %ver
Release: %rel
License: GPL
Group: Applications/System
BuildRoot: /tmp/%{name}-%{ver}-root
BuildArch: noarch
Packager: %packager
URL: http://wiki.systemimager.org/
Distribution: System Installation Suite
Requires: rsync >= 2.4.6, systemimager-common = %{version}, perl-AppConfig, dosfstools, /sbin/chkconfig, perl, perl(XML::Simple) >= 2.14, python, mkisofs
#AutoReqProv: no

%description server
SystemImager is software that automates Linux installs, software 
distribution, and production deployment.  SystemImager makes it easy to
do installs, software distribution, content or data distribution, 
configuration changes, and operating system updates to your network of 
Linux machines. You can even update from one Linux release version to 
another!  It can also be used to ensure safe production deployments.  
By saving your current production image before updating to your new 
production image, you have a highly reliable contingency mechanism.  If
the new production enviroment is found to be flawed, simply roll-back 
to the last production image with a simple update command!  Some 
typical environments include: Internet server farms, database server 
farms, high performance clusters, computer labs, and corporate desktop
environments.

The server package contains those files needed to run a SystemImager
server.

%package flamethrower
Summary: Software that automates Linux installs, software distribution, and production deployment.
Version: %ver
Release: %rel
License: GPL
Group: Applications/System
BuildRoot: /tmp/%{name}-%{ver}-root
BuildArch: noarch
Packager: %packager
URL: http://wiki.systemimager.org/
Distribution: System Installation Suite
Requires: systemimager-server = %{version}, /sbin/chkconfig, perl, flamethrower >= 0.1.6
#AutoReqProv: no

%description flamethrower
SystemImager is software that automates Linux installs, software 
distribution, and production deployment.  SystemImager makes it easy to
do installs, software distribution, content or data distribution, 
configuration changes, and operating system updates to your network of 
Linux machines. You can even update from one Linux release version to 
another!  It can also be used to ensure safe production deployments.  
By saving your current production image before updating to your new 
production image, you have a highly reliable contingency mechanism.  If
the new production enviroment is found to be flawed, simply roll-back 
to the last production image with a simple update command!  Some 
typical environments include: Internet server farms, database server 
farms, high performance clusters, computer labs, and corporate desktop
environments.

The flamethrower package allows you to use the flamethrower utility to perform
installations over multicast.

%package common
Summary: Software that automates Linux installs, software distribution, and production deployment.
Version: %ver
Release: %rel
License: GPL
Group: Applications/System
BuildRoot: /tmp/%{name}-%{ver}-root
BuildArch: noarch
Packager: %packager
URL: http://wiki.systemimager.org/
Distribution: System Installation Suite
Requires: perl, systemconfigurator >= 2.2.11
#AutoReqProv: no

%description common
SystemImager is software that automates Linux installs, software 
distribution, and production deployment.  SystemImager makes it easy to
do installs, software distribution, content or data distribution, 
configuration changes, and operating system updates to your network of 
Linux machines. You can even update from one Linux release version to 
another!  It can also be used to ensure safe production deployments.  
By saving your current production image before updating to your new 
production image, you have a highly reliable contingency mechanism.  If
the new production enviroment is found to be flawed, simply roll-back 
to the last production image with a simple update command!  Some 
typical environments include: Internet server farms, database server 
farms, high performance clusters, computer labs, and corporate desktop
environments.

The common package contains files common to SystemImager clients 
and servers.

%package client
Summary: Software that automates Linux installs, software distribution, and production deployment.
Version: %ver
Release: %rel
License: GPL
Group: Applications/System
BuildRoot: /tmp/%{name}-%{ver}-root
BuildArch: noarch
Packager: %packager
URL: http://wiki.systemimager.org/
Distribution: System Installation Suite
Requires: systemimager-common = %{version}, systemconfigurator >= 2.2.11, perl-AppConfig, rsync >= 2.4.6, perl
#AutoReqProv: no

%description client
SystemImager is software that automates Linux installs, software
distribution, and production deployment.  SystemImager makes it easy to
do installs, software distribution, content or data distribution,
configuration changes, and operating system updates to your network of
Linux machines. You can even update from one Linux release version to
another!  It can also be used to ensure safe production deployments.
By saving your current production image before updating to your new
production image, you have a highly reliable contingency mechanism.  If
the new production enviroment is found to be flawed, simply roll-back
to the last production image with a simple update command!  Some
typical environments include: Internet server farms, database server
farms, high performance clusters, computer labs, and corporate desktop
environments.

The client package contains the files needed on a machine for it to
be imaged by a SystemImager server.

%endif

%package %{_build_arch}boot-%{_boot_flavor}
Summary: Software that automates Linux installs, software distribution, and production deployment.
Version: %ver
Release: %rel
License: GPL
Group: Applications/System
BuildRoot: /tmp/%{name}-%{ver}-root
BuildArch: noarch
Packager: %packager
URL: http://wiki.systemimager.org/
Distribution: System Installation Suite
Obsoletes: systemimager-%{_build_arch}boot
BuildRequires: python, python-devel, gettext
%if %is_ps3
BuildRequires: dtc
%endif
Requires: systemimager-server >= %{version}
Requires: %{name}-initrd_template = %{version}
Provides: %{name}-boot-%{_boot_flavor} = %{version}
AutoReqProv: no

%description %{_build_arch}boot-%{_boot_flavor}
SystemImager is software that automates Linux installs, software 
distribution, and production deployment.  SystemImager makes it easy to
do installs, software distribution, content or data distribution, 
configuration changes, and operating system updates to your network of 
Linux machines. You can even update from one Linux release version to 
another!  It can also be used to ensure safe production deployments.  
By saving your current production image before updating to your new 
production image, you have a highly reliable contingency mechanism.  If
the new production enviroment is found to be flawed, simply roll-back 
to the last production image with a simple update command!  Some 
typical environments include: Internet server farms, database server 
farms, high performance clusters, computer labs, and corporate desktop
environments.

The %{_build_arch}boot package provides specific kernel, ramdisk, and fs utilities
to boot and install %{_build_arch} Linux machines during the SystemImager autoinstall
process.

%package %{_build_arch}initrd_template
Summary: Software that automates Linux installs, software distribution, and production deployment.
Version: %ver
Release: %rel
License: GPL
Group: Applications/System
BuildRoot: /tmp/%{name}-%{ver}-root
BuildArch: noarch
Packager: %packager
URL: http://wiki.systemimager.org/
Distribution: System Installation Suite
BuildRequires: python, python-devel, %{python_xml}, %{static_libcrypt_a}
Requires: %{name}-%{_build_arch}boot-%{_boot_flavor} = %{version}
Provides: %{name}-initrd_template = %{version}
AutoReqProv: no

%description %{_build_arch}initrd_template
SystemImager is software that automates Linux installs, software
distribution, and production deployment.  SystemImager makes it easy to
do installs, software distribution, content or data distribution,
configuration changes, and operating system updates to your network of
Linux machines. You can even update from one Linux release version to
another!  It can also be used to ensure safe production deployments.
By saving your current production image before updating to your new
production image, you have a highly reliable contingency mechanism.  If
the new production enviroment is found to be flawed, simply roll-back
to the last production image with a simple update command!  Some
typical environments include: Internet server farms, database server
farms, high performance clusters, computer labs, and corporate desktop
environments.

The %{_build_arch}initrd_template package provides initrd template files for creating custom
ramdisk that works with a specific kernel by using UYOK (Use Your Own Kernel).  The custom
ramdisk can then be used to boot and install %{_build_arch} Linux machines during the
SystemImager autoinstall process.

%package bittorrent
Summary: Software that automates Linux installs, software distribution, and production deployment.
Version: %ver
Release: %rel
License: GPL
Group: Applications/System
BuildRoot: /tmp/%{name}-%{ver}-root
BuildArch: noarch
Packager: %packager
URL: http://wiki.systemimager.org/
Distribution: System Installation Suite
Requires: systemimager-server = %{version}, /sbin/chkconfig, perl, perl(Getopt::Long)
#AutoReqProv: no

%description bittorrent
SystemImager is software that automates Linux installs, software
distribution, and production deployment.  SystemImager makes it easy to
do installs, software distribution, content or data distribution,
configuration changes, and operating system updates to your network of
Linux machines. You can even update from one Linux release version to
another!  It can also be used to ensure safe production deployments.
By saving your current production image before updating to your new
production image, you have a highly reliable contingency mechanism.  If
the new production enviroment is found to be flawed, simply roll-back
to the last production image with a simple update command!  Some
typical environments include: Internet server farms, database server
farms, high performance clusters, computer labs, and corporate desktop
environments.

The bittorrent package allows you to use the BitTorrent protocol to perform
installations.

%changelog
* Wed Jul 18 2014 Olivier Lahaye <olivier.lahaye@cea.fr> 4.3.0-0.19
- Reverted si_netbootmond wrong fix and fixed the man instead.

* Tue Jul 17 2014 Olivier Lahaye <olivier.lahaye@cea.fr> 4.3.0-0.18
- Fix si_netbootmond that refused to do its job.
- SystemConfigurator disabled (currently broken)

* Wed Jul 02 2014 Olivier Lahaye <olivier.lahaye@cea.fr> 4.3.0-0.17
- Fix /etc/dhclient.conf options descriptions in initrd.img.
  option option-140 code 140 = ip-address;          # Image server.
  option option-141 code 141 = unsigned integer 16; # Log server port.
  option option-142 code 142 = string;              # SSH download URL.
  option option-143 code 143 = unsigned integer 16; # Flamethrower port base.

* Thu Jan 23 2014 Olivier Lahaye <olivier.lahaye@cea.fr> 4.3.0-0.16
- New beta version. (fix si_monitortk thread warning)

* Sat Dec 14 2013 Olivier Lahaye <olivier.lahaye@cea.fr> 4.3.0-0.15
- New beta version.

* Fri Dec 13 2013 Olivier Lahaye <olivier.lahaye@cea.fr> 4.3.0-0.14
- New beta version.

* Thu Jun 27 2013 Olivier Lahaye <olivier.lahaye@cea.fr> 4.3.0-0.13
- New beta version. (Update release to match debian side)

* Thu Jun 27 2013 Olivier Lahaye <olivier.lahaye@cea.fr> 4.3.0-0.12
- New beta version. (Fix option parsing + update manuals)

* Wed Jun 12 2013 Olivier Lahaye <olivier.lahaye@cea.fr> 4.3.0-0.11
- New beta version. (Add options to include system installed firmwares
  into intird.img)

* Fri Apr 19 2013 Olivier Lahaye <olivier.lahaye@cea.fr> 4.3.0-0.10
- Fix libcrypt dependancies even on fc-18 when --target noarch is used.
  Replace BuildArchitecture: (obsolete syntax) with BuildArch:

* Mon Apr 08 2013 Olivier Lahaye <olivier.lahaye@cea.fr> 4.3.0-0.9
- New beta version: updated gzip to 1.5 and tar to 1.26 (gets undefined)

* Mon Apr 08 2013 Olivier Lahaye <olivier.lahaye@cea.fr> 4.3.0-0.8
- New beta version:
  - Fix for parted version detection
  - Fix for "Unable to auto-detect kernel file (rhel-6.4)

* Thu Mar 14 2013 Olivier Lahaye <olivier.lahaye@cea.fr> 4.3.0-0.7
- New beta version which revet dhclient to v3.1.3 as all V4 are affected by
  bug ISC#32935 which prevent unitialized interface to be set up.

* Thu Mar 14 2013 Olivier Lahaye <olivier.lahaye@cea.fr> 4.3.0-0.6
- New beta version that includes new kernel, latest udev and fixed build system

* Thu Mar  7 2013 Olivier Lahaye <olivier.lahaye@cea.fr> 4.3.0-0.5
- Added glib2-devel >= 2.22.0 BuildRequires (needed by udev-182) 
- removed --libdir=/lib in util-linux (so links are wrongly generated)
- removed .la in util-linux and udev install as they are not usable at
  this location
- Fixed udev build by using our own libblkid and libkmod
- Fixed initrd.rul (more initrd cleanup (*.a *.la ...)
  Fixed so links in initrd (nss libs and a few other libs

* Tue Feb 26 2013 Olivier Lahaye <olivier.lahaye@cea.fr> 4.3.0-0.4
- Added lzop BuildRequires (needed in kernel build process).

* Mon Jan 14 2013 Olivier Lahaye <olivier.lahaye@cea.fr> 4.3.0-0.3
- Added binutils-devel required to build mdadm (ansidecl.h)
- Added pam-devel required to build util-linux

* Mon Jan  7 2013 Olivier Lahaye <olivier.lahaye@cea.fr> 4.3.0-0.2
- Commited all generic patches into Git.
- Use specific rpm/ directory to store patch used only when building on
  rpm distro. The rpm can be built with "rpm -tb" command.

* Tue Dec 18 2012 Olivier Lahaye <olivier.lahaye@cea.fr> 4.3.0-0.1
- Removed all spec patches
- New devel branch 4.3.0
- Add optional %dist tag to the release

* Fri Nov 23 2012 Olivier Lahaye <olivier.lahaye@cea.fr> 4.2.0-0.91svn4568
- Enabled ext4 module in kernel
- Updated systemimager_server_pm.patch (use $(()) for arithmetics)

* Fri Nov 23 2012 Olivier Lahaye <olivier.lahaye@cea.fr> 4.2.0-0.9svn4568
- Fix for new parted in Server.pm (avoid grepping "Disk Flags").

* Thu Nov  8 2012 Olivier Lahaye <olivier.lahaye@cea.fr> 4.2.0-0.8svn4568
- Full rewrite of 95all.monitord_rebooted to have correct rebooted status
  on RHEL like distros. Try to comply with SysVInitScripts and systemd.

* Wed Nov  7 2012 Olivier Lahaye <olivier.lahaye@cea.fr> 4.2.0-0.7svn4568
- Upgrade parted to v3.1

* Tue Jul 24 2012 Olivier Lahaye <olivier.lahaye@cea.fr> 4.2.0-0.6svn4568
- Fixed mklib.bef so newer already installed libs aren't overwriten

* Wed Jul  4 2012 Olivier Lahaye <olivier.lahaye@cea.fr> 4.2.0-0.5svn4568
- Fixed initrd_source/make.d/{udev,coreutils,util-linux}.rul
  using make install-exec so libtool is used to install binaries
  and thus avoiding copying the libtool wrapper instead of the
  real binaries.
- Added "BuildRequires: gperf" for udev build

* Tue Apr 24 2012 Olivier Lahaye <olivier.lahaye@cea.fr>
- New svn snapshot 4568
- device-mapper-devel is needed
- quilt is needed for building sysvinit-2.87dsf
- Patch to sysvinit-2.87dsf to avoid debian specific stuffs
- Patch for new kernel config

* Mon Feb 13 2012 Olivier Lahaye <olivier.lahaye@cea.fr>
- New svn snapshot 4555_bli

* Thu Apr 07 2011 Bernard Li <bernard@vanhpc.org>
- Added bc to BuildRequires as Makefile needs it
- Added rsync >= 2.4.6 to BuildRequires

* Thu Mar 24 2011 Bernard Li <bernard@vanhpc.org>
- libuuid.so is provided by libuuid-devel in RHEL6 instead of e2fsprogs-devel
- libcrypt.a is provided by glibc-static in RHEL6 instead of glibc-devel
- gettext is needed for building xfsprogs included in boel_binaries
- Use $RPM_BUILD_ROOT for DESTDIR
- Cleanup some commented commands

* Tue Nov 10 2009 Bernard Li <bernard@vanhpc.org>
- Added ncurses-devel to BuildRequires

* Sun Dec 02 2007 Bernard Li <bernard@vanhpc.org>
- Added dtc to BuildRequires for building ps3-ppc64boot-standard package
  (new PS3 kernel requires it)

* Wed Nov 21 2007 Andrea Righi <a.righi@cineca.it>
- added systemconfigurator >= 2.2.11 dependency

* Thu Oct 04 2007 Andrea Righi <a.righi@cineca.it>
- Removed systemimager-client dependency from systemimager-initrd-template

* Sun Sep 02 2007 Bernard Li <bernard@vanhpc.org>
- Make function is_ps3 work with different formats of /proc/cpuinfo on the PS3

* Sat Aug 04 2007 Andrea Righi <a.righi@cineca.it>
- Removed unmaintained package imagemanip

* Fri Aug 03 2007 Andrea Righi <a.righi@cineca.it>
- Include missing manpages in the server package

* Wed Aug 01 2007 Bernard Li <bernard@vanhpc.org>
- Add support for ppc64-ps3/kboot
- Include dir /etc/systemimager/kboot.cfg

* Tue May 22 2007 Bernard Li <bernard@vanhpc.org>
- Fixed typo: systemimager-server-rsyncd -> systemimager-server-monitord for upgrade service restart

* Tue Apr 17 2007 Andrea Righi <a.righi@cineca.it>
- added systemconfigurator >= 2.2.9 dependency

* Tue Apr 03 2007 Andrea Righi <a.righi@cineca.it>
- added pattern exclusions for si_getimage in /etc/systemimager/getimage.exclude

* Thu Mar 08 2007 Andrea Righi <a.righi@cineca.it>
- Added si_pushoverrides command.

* Wed Feb 28 2007 Bernard Li <bernard@vanhpc.org>
- Change perl(XML::Simple) dependency to >= 2.14 since starting with that version
  it correctly has the dependency for perl(XML::Parser) (Noted by Andrew M. Lyons)

* Wed Feb 21 2007 Andrea Righi <a.righi@cineca.it>
- Removed deprecated file README.ssh_support

* Sun Jan 28 2007 Bernard Li <bernard@vanhpc.org>
- Added missing directories to filelist for systemimager-server

* Sun Jan 28 2007 Andrea Righi <a.righi@cineca.it>
- Differentiate between upgrade and uninstall operations in all the
  %preun sections.

* Sat Jan 27 2007 Andrea Righi <a.righi@cineca.it>
- Added a warning about what will remain untouched during the update of
  the server package
- Re-added "Obsoletes" attribute for the boot-standard package.

* Wed Jan 17 2007 Andrea Righi <a.righi@cineca.it>
- Removed "Obsoletes" attribute from boot and initrd_template.

* Sun Nov 19 2006 Andrea Righi <a.righi@cineca.it>
- Moved the BitTorrent dependency for systemimager-bittorrent in %pre
  section. In this way we have a package compatible both for SuSE and RH
  distributions.

* Sun Nov 12 2006 Andrea Righi <a.righi@cineca.it>
- Removed python-xml dependency from systemimager-server package (this
  package is needed only by BitTorrent).
- Added python-xml and BitTorrent dependencies for initrd_template
  package.
- Removed python-xml dependency from systemimager-bittorrent (this
  package is a dependency only for BitTorrent, that is already present
  in the list of the required packages).

* Wed Aug 02 2006 Andrea Righi <a.righi@cineca.it>
- Updated URLs to http://wiki.systemimager.org 

* Wed Aug 02 2006 Bernard Li <bli@bcgsc.ca>
- Officially taking over as packager of SystemImager RPMs

* Wed Jul 26 2006 Bernard Li <bli@bcgsc.ca>
- Prevent RPM from stripping binaries (eg. bittorrent)

* Tue Jul 11 2006 Bernard Li <bli@bcgsc.ca>
- Added code to cleanup buildroot etc.

* Sun Jul 02 2006 Bernard Li <bli@bcgsc.ca>
- After a init service is added, turn it off, because we don't want the
  service to be turned on after installation (the user should do that)

* Sat Jun 17 2006 Bernard Li <bli@bcgsc.ca>
- Added %doc README.SystemImager_DHCP_options, README.ssh_support and
  TODO to systemimager-server package

* Mon Jun 11 2006 Bernard Li <bli@bcgsc.ca>
- New package: systemimager-imagemanip

* Fri Jun 09 2006 Bernard Li <bli@bcgsc.ca>
- Added file /etc/systemimager/UYOK.modules_to_include

* Fri Apr 21 2006 Bernard Li <bli@bcgsc.ca>
- New package: systemimager-bittorrent
- Requires bittorrent RPM

* Sun Apr 16 2006 Bernard Li <bli@bcgsc.ca>
- Added %post and %preun sections for flamethrower

* Sat Apr 15 2006 Bernard Li <bli@bcgsc.ca>
- Added bits to add/remove init scripts for systemimager-server-{netbootmond
  monitord,bittorrent}
- Added /usr/share/systemimager/icons/* to %files

* Sun Mar 26 2006 Bernard Li <bli@bcgsc.ca>
- Added new function %is_suse to test if we're building on SuSE Linux
- Changed python-xml requires such that it is only required on SuSE Linux, otherwise,
  require PyXML (Red Hat, Fedora, Mandriva)

* Thu Dec 08 2005 Bernard Li <bli@bcgsc.ca>
- New package - %{_build_arch}initrd_template

* Thu Dec 01 2005 Bernard Li <bli@bcgsc.ca>
- Added general description text for systemimager package as this is used by SRPM

* Thu Nov 17 2005 Bernard Li <bli@bcgsc.ca>
- Added ./configure SI_BUILD_DOCS=1 to ensure building of docs
- Added docbook-utils to BuildRequires

* Mon Aug 08 2005 Bernard Li <bli@bcgsc.ca>
- Changed requirement of perl-XML-Simple to perl(XML::Simple)
- Changed requirement of perl-TermReadKey to perl(Term::ReadKey)

* Mon Jul 25 2005 Bernard Li <bli@bcgsc.ca>
- Added directory /var/lock/systemimager

* Sat Jul 23 2005 Bernard Li <bli@bcgsc.ca>
- Updated Copyright -> License (deprecated)
- Added requirement for perl-TermReadKey
- Updated requirement for perl-XML-Simple to >= 2.08

* Sun Dec 19 2004 Josh Aas <josha@sgi.com>
- Here is another patch for RPM building. With this patch, you should be
  able to make an srpm, install it, build from the spec file ("rpmbuild
  -ba systemimager.spec") and get a full set of RPMs. I assume you want
  BootMedia stuff in the server RPM.

* Wed Jun 02 2004 sis devel <sisuite-devel@lists.sourceforge.net> 3.3.1-1
- include pre-install and post-install directories

* Fri Mar 12 2004 sis devel <sisuite-devel@lists.sourceforge.net> 3.2.0-3
- html documentation returned to systemimager-server package

* Wed Mar 10 2004 sis devel <sisuite-devel@lists.sourceforge.net> 3.2.0-2
- remove more files created by multiple calls to install phases

* Wed Mar 03 2004 sis devel <sisuite-devel@lists.sourceforge.net> 3.2.0-1

* Wed Nov 12 2003 sis devel <sisuite-devel@lists.sourceforge.net> 3.1.6-1
- new upstream release
- add version dependency for systemimager-flamethrower package

* Tue Aug 19 2003 sis devel <sisuite-devel@lists.sourceforge.net> 3.1.5-1
- new upstream release

* Tue Jul 14 2003 sis devel <sisuite-devel@lists.sourceforge.net> 3.1.4-1
- new upstream release

* Tue Jul 09 2003 sis devel <sisuite-devel@lists.sourceforge.net> 3.1.3-1
- new upstream release

* Tue Jul 08 2003 sis devel <sisuite-devel@lists.sourceforge.net> 3.1.2-5
- add missing Client.pm, pushupdate manpage & overrides readme

* Sun Jul 06 2003 sis devel <sisuite-devel@lists.sourceforge.net> 3.1.2-4
- add missing conf file & state dir to systemimager-server-flamethrower

* Sat Jul 05 2003 sis devel <sisuite-devel@lists.sourceforge.net> 3.1.2-3
- install missing autoinstallscript.template

* Tue Jul 01 2003 sis devel <sisuite-devel@lists.sourceforge.net> 3.1.2-2
- make systemimager-flamethrower depend on flamethrower
- patch the x86 config to support sk98lin, so it does not go interactive

* Tue Jul 01 2003 sis devel <sisuite-devel@lists.sourceforge.net> 3.1.2-1
- new upstream development release

* Tue Apr 02 2003 sis devel <sisuite-devel@lists.sourceforge.net> 3.0.1-4
- fix mkautoinstallcd on ia64 - 751740

* Tue Apr 02 2003 sis devel <sisuite-devel@lists.sourceforge.net> 3.0.1-3
- added a patch from bef that no longer sorts module names - 755463

* Tue Apr 02 2003 sis devel <sisuite-devel@lists.sourceforge.net> 3.0.1-2
- remove eepro100 (but keep e100) so boel will fit on a floppy again

* Sun Mar 30 2003 sis devel <sisuite-devel@lists.sourceforge.net> 3.0.1-1
- new upstream bug-fix release

* Sun Jan 08 2003 sis devel <sisuite-devel@lists.sourceforge.net> 3.0.0-2
- various ia64 fixes
- stop attempting to build ps manual

* Sun Dec 08 2002 sis devel <sisuite-devel@lists.sourceforge.net> 3.0.0-1
- new upstream release

* Sun Nov 18 2002 dann frazier <dannf@dannf.org> 2.9.5-1
- new upstream release

* Sun Oct 27 2002 dann frazier <dannf@dannf.org> 2.9.4-1
- new upstream release

* Thu Oct 13 2002 dann frazier <dannf@dannf.org> 2.9.3-2
- added code to migrate users to rsync stubs

* Thu Oct 02 2002 dann frazier <dannf@dannf.org> 2.9.3-1
- new upstream release

* Thu Sep 19 2002 Sean Dague <sean@dague.net> 2.9.1-1
- Added \%if \%{_build_all} stanzas to make building easier.

* Tue Feb  5 2002 Sean Dague <sean@dague.net> 2.1.1-1
- Added section 5 manpages
- removed syslinux requirement, as it isn't need for ia64

* Mon Jan 14 2002 Sean Dague <sean@dague.net> 2.1.0-1
- Set Macro to build $ARCHboot packages propperly
- Targetted rpms for noarch target (dannf@dannf.org)
- Synced up file listing

* Wed Dec  5 2001 Sean Dague <sean@dague.net> 2.0.1-1
- Update SystemImager version
- Changed prefix to /usr
- Made seperate i386boot package

* Mon Nov  5 2001 Sean Dague <sean@dague.net> 2.0.0-4
- Added build section for true SRPM ability

* Mon Oct  28 2001 Sean Dague <sean@dague.net> 2.0.0-3
- Added common package

* Sat Oct 20 2001  Sean Dague <sean@dague.net> 2.0.0-2
- Recombined client and server into one spec file

* Thu Oct 18 2001 Sean Dague <sean@dague.net> 2.0.0-1
- Initial build
- Based on work by Ken Segura <ksegura@5o7.org>

%prep

# Prepare source tree
%setup -q

# Add patches so it can build on non-debian systems.
%__cp rpm/*.patch initrd_source/patches/

# Download external sources
%{__make} %{?_smp_mflags} get_source

%build
cd $RPM_BUILD_DIR/%{name}-%{version}/

# Make sure we can fin system utils like mkfs.cramfs (when building as non-root)
export PATH=/sbin:/usr/sbin:$PATH

# Build against installed libs, not our system lib which may not be the same version.
export LD_FLAGS=-L$RPM_BUILD_DIR/%{name}-%{version}/initrd_source/build_dir/lib

# Make sure we build the docs
./configure SI_BUILD_DOCS=1

# Only build everything if on x86, this helps with PPC build issues
%if %{_build_all}
#%{__make} %{?_smp_mflags} all
%{__make} -j1 all

%else
%{__make} binaries

%endif

%install
cd $RPM_BUILD_DIR/%{name}-%{version}/

%if %{_build_all}

make install_server_all DESTDIR=$RPM_BUILD_ROOT PREFIX=%_prefix
make install_client_all DESTDIR=$RPM_BUILD_ROOT PREFIX=%_prefix
(cd doc/manual_source;%{__make} html)

%else

%{__make} install_binaries DESTDIR=$RPM_BUILD_ROOT PREFIX=%_prefix

%endif

# Some things that get duplicated because there are multiple calls to
# the make install_* phases.
find $RPM_BUILD_ROOT -name \*~ -exec rm -f '{}' \;

%clean
#__rm -rf $RPM_BUILD_DIR/%{name}-%{version}/
%__rm -rf $RPM_BUILD_ROOT

%if %{_build_all}

%pre server
# /etc/systemimager/rsyncd.conf is now generated from stubs stored
# in /etc/systemimager/rsync_stubs.  if upgrading from an early
# version, we need to create stub files for all image entries
if [ -f %{_sysconfdir}/systemimager/rsyncd.conf -a \
    ! -d %{_sysconfdir}/systemimager/rsync_stubs ]; then
    echo "You appear to be upgrading from a pre-rsync stubs release."
    echo "%{_sysconfdir}/systemimager/rsyncd.conf is now auto-generated from stub"
    echo "files stored in %{_sysconfdir}/systemimager/rsync_stubs."
    echo "Backing up %{_sysconfdir}/systemimager/rsyncd.conf to:"
    echo -n "  %{_sysconfdir}/systemimager/rsyncd.conf-before-rsync-stubs... "
    mv %{_sysconfdir}/systemimager/rsyncd.conf \
      %{_sysconfdir}/systemimager/rsyncd.conf-before-rsync-stubs

    ## leave an extra copy around so the postinst knows to make stub files from it
    cp %{_sysconfdir}/systemimager/rsyncd.conf-before-rsync-stubs \
      %{_sysconfdir}/systemimager/rsyncd.conf-before-rsync-stubs.tmp
    echo "done."
fi    


%post server
# First we check for rsync service under xinetd and get rid of it
# also note the use of DURING_INSTALL, which is used to
# support using this package in Image building without affecting
# processes running on the parrent
if [[ -a %{_sysconfdir}/xinetd.d/rsync ]]; then
    mv %{_sysconfdir}/xinetd.d/rsync %{_sysconfdir}/xinetd.d/rsync.presis~
    `pidof xinetd > /dev/null`
    if [[ $? == 0 ]]; then
        if [ -z $DURING_INSTALL ]; then
            %{_sysconfdir}/init.d/xinetd restart
        fi
    fi
fi

# If we are upgrading from a pre-rsync-stubs release, the preinst script
# will have left behind a copy of the old rsyncd.conf file.  we need to parse
# it and make stubs files for each image.

# This assumes that this file has been managed by systemimager, and
# that there is nothing besides images entries that need to be carried
# forward.

in_image_section=0
current_image=""
if [ -f %{_sysconfdir}/systemimager/rsyncd.conf-before-rsync-stubs.tmp ]; then
    echo "Migrating image entries from existing %{_sysconfdir}/systemimager/rsyncd.conf to"
    echo "individual files in the %{_sysconfdir}/systemimager/rsync_stubs/ directory..."
    while read line; do
	## Ignore all lines until we get to the image section
	if [ $in_image_section -eq 0 ]; then
	    echo $line | grep -q "^# only image entries below this line"
	    if [ $? -eq 0 ]; then
		in_image_section=1
	    fi
	else
	    echo $line | grep -q "^\[.*]$"
	    if [ $? -eq 0 ]; then
		current_image=$(echo $line | sed 's/^\[//' | sed 's/\]$//')
		echo -e "\tMigrating entry for $current_image"
		if [ -e "%{_sysconfdir}/systemimager/rsync_stubs/40$current_image" ]; then
		    echo -e "\t%{_sysconfdir}/systemimager/rsync_stubs/40$current_image already exists."
		    echo -e "\tI'm not going to overwrite it with the value from"
		    echo -e "\t%{_sysconfdir}/systemimager/rsyncd.conf-before-rsync-stubs.tmp"
		    current_image=""
		fi
	    fi
	    if [ "$current_image" != "" ]; then
		echo "$line" >> %{_sysconfdir}/systemimager/rsync_stubs/40$current_image
	    fi
	fi
    done < %{_sysconfdir}/systemimager/rsyncd.conf-before-rsync-stubs.tmp
    rm -f %{_sysconfdir}/systemimager/rsyncd.conf-before-rsync-stubs.tmp
    echo "Migration complete - please make sure to migrate any configuration you have"
    echo "    made in %{_sysconfdir}/systemimager/rsyncd.conf outside of the image section."
fi
## END make stubs from pre-stub %{_sysconfdir}/systemimager/rsyncd.conf file

/usr/sbin/si_mkrsyncd_conf

if [[ -a /usr/lib/lsb/install_initd ]]; then
    /usr/lib/lsb/install_initd %{_sysconfdir}/init.d/systemimager-server-rsyncd
    /usr/lib/lsb/install_initd %{_sysconfdir}/init.d/systemimager-server-netbootmond
    /usr/lib/lsb/install_initd %{_sysconfdir}/init.d/systemimager-server-monitord
fi

if [[ -a /sbin/chkconfig ]]; then
    /sbin/chkconfig --add systemimager-server-rsyncd
    /sbin/chkconfig --add systemimager-server-netbootmond
    /sbin/chkconfig --add systemimager-server-monitord
fi

%preun server

if [ $1 = 0 ]; then
	%{_sysconfdir}/init.d/systemimager-server-rsyncd stop
	%{_sysconfdir}/init.d/systemimager-server-netbootmond stop
	%{_sysconfdir}/init.d/systemimager-server-monitord stop

	if [[ -a /usr/lib/lsb/remove_initd ]]; then
	    /usr/lib/lsb/remove_initd %{_sysconfdir}/init.d/systemimager-server-rsyncd
	    /usr/lib/lsb/remove_initd %{_sysconfdir}/init.d/systemimager-server-netbootmond
	    /usr/lib/lsb/remove_initd %{_sysconfdir}/init.d/systemimager-server-monitord
	fi

	if [[ -a /sbin/chkconfig ]]; then
	    /sbin/chkconfig --del systemimager-server-rsyncd
	    /sbin/chkconfig --del systemimager-server-netbootmond
	    /sbin/chkconfig --del systemimager-server-monitord
	fi

	if [[ -a %{_sysconfdir}/xinetd.d/rsync.presis~ ]]; then
	    mv %{_sysconfdir}/xinetd.d/rsync.presis~ %{_sysconfdir}/xinetd.d/rsync
	    `pidof xinetd > /dev/null`
	    if [[ $? == 0 ]]; then
	        %{_sysconfdir}/init.d/xinetd restart
	    fi
	fi
else
	echo
	echo "WARNING: this seems to be an upgrade!"
	echo
	echo "Remember that this operation does not touch the following objects:"
	echo "  - master, pre-install, post-install scripts"
	echo "  - images"
	echo "  - overrides"
	echo

	# This is an upgrade: restart the daemons.
	echo "Restarting services..."
	(%{_sysconfdir}/init.d/systemimager-server-rsyncd status >/dev/null 2>&1 && \
		%{_sysconfdir}/init.d/systemimager-server-rsyncd restart) || true
	(%{_sysconfdir}/init.d/systemimager-server-netbootmond status >/dev/null 2>&1 && \
		%{_sysconfdir}/init.d/systemimager-server-netbootmond restart) || true
	(%{_sysconfdir}/init.d/systemimager-server-monitord status >/dev/null 2>&1 && \
		%{_sysconfdir}/init.d/systemimager-server-monitord restart) || true
fi

%post flamethrower
if [[ -a /usr/lib/lsb/install_initd ]]; then
    /usr/lib/lsb/install_initd %{_sysconfdir}/init.d/systemimager-server-flamethrowerd
fi

if [[ -a /sbin/chkconfig ]]; then
    /sbin/chkconfig --add systemimager-server-flamethrowerd
    /sbin/chkconfig systemimager-server-flamethrowerd off
fi

%preun flamethrower
if [ $1 = 0 ]; then
	%{_sysconfdir}/init.d/systemimager-server-flamethrowerd stop

	if [[ -a /usr/lib/lsb/remove_initd ]]; then
	    /usr/lib/lsb/remove_initd %{_sysconfdir}/init.d/systemimager-server-flamethrowerd
	fi

	if [[ -a /sbin/chkconfig ]]; then
	    /sbin/chkconfig --del systemimager-server-flamethrowerd
	fi
else
	# This is an upgrade: restart the daemon.
	(%{_sysconfdir}/init.d/systemimager-server-flamethrowerd status >/dev/null 2>&1 && \
		%{_sysconfdir}/init.d/systemimager-server-flamethrowerd restart) || true
fi

%post bittorrent
if [[ -a /usr/lib/lsb/install_initd ]]; then
    /usr/lib/lsb/install_initd %{_sysconfdir}/init.d/systemimager-server-bittorrent
fi

if [[ -a /sbin/chkconfig ]]; then
    /sbin/chkconfig --add systemimager-server-bittorrent
    /sbin/chkconfig systemimager-server-bittorrent off
fi

%pre bittorrent
echo "checking for a tracker binary..."
BT_TRACKER_BIN=`(which bittorrent-tracker || which bttrack) 2>/dev/null`
if [ -z $BT_TRACKER_BIN ]; then
	echo "WARNING: couldn't find a valid tracker binary!"
	echo "--> Install the BitTorrent package (bittorrent for RH)."
	echo "--> For details, please see http://wiki.systemimager.org/index.php/Quick_Start_HOWTO"
else
	echo done
fi

echo "checking for a maketorrent binary..."
BT_MAKETORRENT_BIN=`(which maketorrent-console || which btmaketorrent) 2>/dev/null`
if [ -z $BT_MAKETORRENT_BIN ]; then
	echo "WARNING: couldn't find a valid maketorrent binary!"
	echo "--> Install the BitTorrent package (bittorrent for RH)."
	echo "--> For details, please see http://wiki.systemimager.org/index.php/Quick_Start_HOWTO"
else
	echo done
fi

echo "checking for a bittorrent binary..."
BT_BITTORRENT_BIN=`(which launchmany-console || which btlaunchmany) 2>/dev/null`
if [ -z $BT_BITTORRENT_BIN ]; then
	echo "WARNING: couldn't find a valid bittorrent binary!"
	echo "--> Install the BitTorrent package (bittorrent for RH)."
	echo "--> For details, please see http://wiki.systemimager.org/index.php/Quick_Start_HOWTO"
else
	echo done
fi

%preun bittorrent
if [ $1 = 0 ]; then
	%{_sysconfdir}/init.d/systemimager-server-bittorrent stop

	if [[ -a /usr/lib/lsb/remove_initd ]]; then
	    /usr/lib/lsb/remove_initd %{_sysconfdir}/init.d/systemimager-server-bittorrent
	fi

	if [[ -a /sbin/chkconfig ]]; then
	    /sbin/chkconfig --del systemimager-server-bittorrent
	fi
else
	# This is an upgrade: restart the daemon.
	(%{_sysconfdir}/init.d/systemimager-server-bittorrent status >/dev/null 2>&1 && \
		%{_sysconfdir}/init.d/systemimager-server-bittorrent restart) || true
fi

%files common
%defattr(-, root, root)
%{_bindir}/si_lsimage
%{_mandir}/man8/si_lsimage*
%{_mandir}/man5/autoinstall*
%dir %{perl_vendorlib}/SystemImager
%{perl_vendorlib}/SystemImager/Common.pm
%{perl_vendorlib}/SystemImager/Config.pm
%{perl_vendorlib}/SystemImager/Options.pm
%{perl_vendorlib}/SystemImager/UseYourOwnKernel.pm
%dir %{_sysconfdir}/systemimager
%config %{_sysconfdir}/systemimager/UYOK.modules_to_exclude
%config %{_sysconfdir}/systemimager/UYOK.modules_to_include

%files server
%defattr(-, root, root)
%doc CHANGE.LOG COPYING CREDITS README TODO VERSION
%doc README.SystemImager_DHCP_options
%doc doc/manual_source/html
# These should move to a files doc section, because they are missing if you don't do doc
# %doc doc/manual/systemimager* doc/manual/html doc/manual/examples
%doc doc/man/autoinstall* doc/examples/local.cfg
%dir /var/lock/systemimager
%dir /var/log/systemimager
%dir %{_sharedstatedir}/systemimager
%dir %{_sharedstatedir}/systemimager/images
%dir %{_sharedstatedir}/systemimager/scripts
%dir %{_sharedstatedir}/systemimager/scripts/pre-install
%dir %{_sharedstatedir}/systemimager/scripts/post-install
%dir %{_sharedstatedir}/systemimager/overrides
%{_sharedstatedir}/systemimager/overrides/README
%dir %{_datarootdir}/systemimager
%dir %{_datarootdir}/systemimager/icons
%config %{_sysconfdir}/systemimager/pxelinux.cfg/*
%config %{_sysconfdir}/systemimager/kboot.cfg/*
%config %{_sysconfdir}/systemimager/autoinstallscript.template
%config(noreplace) %{_sysconfdir}/systemimager/rsync_stubs/*
%config(noreplace) %{_sysconfdir}/systemimager/systemimager.conf
%config(noreplace) %{_sysconfdir}/systemimager/cluster.xml
%config(noreplace) %{_sysconfdir}/systemimager/getimage.exclude
%{_sysconfdir}/init.d/systemimager-server-rsyncd
%{_sysconfdir}/init.d/systemimager-server-netboot*
%{_sysconfdir}/init.d/systemimager-server-monitord
%{_sharedstatedir}/systemimager/images/*
%{_sharedstatedir}/systemimager/scripts/post-install/*
%{_sharedstatedir}/systemimager/scripts/pre-install/*
%{_sbindir}/si_addclients
%{_sbindir}/si_cpimage
%{_sbindir}/si_getimage
%{_sbindir}/si_mk*
%{_sbindir}/si_mvimage
%{_sbindir}/si_netbootmond
%{_sbindir}/si_pushupdate
%{_sbindir}/si_pushinstall
%{_sbindir}/si_rmimage
%{_sbindir}/si_monitor
%{_sbindir}/si_monitortk
%{_bindir}/si_clusterconfig
%{_bindir}/si_mk*
%{_bindir}/si_psh
%{_bindir}/si_pcp
%{_bindir}/si_pushoverrides
%{perl_vendorlib}/SystemImager/Server.pm
%{perl_vendorlib}/SystemImager/Config.pm
%{perl_vendorlib}/SystemImager/HostRange.pm
%{_prefix}/lib/systemimager/confedit
%{perl_vendorlib}/BootMedia
%{perl_vendorlib}/BootGen
%{_mandir}/man5/systemimager*
%{_mandir}/man8/si_*
%{_datarootdir}/systemimager/icons/*

%files client
%defattr(-, root, root)
%doc CHANGE.LOG COPYING CREDITS README VERSION
%config %{_sysconfdir}/systemimager/updateclient.local.exclude
%config %{_sysconfdir}/systemimager/client.conf
%{_sbindir}/si_updateclient
%{_sbindir}/si_prepareclient
%{_mandir}/man8/si_updateclient*
%{_mandir}/man8/si_prepareclient*
%{perl_vendorlib}/SystemImager/Client.pm

%files flamethrower
%defattr(-, root, root)
%doc CHANGE.LOG COPYING CREDITS README VERSION
%dir /var/state/systemimager/flamethrower
%config %{_sysconfdir}/systemimager/flamethrower.conf
%{_sysconfdir}/init.d/systemimager-server-flamethrowerd

%files bittorrent
%defattr(-, root, root)
%dir %{_sharedstatedir}/systemimager/tarballs
%dir %{_sharedstatedir}/systemimager/torrents
%config %{_sysconfdir}/systemimager/bittorrent.conf
%{_sysconfdir}/init.d/systemimager-server-bittorrent
%{_sbindir}/si_installbtimage

%endif

%files %{_build_arch}boot-%{_boot_flavor}
%defattr(-, root, root)
%dir %{_datarootdir}/systemimager/boot/%{_build_arch}
%dir %{_datarootdir}/systemimager/boot/%{_build_arch}/standard
%{_datarootdir}/systemimager/boot/%{_build_arch}/standard/config
%{_datarootdir}/systemimager/boot/%{_build_arch}/standard/initrd.img
%{_datarootdir}/systemimager/boot/%{_build_arch}/standard/kernel
#prefix/share/systemimager/boot/%{_build_arch}/standard/boel_binaries.tar.gz

%files %{_build_arch}initrd_template
%defattr(-, root, root)
%dir %{_datarootdir}/systemimager/boot/%{_build_arch}/standard/initrd_template
%{_datarootdir}/systemimager/boot/%{_build_arch}/standard/initrd_template/*
