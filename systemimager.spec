#
#    This file is part of SystemImager.
#
#    SystemImager is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 2 of the License, or
#    (at your option) any later version.
#
#    SystemImager is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with SystemImager. If not, see <https://www.gnu.org/licenses/>.
#
#    Copyright (C) 2012-2019 Olivier LAHAYE <olivier.lahaye1@free.fr>
#
#    Purpose:
#      This is the spec file that describez the build of the systemimager
#      RPM package.
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
%define rel      ##PKG_REL##%{?dist}
%define dracut_module_index 51
%define packager Olivier Lahaye <olivier.lahaye@cea.fr>
#define prefix   /usr
%define _build_all 1
%define _boot_flavor standard
# Set this to 1 to build only the boot rpm
# it can also be done in the .rpmmacros file
#define _build_only_boot 1
%{?_build_only_boot:%{expand: %%define _build_all 0}}

# Since Fedora 20, %doc macro will store doc in unversionned directory.
# If this macro doesn't exists, then we have to define it to versionned
# directory. If it's defined, it's correct (F18 and 19 uses versionned dirs
# and Fedora 20 and upward will use unversionned version.
# Source: http://fedoraproject.org/wiki/Changes/UnversionedDocdirs
# OL: BUG => Missing "-server" before version
%{!?_pkgdocdir: %global _pkgdocdir %{_docdir}/%{name}-%{version}}

%define _unpackaged_files_terminate_build 0
# Allow initrd_template binaries ion a noarch package.
# indeed, x86_64 initrd template should be installable on another arch as "data"
# in order to generate initrd for this arch.
%define _binaries_in_noarch_packages_terminate_build   0

# prevent RPM from stripping files (eg. bittorrent binaries)
%define __spec_install_post /usr/lib/rpm/brp-compress
# prevent RPM files to be changed by prelink
%{?__prelink_undo_cmd:%undefine __prelink_undo_cmd}

# define _dracutbase
%define _dracutbase %(test -d /usr/lib/dracut && echo '/lib/dracut' || echo '/share/dracut')

%define is_suse %(grep -E "(suse)" /etc/os-release > /dev/null 2>&1 && echo 1 || echo 0)
#define is_suse %(test -f /etc/SuSE-release && echo 1 || echo 0)
%define is_ppc64 %([ "`uname -m`" = "ppc64" ] && echo 1 || echo 0)
%define is_ps3 %([ `grep PS3 /proc/cpuinfo >& /dev/null; echo $?` -eq 0 ] && echo 1 || echo 0) 

%if %is_ppc64
%define _arch ppc64
%endif

%if %is_ps3
%define _arch ppc64-ps3
%endif

# Packages definitions
%if 0%{?rhel} == 6
%define pkg_ipcalc initscripts
%define pkg_sshd openssh-server
%define pkg_btrfs_progs btrfs-progs
%define pkg_ntfsprogs ntfsprogs
%define pkg_dejavu_font dejavu-serif-fonts, dejavu-sans-fonts
%define pkg_docbook_utils docbook-utils, docbook-utils-pdf
%define pkg_mkisofs mkisofs
%define pkg_ncat nmap
%define pkg_pidof sysvinit-tools
%define pkg_dhcpd dhcp
%define pkg_transmission_cli transmission-cli
%define pkg_transmission_daemon transmission-daemon
%define web_vhosts_dir %{_sysconfdir}/httpd/conf.d
%endif
%if 0%{?rhel} == 7
%define pkg_ipcalc initscripts
%define pkg_sshd openssh-server
%define pkg_btrfs_progs btrfs-progs
%define pkg_ntfsprogs ntfsprogs
%define pkg_dejavu_font dejavu-serif-fonts, dejavu-sans-fonts
%define pkg_docbook_utils docbook-utils, docbook-utils-pdf
%define pkg_mkisofs mkisofs
%define pkg_ncat nmap-ncat
%define pkg_pidof sysvinit-tools
%define pkg_dhcpd dhcp
%define pkg_transmission_cli transmission-cli
%define pkg_transmission_daemon transmission-daemon
%define web_vhosts_dir %{_sysconfdir}/httpd/conf.d
%endif
%%if 0%{?rhel} >= 8
%define pkg_ipcalc ipcalc
%define pkg_sshd openssh-server
#define pkg_btrfs_progs
#define pkg_ntfsprogs
%define pkg_dejavu_font dejavu-serif-fonts, dejavu-sans-fonts
%define pkg_docbook_utils docbook-utils
%define pkg_mkisofs genisoimage
%define pkg_ncat nmap-ncat
%define pkg_pidof procps-ng
%define pkg_dhcpd dhcp-server
%define pkg_transmission_cli transmission-cli
%define pkg_transmission_daemon transmission-daemon
%define web_vhosts_dir %{_sysconfdir}/httpd/conf.d
%endif
%if 0%{?fedora} > 26
%define pkg_ipcalc ipcalc
%define pkg_sshd openssh-server
%define pkg_btrfs_progs btrfs-progs
%define pkg_ntfsprogs ntfsprogs
%define pkg_dejavu_font dejavu-serif-fonts, dejavu-sans-fonts
%define pkg_docbook_utils docbook-utils, docbook-utils-pdf
%define pkg_mkisofs mkisofs
%define pkg_ncat nmap-ncat
%define pkg_pidof procps-ng
%define pkg_dhcpd dhcp-server
%define pkg_transmission_cli transmission-cli
%define pkg_transmission_daemon transmission-daemon
%define web_vhosts_dir %{_sysconfdir}/httpd/conf.d
%endif
%if %is_suse%{?is_opensuse}
%define pkg_ipcalc ipcalc
%define pkg_sshd openssh
%define pkg_btrfs_progs btrfsprogs
%define pkg_ntfsprogs ntfsprogs
%define pkg_dejavu_font dejavu-fonts
%define pkg_docbook_utils docbook-utils
%define pkg_mkisofs cdrtools
%define pkg_ncat ncat
%define pkg_pidof sysvinit-tools
%define pkg_dhcpd dhcp-server
%define pkg_transmission_cli transmission
%define pkg_transmission_daemon transmission-daemon
%define web_vhosts_dir %{_sysconfdir}/apache2/vhosts.d
%endif

