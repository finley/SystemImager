%define name     va-systemimager
%define ver      1.4.0
%define rel      1
%define prefix   /usr

Summary: Software that automates Linux installs and software distribution.
Name: %name
Version: %ver
Release: %rel
Copyright: GPL
Group: Applications/System
Conflicts: va-systemimager-client
Source: http://download.sourceforge.net/systemimager/%{name}-%{ver}.tar.gz
BuildRoot: /tmp/%{name}-%{ver}-root
Packager: Michael Jennings <mej@valinux.com>
Docdir: %{prefix}/doc
URL: http://systemimager.org/
Requires: rsync >= 2.4.6, syslinux >= 1.48, dhcp = 2.0, fileutils, grep, util-linux, sh-utils, gawk, sed, findutils, textutils, perl, dosfstools

%description
VA SystemImager is software that automates Linux installs and software
distribution.  It also makes software distribution, configuration, and
operating system updates easy. You can even update from one Linux 
release version to another! VA SystemImager can also be used for 
content distribution on web servers.  It is most useful in environments
where you have large numbers of identical machines. Some typical
environments include: Internet server farms, high performance clusters,
computer labs, or corporate desktop environments where all workstations
have the same basic hardware configuration.

%package client
Summary: VA SystemImager "golden client" software
Group: Applications/System
Conflicts: va-systemimager
Requires: rsync >= 2.4.6, util-linux, sh-utils, fileutils, grep, gawk, sed, findutils, textutils, perl, mtools

%description client
This is the package you install on a VA SystemImager "golden client".
It prepares the "golden client" to have its image retrieved by an 
image server.

%changelog

%prep
%setup

%changelog

%build

%install
rm -rf $RPM_BUILD_ROOT

DESTDIR=$RPM_BUILD_ROOT ; export DESTDIR
prefix=%{prefix} ; export prefix
./install -q -n

mkdir -p $RPM_BUILD_ROOT/etc/systemimager/
install -m 644 tftpstuff/systemimager/systemimager.exclude $RPM_BUILD_ROOT/etc/systemimager/
install -m 755 tftpstuff/systemimager/prepareclient        $RPM_BUILD_ROOT/usr/sbin/
install -m 755 tftpstuff/systemimager/updateclient         $RPM_BUILD_ROOT/usr/sbin/

%clean
rm -rf $RPM_BUILD_ROOT

%post
cd /usr/doc/va-systemimager-%{ver}/ && ./afterburner -q -n

%post client

%postun

%files
%defattr(-, root, root)
%doc CHANGE.LOG COPYING CREDITS FAQ-HOWTO README TODO VERSION afterburner local.cfg
/var/*

/tftpboot/initrd.gz
/tftpboot/kernel

/tftpboot/pxelinux.cfg/*

/tftpboot/systemimager/grep
/tftpboot/systemimager/mkraid
/tftpboot/systemimager/raidstart
/tftpboot/systemimager/raidstop
/tftpboot/systemimager/mkreiserfs
/tftpboot/systemimager/prepareclient
/tftpboot/systemimager/sfdisk
/tftpboot/systemimager/systemimager.exclude
/tftpboot/systemimager/updateclient

/usr/sbin/addclients
/usr/sbin/getimage
/usr/sbin/makeautoinstalldiskette
/usr/sbin/makeautoinstallcd
/usr/sbin/makedhcpserver
/usr/sbin/makedhcpstatic


%files client
%defattr(-, root, root)
%doc CHANGE.LOG COPYING CREDITS FAQ-HOWTO README TODO VERSION local.cfg
/usr/sbin/updateclient
/usr/sbin/prepareclient
%config /etc/systemimager/systemimager.exclude
