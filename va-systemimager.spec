%define name     va-systemimager
%define ver      1.2
%define rel      1
%define prefix   /usr

Summary: Software to install and update mass numbers of Linux systems
Name: %name
Version: %ver
Release: %rel
Copyright: GPL
Group: Applications/System
Source: http://download.sourceforge.net/systemimager/%{name}-%{ver}.tar.gz
BuildRoot: /tmp/%{name}-%{ver}-root
Packager: Michael Jennings <mej@valinux.com>
Docdir: %{prefix}/doc
URL: http://systemimager.org/
Requires: rsync >= 2.3.1, syslinux >= 1.48, dhcp = 2.0

%description
VA SystemImager is software that makes the installation of Linux to
masses of similar machines relatively easy.  It also makes software,
configuration, and operating system updates easy.  You can even update
from one release version to another!  VA SystemImager can even be used
for content management on web servers.  It is most useful in 
environments where you have large numbers of identical machines.  Some
typical environments include: Internet server farms, high performance
clusters, computer labs, or corporate desktop environments where all
workstations have the same basic hardware configuration.

%package client
Summary: VA SystemImager "Master Client" software
Group: Applications/System
Conflicts: %{name}
Requires: rsync >= 2.3.1, util-linux, sh-utils

%description client
This is the package you install on a VA SystemImager "master client".
It prepares the "master client" to have its image retrieved by an 
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

mkdir -p $RPM_BUILD_ROOT/etc/
install -m 644 tftpstuff/systemimager/systemimager.exclude $RPM_BUILD_ROOT/etc/
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
%doc CHANGE.LOG COPYING CREDITS FAQ-HOWTO README TODO VERSION afterburner
/var/*

/tftpboot/initrd.gz
/tftpboot/kernel

/tftpboot/pxelinux.cfg/*

/tftpboot/systemimager/grep
/tftpboot/systemimager/hosts
/tftpboot/systemimager/prepareclient
/tftpboot/systemimager/rsync
/tftpboot/systemimager/sed
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
%doc CHANGE.LOG COPYING CREDITS FAQ-HOWTO README TODO VERSION
/usr/sbin/updateclient
/usr/sbin/prepareclient
/etc/systemimager.exclude