# Still use the correct lib even on fc-18+ where --target noarch sets _libdir to /usr/lib even on x86_64 arch.
%define static_libcrypt_a /usr/lib/libcrypt.a
%if "%(arch)" == "x86_64" || "%(arch)" == "aarch64"
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
BuildRequires: bc, rsync >= 2.4.6, coreutils, dracut
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
the new production environment is found to be flawed, simply roll-back
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
Requires: rsync >= 2.4.6, systemimager-common = %{version}, dracut-systemimager = %{version}, perl-AppConfig, perl, perl(XML::Simple) >= 2.14
Requires: %pkg_dhcpd
Requires(post): systemimager-common = %{version}
Requires: %pkg_mkisofs
# If systemd
%if 0%{?_unitdir:1}
%systemd_requires
%else
Requires: /sbin/chkconfig
%endif
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
the new production environment is found to be flawed, simply roll-back 
to the last production image with a simple update command!  Some 
typical environments include: Internet server farms, database server 
farms, high performance clusters, computer labs, and corporate desktop
environments.

The server package contains those files needed to run a SystemImager
server.

%package doc
Summary: Systemimager manual and other documentation
Version: %ver
Release: %rel
License: GPL
Group: Applications/System
BuildRoot: /tmp/%{name}-%{ver}-root
BuildArch: noarch
Packager: %packager
URL: http://wiki.systemimager.org/
BuildRequires: dos2unix
BuildRequires: %pkg_docbook_utils
Distribution: System Installation Suite

%description doc
SystemImager is software that automates Linux installs, software
distribution, and production deployment.  SystemImager makes it easy to
do installs, software distribution, content or data distribution,
configuration changes, and operating system updates to your network of
Linux machines. You can even update from one Linux release version to
another!  It can also be used to ensure safe production deployments.
By saving your current production image before updating to your new
production image, you have a highly reliable contingency mechanism.  If
the new production environment is found to be flawed, simply roll-back
to the last production image with a simple update command!  Some
typical environments include: Internet server farms, database server
farms, high performance clusters, computer labs, and corporate desktop
environments.

The doc package provides End-User and Administrator guides for setting up
and use Systemimager. It also includes many configuration examples.

%package server-flamethrower
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
Obsoletes: systemimager-flamethrower
Requires: systemimager-server = %{version}, perl, flamethrower >= 0.1.6
# If systemd
%if 0%{?_unitdir:1}
%systemd_requires
%else
Requires: /sbin/chkconfig
%endif
#AutoReqProv: no

%description server-flamethrower
SystemImager is software that automates Linux installs, software 
distribution, and production deployment.  SystemImager makes it easy to
do installs, software distribution, content or data distribution, 
configuration changes, and operating system updates to your network of 
Linux machines. You can even update from one Linux release version to 
another!  It can also be used to ensure safe production deployments.  
By saving your current production image before updating to your new 
production image, you have a highly reliable contingency mechanism.  If
the new production environment is found to be flawed, simply roll-back 
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
Requires: perl, perl-JSON
Requires: systemimager-webgui
# systemimager-webgui is requred by JConfig.pm for the config_scheme.json file.

%description common
SystemImager is software that automates Linux installs, software 
distribution, and production deployment.  SystemImager makes it easy to
do installs, software distribution, content or data distribution, 
configuration changes, and operating system updates to your network of 
Linux machines. You can even update from one Linux release version to 
another!  It can also be used to ensure safe production deployments.  
By saving your current production image before updating to your new 
production image, you have a highly reliable contingency mechanism.  If
the new production environment is found to be flawed, simply roll-back 
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
Requires: systemimager-common = %{version}, perl-AppConfig, rsync >= 2.4.6, perl
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
the new production environment is found to be flawed, simply roll-back
to the last production image with a simple update command!  Some
typical environments include: Internet server farms, database server
farms, high performance clusters, computer labs, and corporate desktop
environments.

The client package contains the files needed on a machine for it to
be imaged by a SystemImager server.

%endif

