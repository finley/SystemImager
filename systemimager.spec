%define name     systemimager
%define ver      0.24beta3
%define rel      1
%define prefix   /usr

Summary: Software to install and update mass numbers of Linux systems
Name: %name
Version: %ver
Release: %rel
Copyright: GPL
Group: Applications/System
Source: http://download.sourceforge.net/%{name}/%{name}-%{ver}.tar.gz
BuildRoot: /tmp/%{name}-%{ver}-root
Packager: Michael Jennings <mej@valinux.com>
Docdir: %{prefix}/doc
URL: http://systemimager.org/
Requires: syslinux tftp-hpa

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

install -m 755 afterburner functions $RPM_BUILD_ROOT/tftpboot/systemimager/
install -m 644 VERSION $RPM_BUILD_ROOT/tftpboot/systemimager/

%clean
rm -rf $RPM_BUILD_ROOT

%post
cd /tftpboot/systemimager && ./afterburner -q -n

%postun

%files
%defattr(-, root, root)
%doc CHANGE.LOG COPYING CREDITS FAQ-HOWTO README TODO
%{prefix}/*
/tftpboot/*
/var/*

%files client
%defattr(-, root, root)
%doc CHANGE.LOG COPYING CREDITS FAQ-HOWTO README TODO
%{prefix}/*
/tftpboot/*
/var/*
