# This is a template for a single-package spec file
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

%package %{name}-client
Summary: Client installation for VA SystemImager
Group: Applications/System
Conflicts: %{name}

%description %{name}-client
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

###############################################################
# This part is completely unnecessary, but may be useful for
# making sure you don't have $RPM_BUILD_ROOT appearing in any
# config files.
###############################################################
cd $RPM_BUILD_ROOT
for i in `find . -type f -print` ; do
  if (grep $RPM_BUILD_ROOT $i >/dev/null 2>&1); then
    echo "ERROR:  $i contains the string $RPM_BUILD_ROOT"
  fi
done

###############################################################
# This part is also not needed but can be useful for building
# the %files lists in the sections below.
###############################################################
cd $RPM_BUILD_ROOT
find . -print | sed "s@$RPM_BUILD_ROOT%{prefix}@%""{prefix}@g"

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

%files %{name}-client
%defattr(-, root, root)
%doc CHANGE.LOG COPYING CREDITS FAQ-HOWTO README TODO
%{prefix}/*
/tftpboot/*
/var/*