%package %{_arch}boot-%{_boot_flavor}
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
Obsoletes: systemimager-%{_arch}boot
# SuSE includes dracut-netwok in main package
%if ! %is_suse%{?is_opensuse}
BuildRequires: dracut-network
%endif
# SuSE has separate package for plymouth in dracut
%if %is_suse%{?is_opensuse}
BuildRequires: plymouth-dracut
%endif
BuildRequires: %pkg_transmission_cli
BuildRequires: perl-JSON
BuildRequires: dracut
BuildRequires: plymouth-plugin-script, plymouth-plugin-label
BuildRequires: psmisc, kexec-tools, bind-utils, net-tools, ethtool, lsscsi, usbutils, pciutils, lshw, hwdata, iputils, dmidecode
BuildRequires: xmlstarlet, jq
BuildRequires: parted, mdadm, util-linux, lvm2, gdisk
BuildRequires: xfsprogs, e2fsprogs, dosfstools
%if 0%{?pkg_btrfs_progs:1}
BuildRequires: %pkg_btrfs_progs
%endif
%if 0%{?pkg_ntfsprogs:1}
BuildRequires: %pkg_ntfsprogs
%endif
BuildRequires: %pkg_ipcalc
BuildRequires: %pkg_dejavu_font
BuildRequires: %pkg_ncat
BuildRequires: %pkg_sshd
BuildRequires: ncurses, /usr/bin/awk, kbd
BuildRequires: gettext, bc
BuildRequires: kernel, coreutils
BuildRequires: cryptsetup
BuildRequires: udpcast, flamethrower
%if 0%{?rhel} == 6
BuildRequires:  udev
%else
BuildRequires:  systemd
%endif
# CentOS-7 plymouth ask-for-password is buggy
# https://bugzilla.redhat.com/show_bug.cgi?id=1600990
BuildRequires: socat
# Debug tools (for scripts)
BuildRequires: strace, lsof
BuildRequires: %{pkg_pidof}
%if %is_ps3
BuildRequires: dtc
%endif
Requires: systemimager-server >= %{version}
Requires: %{name}-initrd_template = %{version}
Provides: %{name}-boot-%{_boot_flavor} = %{version}
AutoReqProv: no

%description %{_arch}boot-%{_boot_flavor}
SystemImager is software that automates Linux installs, software 
distribution, and production deployment.  SystemImager makes it easy to
do installs, software distribution, content or data distribution, 
configuration changes, and operating system updates to your network of 
Linux machines. You can even update from one Linux release version to 
another!  It can also be used to ensure safe production deployments.  
By saving your current production image before updating to your new 
production image, you have a highly reliable contingency mechanism.  If
the new production environment is found to be flawed, simply roll-back 
to the last production image with a simple update command!  Some 
typical environments include: Internet server farms, database server 
farms, high performance clusters, computer labs, and corporate desktop
environments.

The %{_arch}boot package provides specific kernel, ramdisk, and fs utilities
to boot and install %{_arch} Linux machines during the SystemImager autoinstall
process.

%package initrd_template
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
Requires: %{name}-%{_arch}boot-%{_boot_flavor} = %{version}
Obsoletes: %{name}-%{_arch}initrd_template = %{version}
AutoReqProv: no

%description initrd_template
SystemImager is software that automates Linux installs, software
distribution, and production deployment.  SystemImager makes it easy to
do installs, software distribution, content or data distribution,
configuration changes, and operating system updates to your network of
Linux machines. You can even update from one Linux release version to
another!  It can also be used to ensure safe production deployments.
By saving your current production image before updating to your new
production image, you have a highly reliable contingency mechanism.  If
the new production environment is found to be flawed, simply roll-back
to the last production image with a simple update command!  Some
typical environments include: Internet server farms, database server
farms, high performance clusters, computer labs, and corporate desktop
environments.

The initrd_template package provides initrd template files for creating custom
ramdisk that works with a specific kernel by using UYOK (Use Your Own Kernel).  The custom
ramdisk can then be used to boot and install Linux machines during the
SystemImager autoinstall process.

%package server-bittorrent
Summary: Software that automates Linux installs, software distribution, and production deployment.
Version: %ver
Release: %rel
License: GPL
Group: Applications/System
Obsoletes: systemimager-bittorrent
BuildRoot: /tmp/%{name}-%{ver}-root
BuildArch: noarch
Packager: %packager
URL: http://wiki.systemimager.org/
Distribution: System Installation Suite
Requires: systemimager-server = %{version}, perl, perl(Getopt::Long)
# transmission-cli pkg needed for transmission-create command
Requires: %pkg_transmission_cli
Requires: %pkg_transmission_daemon
# If systemd
%if 0%{?_unitdir:1}
%systemd_requires
%else
Requires: /sbin/chkconfig
%endif
#AutoReqProv: no

%description server-bittorrent
SystemImager is software that automates Linux installs, software
distribution, and production deployment.  SystemImager makes it easy to
do installs, software distribution, content or data distribution,
configuration changes, and operating system updates to your network of
Linux machines. You can even update from one Linux release version to
another!  It can also be used to ensure safe production deployments.
By saving your current production image before updating to your new
production image, you have a highly reliable contingency mechanism.  If
the new production environment is found to be flawed, simply roll-back
to the last production image with a simple update command!  Some
typical environments include: Internet server farms, database server
farms, high performance clusters, computer labs, and corporate desktop
environments.

