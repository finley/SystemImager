%define name     systemimager
%define ver      0.24beta3
%define rel      1
%define prefix   /usr

Summary: System Replication Tool
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
VA SystemImager is a software package designed to make it easy for
system administrators to install and update large numbers of
like machines running Linux.

%package client
Summary: Client installation for VA SystemImager
Group: Applications/System
Conflicts: %{name}

%description client
This is the package you install on a VA SystemImager client node.

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

install -m 755 afterburner $RPM_BUILD_ROOT/tftpboot/systemimager/

%clean
rm -rf $RPM_BUILD_ROOT

%post
/tftpboot/systemimager/afterburner -q -n

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