The bittorrent package allows you to use the BitTorrent protocol to perform
installations.

%package -n dracut-%{name}
Summary: dracut modules to build a dracut initramfs with systemimager support
Version: %ver
Release: %rel
License: GPL
Group: Applications/System
BuildRoot: /tmp/%{name}-%{ver}-root
BuildArch: noarch
Packager: %packager
URL: http://wiki.systemimager.org/
Distribution: System Installation Suite
Requires: systemimager-server = %{version}
# SuSE includes dracut-netwok in main package
%if ! %is_suse%{?is_opensuse}
requires: dracut-network
%endif
# SuSE has separate package for plymouth in dracut
%if %is_suse%{?is_opensuse}
Requires: plymouth-dracut
%endif
Requires: dracut
Requires: plymouth-plugin-script, plymouth-plugin-label
Requires: psmisc, kexec-tools, bind-utils, net-tools, ethtool, lsscsi, usbutils, pciutils, lshw, hwdata, iputils, dmidecode
Requires: xmlstarlet, jq
Requires: parted, mdadm, util-linux, lvm2, gdisk
Requires: xfsprogs, e2fsprogs, dosfstools
%if 0%{?pkg_btrfs_progs:1}
Requires: %pkg_btrfs_progs
%endif
%if 0%{?pkg_ntfsprogs:1}
Requires: %pkg_ntfsprogs
%endif
Requires: %pkg_ipcalc
Requires: %pkg_dejavu_font
Requires: %pkg_ncat
Requires: %pkg_sshd
Requires: ncurses, /usr/bin/awk, kbd
Requires: gettext, bc
Requires: kernel, coreutils
Requires: systemimager-initrd_template
Requires: cryptsetup
Requires: udpcast, flamethrower
# transmission-cli pkg needed for transmission-cli command
Requires: %pkg_transmission_cli
%if 0%{?rhel} == 6
Requires:  udev
%else
Requires:  systemd
%endif
# CentOS-7 plymouth ask-for-password is buggy
# https://bugzilla.redhat.com/show_bug.cgi?id=1600990
Requires: socat
# Debug tools (for scripts)
Requires: strace, lsof
Requires: %{pkg_pidof}

#AutoReqProv: no
%description -n dracut-%{name}
This package is a dracut modules that automates the systeimager initramfs creation.

%package webgui
Summary: SystemImager admin web interface.
Version: %ver
Release: %rel
License: GPL
Group: Applications/System
BuildRoot: /tmp/%{name}-%{ver}-root
BuildArch: noarch
Packager: %packager
URL: http://wiki.systemimager.org/
Distribution: System Installation Suite
Requires: systemimager-server = %{version}
Requires: httpd php php-json
# Need common package to be installed so config_scheme.json is avalable for %post
Requires(post): systemimager-common = %{version}
BuildRequires: httpd

%description webgui
SystemImager admin web interface.

%prep

# Prepare source tree
%setup -q

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
%{__make} -j1 all DESTDIR=%{buildroot} PREFIX=%_prefix DRACUT_BASEDIR=%_dracutbase
%{__make} -C doc/manual_source html

%else
%{__make} binaries DESTDIR=%{buildroot} PREFIX=%_prefix DRACUT_BASEDIR=%_dracutbase

%endif

# Fix docdir in ./sbin/si_* commands when usage() will refere to this path.
for FILE in ./sbin/si_mkbootpackage ./README
do
	sed -i -e 's|SYSTEMIMAGER_DOC_DIR|%{_pkgdocdir}|g' $FILE
done

# Build an initrd.img for current kernel.
# 1st: recreate a full dracut local basedir so --local option can be used.
echo "Creating local dracut environment"
LOCAL_DRACUT_BASEDIR=./tmp/dracutbase
test -d $LOCAL_DRACUT_BASEDIR && /bin/rm -rf $LOCAL_DRACUT_BASEDIR
mkdir -p $LOCAL_DRACUT_BASEDIR
test -d $LOCAL_DRACUT_BASEDIR || exit 1
cp -r %_usr%_dracutbase/* $LOCAL_DRACUT_BASEDIR/
# Remove old systemimager parasit version that we could have copied.
rm -rf $LOCAL_DRACUT_BASEDIR/modules.d/*systemimager
# Copy our module locally while doing correct STRINGS replacement.
make install_dracut DRACUT_MODULES=$LOCAL_DRACUT_BASEDIR/modules.d
#mkdir -p $LOCAL_DRACUT_BASEDIR/modules.d/%{dracut_module_index}systemimager
#for FILE in ./lib/dracut/modules.d/%{dracut_module_index}systemimager/{check,install,*.sh}
#do
#    ./tools/si_install  -b -m 755 $FILE $LOCAL_DRACUT_BASEDIR/modules.d/%{dracut_module_index}systemimager/
#done
#cp -r ./lib/dracut/modules.d/%{dracut_module_index}systemimager/plymouth_theme $LOCAL_DRACUT_BASEDIR/modules.d/%{dracut_module_index}systemimager/
test -x /usr/bin/lsinitrd && ln -s /usr/bin/lsinitrd $LOCAL_DRACUT_BASEDIR/lsinitrd.sh # only required in newer dracut versions.

# move to local modules dir so we can use dracut --local
cd $LOCAL_DRACUT_BASEDIR/

SIS_DATAROOTDIR=$RPM_BUILD_DIR/%{name}-%{version}/conf SIS_CONFDIR=$RPM_BUILD_DIR/%{name}-%{version}/etc dracutbasedir=$(pwd) SI_INITRD_TEMPLATE=../../initrd_source/skel perl -I ../../lib ../../sbin/si_mkbootpackage --dracut-opts="--local" --destination ../..
#dracut --force --local --add systemimager --no-hostonly --no-hostonly-cmdline --no-hostonly-i18n ../../../initrd.img $(uname -r)

%install
cd $RPM_BUILD_DIR/%{name}-%{version}/

%if %{_build_all}

make install_all DESTDIR=%{buildroot} PREFIX=%_prefix DRACUT_BASEDIR=%_dracutbase # DOC=%{buildroot}%{_pkgdocdir}

cp ./initrd.img %{buildroot}/%{_datarootdir}/systemimager/boot/%{_arch}/standard/initrd.img
cp ./kernel     %{buildroot}/%{_datarootdir}/systemimager/boot/%{_arch}/standard/kernel
test -f ./config && cp ./config     %{buildroot}/%{_datarootdir}/systemimager/boot/%{_arch}/standard/config
cp version.txt %{buildroot}/%{_datarootdir}/systemimager/boot/%{_arch}/standard/version.txt

%else

%{__make} install_binaries DESTDIR=%{buildroot} PREFIX=%_prefix DRACUT_BASEDIR=%_dracutbase

%endif

# Some things that get duplicated because there are multiple calls to
# the make install_* phases.
find %{buildroot} -name \*~ -exec rm -f '{}' \;

%clean
#__rm -rf $RPM_BUILD_DIR/%{name}-%{version}/
%__rm -rf %{buildroot}

%if %{_build_all}

%pre -n dracut-%{name}
test -x /usr/sbin/mkfs.jfs || echo "WARNING: /usr/sbin/mkfs.jfs mot present. JFS support not available."
test -x /usr/sbin/mkfs.reiserfs || echo "WARNING: /usr/sbin/mkfs.reiserfs mot present. ReiserFS support not available."

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
# If systemd
%if 0%{?_unitdir:1}
systemctl disable rsyncd.socket
%else
if [[ -a %{_sysconfdir}/xinetd.d/rsync ]]; then
    mv %{_sysconfdir}/xinetd.d/rsync %{_sysconfdir}/xinetd.d/rsync.presis~
    `pidof xinetd > /dev/null`
    if [[ $? == 0 ]]; then
        if [ -z $DURING_INSTALL ]; then
            %{_sysconfdir}/init.d/xinetd restart
        fi
    fi
fi
%endif

# Then we make sure that a config file exists and is accessible by webgui.
perl - << EOF                           
use SystemImager::JConfig;
EOF
chmod 644 /etc/systemimager/systemimager.json
chown apache /etc/systemimager/systemimager.json

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

# If systemd
%if 0%{?_unitdir:1}
%systemd_post systemimager-server-rsyncd
%systemd_post systemimager-server-netbootmond
%systemd_post systemimager-server-monitord
# else not systemd
%else
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
# endif systemd
%endif

%preun server
if [ $1 != 0 ]; then
    echo
    echo "WARNING: this seems to be an upgrade!"
    echo
    echo "Remember that this operation does not touch the following objects:"
    echo "  - master, pre-install, post-install scripts"
    echo "  - images"
    echo "  - overrides"
    echo
fi

# if systemd
%if 0%{?_unitdir:1}
%systemd_preun systemimager-server-rsyncd
%systemd_preun systemimager-server-netbootmond
%systemd_preun systemimager-server-monitord
# else not systemd
%else
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
	# This is an upgrade: restart the daemons.
	echo "Restarting services..."
	(%{_sysconfdir}/init.d/systemimager-server-rsyncd status >/dev/null 2>&1 && \
		%{_sysconfdir}/init.d/systemimager-server-rsyncd restart) || true
	(%{_sysconfdir}/init.d/systemimager-server-netbootmond status >/dev/null 2>&1 && \
		%{_sysconfdir}/init.d/systemimager-server-netbootmond restart) || true
	(%{_sysconfdir}/init.d/systemimager-server-monitord status >/dev/null 2>&1 && \
		%{_sysconfdir}/init.d/systemimager-server-monitord restart) || true
fi
# endif systemd/not systemd
%endif

%post server-flamethrower
# if systemd
%if 0%{?_unitdir:1}
%systemd_post systemimager-server-flamethrowerd
# else not systemd
%else
if [[ -a /usr/lib/lsb/install_initd ]]; then
    /usr/lib/lsb/install_initd %{_sysconfdir}/init.d/systemimager-server-flamethrowerd
fi

if [[ -a /sbin/chkconfig ]]; then
    /sbin/chkconfig --add systemimager-server-flamethrowerd
    /sbin/chkconfig systemimager-server-flamethrowerd off
fi
# endif systemd/not systemd
%endif

%preun server-flamethrower
# if systemd
%if 0%{?_unitdir:1}
%systemd_preun systemimager-server-flamethrowerd
# else not systemd
%else
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
# endif systemd/not systemd
%endif

%post webgui
# Make sure systemcimager configuration file is initalized.
php %{_exec_prefix}/lib/systemimager/init_systemimager_config.php > /dev/null

%post server-bittorrent
# if systemd
%if 0%{?_unitdir:1}
%systemd_post systemimager-server-bittorrent
# else not systemd
%else
if [[ -a /usr/lib/lsb/install_initd ]]; then
    /usr/lib/lsb/install_initd %{_sysconfdir}/init.d/systemimager-server-bittorrent
fi

if [[ -a /sbin/chkconfig ]]; then
    /sbin/chkconfig --add systemimager-server-bittorrent
    /sbin/chkconfig systemimager-server-bittorrent off
fi
# endif systemd/not systemd
%endif

%pre server-bittorrent
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

%preun server-bittorrent
# if systemd
%if 0%{?_unitdir:1}
%systemd_preun systemimager-server-bittorrent
# else not systemd
%else
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
# endif systemd/not systemd
%endif

%files common
%defattr(-, root, root)
%{_bindir}/si_lsimage
%{_mandir}/man8/si_lsimage*
%{_mandir}/man7/autoinstall*
%dir %{perl_vendorlib}/SystemImager
%{perl_vendorlib}/SystemImager/Common.pm
%{perl_vendorlib}/SystemImager/Options.pm
%{perl_vendorlib}/SystemImager/UseYourOwnKernel.pm
%{perl_vendorlib}/SystemImager/JConfig.pm
%dir %{_datarootdir}/systemimager
%dir %{_datarootdir}/systemimager/conf
%{_datarootdir}/systemimager/conf/config_scheme.json
%dir %{_sysconfdir}/systemimager
%config %{_sysconfdir}/systemimager/UYOK.modules_to_exclude
%config %{_sysconfdir}/systemimager/UYOK.modules_to_include

%files server
%defattr(-, root, root)
%doc CHANGE.LOG COPYING CREDITS README TODO VERSION
%doc README.SystemImager_DHCP_options
%dir /var/lock/systemimager
%dir /var/log/systemimager
%dir %{_var}/lib/systemimager
%dir %{_var}/lib/systemimager/images
%dir %{_var}/lib/systemimager/scripts
%dir %{_var}/lib/systemimager/scripts/pre-install
%dir %{_var}/lib/systemimager/scripts/main-install
%dir %{_var}/lib/systemimager/scripts/post-install
%dir %{_var}/lib/systemimager/scripts/configs
%dir %{_var}/lib/systemimager/scripts/disks-layouts
%dir %{_var}/lib/systemimager/scripts/network-configs
%dir %{_var}/lib/systemimager/overrides
%{_var}/lib/systemimager/overrides/README
%dir %{_datarootdir}/systemimager/icons
%config %{_sysconfdir}/systemimager/pxelinux.cfg/*
%config %{_sysconfdir}/systemimager/kboot.cfg/*
%config %{_sysconfdir}/systemimager/autoinstallscript.template
%config %{_sysconfdir}/systemimager/autoinstallconf.template
%config(noreplace) %{_sysconfdir}/systemimager/rsync_stubs/*
%config(noreplace) %{_sysconfdir}/systemimager/systemimager.conf
%config(noreplace) %{_sysconfdir}/systemimager/cluster.xml
%config(noreplace) %{_sysconfdir}/systemimager/getimage.exclude
%if 0%{?_unitdir:1}
%{_unitdir}/systemimager-server-monitord.service
%{_unitdir}/systemimager-server-netbootmond.service
%{_unitdir}/systemimager-server-rsyncd.service
%{_unitdir}/systemimager-server-rsyncd@.service
%{_unitdir}/systemimager-server-rsyncd.socket
%else
%{_sysconfdir}/init.d/systemimager-server-rsyncd
%{_sysconfdir}/init.d/systemimager-server-netboot*
%{_sysconfdir}/init.d/systemimager-server-monitord
%endif
%{_var}/lib/systemimager/images/*
%{_var}/lib/systemimager/scripts/pre-install/*
%{_var}/lib/systemimager/scripts/post-install/*
%{_sbindir}/si_addclients
%{_sbindir}/si_cpimage
%{_sbindir}/si_getimage
%{_sbindir}/si_lint
%{_sbindir}/si_mk*
%{_sbindir}/si_mvimage
%{_sbindir}/si_netbootmond
%{_sbindir}/si_pushupdate
%{_sbindir}/si_pushinstall
%{_sbindir}/si_rmimage
%{_bindir}/si_clusterconfig
%{_bindir}/si_mk*
%{_bindir}/si_psh
%{_bindir}/si_pcp
%{_bindir}/si_pushoverrides
%{perl_vendorlib}/SystemImager/Server.pm
%{perl_vendorlib}/SystemImager/HostRange.pm
%{_mandir}/man5/systemimager*
%{_mandir}/man7/systemimager*
%{_mandir}/man8/si_*
%{_datarootdir}/systemimager/icons/*
#{perl_vendorlib}/BootMedia
#{perl_vendorlib}/BootGen

%files doc
%defattr(-, root, root)
%doc doc/manual_source/html
# These should move to a files doc section, because they are missing if you don't do doc
# %doc doc/manual/systemimager* doc/manual/html doc/manual/examples
%doc doc/man/autoinstall*
%doc doc/examples

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

%files server-flamethrower
%defattr(-, root, root)
%doc CHANGE.LOG COPYING CREDITS README VERSION
%config %{_sysconfdir}/systemimager/flamethrower.conf
%if 0%{?_unitdir:1}
%{_unitdir}/systemimager-server-flamethrowerd.service
%else
%{_sysconfdir}/init.d/systemimager-server-flamethrowerd
%endif

%files server-bittorrent
%defattr(-, root, root)
%dir %{_var}/lib/systemimager/tarballs
%dir %{_var}/lib/systemimager/torrents
%config %{_sysconfdir}/systemimager/bittorrent.conf
%config %{_sysconfdir}/systemimager/bittorrent.json
%if 0%{?_unitdir:1}
%{_unitdir}/systemimager-server-bittorrent.service
%{_unitdir}/systemimager-server-bittorrent-seeder.service
%{_unitdir}/systemimager-server-bittorrent-tracker.service
%else
%{_sysconfdir}/init.d/systemimager-server-bittorrent
%endif
%{_sbindir}/si_installbtimage

%endif

%files %{_arch}boot-%{_boot_flavor}
%defattr(0744, root, root, 0755)
%dir %{_datarootdir}/systemimager/boot/%{_arch}
%dir %{_datarootdir}/systemimager/boot/%{_arch}/standard
%{_datarootdir}/systemimager/boot/%{_arch}/standard/config*
%{_datarootdir}/systemimager/boot/%{_arch}/standard/initrd.img
%{_datarootdir}/systemimager/boot/%{_arch}/standard/kernel
%{_datarootdir}/systemimager/boot/%{_arch}/standard/version.txt
%{_datarootdir}/systemimager/boot/%{_arch}/standard/ARCH

%files initrd_template
%defattr(-, root, root)
%dir %{_datarootdir}/systemimager/boot/initrd_template
%{_datarootdir}/systemimager/boot/initrd_template/*

%files -n dracut-%{name}
%defattr(-, root, root)
%dir %{_prefix}%{_dracutbase}/modules.d/%{dracut_module_index}systemimager
%{_prefix}%{_dracutbase}/modules.d/%{dracut_module_index}systemimager/*

%files webgui
%defattr(0644, root, root, 0755)
%config(noreplace) %{web_vhosts_dir}/systemimager.conf
%dir %{_datarootdir}/systemimager/webgui
%dir %{_datarootdir}/systemimager/webgui/css
%dir %{_exec_prefix}/lib/systemimager
%{_datarootdir}/systemimager/webgui/COPYRIGHTS
%{_datarootdir}/systemimager/webgui/index.php
%{_datarootdir}/systemimager/webgui/edit_config.php
%{_datarootdir}/systemimager/webgui/manage_netboot.php
%{_datarootdir}/systemimager/webgui/edit_clusters.php
%{_datarootdir}/systemimager/webgui/edit_dhcp.php
%{_datarootdir}/systemimager/webgui/health_console.php
%{_datarootdir}/systemimager/webgui/client_list.php
%{_datarootdir}/systemimager/webgui/client_console.php
%{_datarootdir}/systemimager/webgui/push_client_defs.php
%{_datarootdir}/systemimager/webgui/push_client_logs.php
%{_datarootdir}/systemimager/webgui/services.json
%{_datarootdir}/systemimager/webgui/statuses.json
%{_datarootdir}/systemimager/webgui/functions.php
%{_datarootdir}/systemimager/webgui/functions.js
%{_datarootdir}/systemimager/webgui/css/SystemImagerBanner.png
%{_datarootdir}/systemimager/webgui/css/Background.png
%{_datarootdir}/systemimager/webgui/css/flex_table.css
%{_datarootdir}/systemimager/webgui/css/screen.css
%{_datarootdir}/systemimager/webgui/css/sliders.css
%{_datarootdir}/systemimager/webgui/images/Alecive-Flatwoken-Apps-Dialog-Apply.svg
%{_datarootdir}/systemimager/webgui/images/Alecive-Flatwoken-Apps-Dialog-Close.svg
%{_datarootdir}/systemimager/webgui/images/Alecive-Flatwoken-Apps-Dialog-Logout.svg
%{_datarootdir}/systemimager/webgui/images/Alecive-Flatwoken-Apps-Dialog-Refresh.svg
%{_datarootdir}/systemimager/webgui/images/Alecive-Flatwoken-Apps-Settings.svg
%{_datarootdir}/systemimager/webgui/images/yes.svg
%{_datarootdir}/systemimager/webgui/images/no.svg
%{_datarootdir}/systemimager/webgui/images/health_console.png
%{_datarootdir}/systemimager/webgui/images/edit_clusters.png
%{_datarootdir}/systemimager/webgui/images/client_list.png
%{_datarootdir}/systemimager/webgui/images/edit_config.png
%{_datarootdir}/systemimager/webgui/images/manage_netboot.png
%{_datarootdir}/systemimager/webgui/images/edit_dhcp.png
%{_exec_prefix}/lib/systemimager/init_systemimager_config.php
%attr(0755, root, root) %{_exec_prefix}/lib/systemimager/get-networks-helper
%attr(0755, root, root) %{_exec_prefix}/lib/systemimager/clients-statuses-helper

%changelog
* Wed Feb 15 2023 Olivier Lahaye <olivier.lahaye@cea.fr> 4.9.1-0.3
- Add support for aarch64
- Removed systemconfigurator dependancy

* Wed Jun 08 2022 Olivier Lahaye <olivier.lahaye@cea.fr> 4.9.1-0.2
- Packaging reworked to match debian package names that are more relevant.
- Renamed systemimager-flamethrower to systemimager-server-flamethrower
- Renamed systemimager-bittorrent to systemimager-server-bittorrent

* Wed Oct 27 2021 Olivier Lahaye <olivier.lahaye@cea.fr> 4.9.1-0.1
- Bugfix release
- Port to Debian 10 and 11.

* Mon Nov 4 2019 Olivier Lahaye <olivier.lahaye@cea.fr> 4.9.0-0.1
- Port to AlmaLinux-8.4 (initrd NetworkManager based)
- Port to CentOS-8
- New web GUI (deprecated si_monitor and si_monitortk).
- New configuration based on json. Api for perl/php/javascript/bash.
- New log system that can catch stderr, stdout and system/kernel messages.

* Mon Sep 30 2019 Olivier Lahaye <olivier.lahaye@cea.fr> 4.5.0-0.25
- Removed most old build dependancy as we don't build any binaries
  since dracut is used.
- Added ethtool and lsscsi dependancy so lsscsi command and ethtool are available in imager.
- renamed %{_build_arch}initrd_template to initrd_template (no arch content).
- Port to CentOS-6, OpenSuSE-42.3
- Added ipcalc dependancy.
- added dracut-systemimager package.
- Fixed script that reports rebooted status.

* Fri Jul 18 2014 Olivier Lahaye <olivier.lahaye@cea.fr> 4.3.0-0.19
- Reverted si_netbootmond wrong fix and fixed the man instead.

* Thu Jul 17 2014 Olivier Lahaye <olivier.lahaye@cea.fr> 4.3.0-0.18
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
- Use %{buildroot} for DESTDIR
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

* Sun Jun 11 2006 Bernard Li <bli@bcgsc.ca>
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

* Mon Jul 14 2003 sis devel <sisuite-devel@lists.sourceforge.net> 3.1.4-1
- new upstream release

* Wed Jul 09 2003 sis devel <sisuite-devel@lists.sourceforge.net> 3.1.3-1
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

* Wed Apr 02 2003 sis devel <sisuite-devel@lists.sourceforge.net> 3.0.1-4
- fix mkautoinstallcd on ia64 - 751740

* Wed Apr 02 2003 sis devel <sisuite-devel@lists.sourceforge.net> 3.0.1-3
- added a patch from bef that no longer sorts module names - 755463

* Wed Apr 02 2003 sis devel <sisuite-devel@lists.sourceforge.net> 3.0.1-2
- remove eepro100 (but keep e100) so boel will fit on a floppy again

* Sun Mar 30 2003 sis devel <sisuite-devel@lists.sourceforge.net> 3.0.1-1
- new upstream bug-fix release

* Wed Jan 08 2003 sis devel <sisuite-devel@lists.sourceforge.net> 3.0.0-2
- various ia64 fixes
- stop attempting to build ps manual

* Sun Dec 08 2002 sis devel <sisuite-devel@lists.sourceforge.net> 3.0.0-1
- new upstream release

* Mon Nov 18 2002 dann frazier <dannf@dannf.org> 2.9.5-1
- new upstream release

* Sun Oct 27 2002 dann frazier <dannf@dannf.org> 2.9.4-1
- new upstream release

* Sun Oct 13 2002 dann frazier <dannf@dannf.org> 2.9.3-2
- added code to migrate users to rsync stubs

* Wed Oct 02 2002 dann frazier <dannf@dannf.org> 2.9.3-1
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

* Sun Oct 28 2001 Sean Dague <sean@dague.net> 2.0.0-3
- Added common package

* Sat Oct 20 2001  Sean Dague <sean@dague.net> 2.0.0-2
- Recombined client and server into one spec file

* Thu Oct 18 2001 Sean Dague <sean@dague.net> 2.0.0-1
- Initial build
- Based on work by Ken Segura <ksegura@5o7.org>


