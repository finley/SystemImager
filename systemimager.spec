%define name     systemimager
%define ver      2.1.2
%define rel      1
%define prefix   /usr

Summary: Software that automates Linux installs, software distribution, and production deployment.
Name: %name
Version: %ver
Release: %rel
Copyright: GPL
Group: Applications/System
Source: http://download.sourceforge.net/systemimager/%{name}-%{ver}.tar.gz
BuildRoot: /tmp/%{name}-%{ver}-root
BuildArchitectures: noarch
Packager: dann frazier <dannf@dannf.org>
Docdir: %{prefix}/doc
URL: http://systemimager.org/
Distribution: System Installation Suite
Requires: rsync >= 2.4.6, syslinux >= 1.48, libappconfig-perl, dosfstools, /usr/bin/perl
AutoReqProv: no

%description
This is bogus and not used anywhere

%package server
Summary: Software that automates Linux installs, software distribution, and production deployment.
Version: %ver
Release: %rel
Copyright: GPL
Group: Applications/System
BuildRoot: /tmp/%{name}-%{ver}-root
Packager: dann frazier <dannf@dannf.org>
Docdir: %{prefix}/doc
URL: http://systemimager.org/
Distribution: System Installation Suite
Requires: rsync >= 2.4.6, systemimager-common, libappconfig-perl, dosfstools, /sbin/chkconfig, /sbin/service, /usr/bin/perl
AutoReqProv: no

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

%package common
Summary: Software that automates Linux installs, software distribution, and production deployment.
Version: %ver
Release: %rel
Copyright: GPL
Group: Applications/System
BuildRoot: /tmp/%{name}-%{ver}-root
Packager: dann frazier <dannf@dannf.org>
Docdir: %{prefix}/doc
URL: http://systemimager.org/
Distribution: System Installation Suite
Requires: /usr/bin/perl
AutoReqProv: no

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

%package %{_build_arch}boot
Summary: Software that automates Linux installs, software distribution, and production deployment.
Version: %ver
Release: %rel
Copyright: GPL
Group: Applications/System
BuildRoot: /tmp/%{name}-%{ver}-root
Packager: dann frazier <dannf@dannf.org>
Docdir: %{prefix}/doc
URL: http://systemimager.org/
Distribution: System Installation Suite
Requires: systemimager-server
AutoReqProv: no

%description %{_build_arch}boot
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

%package client
Summary: Software that automates Linux installs, software distribution, and production deployment.
Version: %ver
Release: %rel
Copyright: GPL
Group: Applications/System
BuildRoot: /tmp/%{name}-%{ver}-root
Packager: dann frazier <dannf@dannf.org>
Docdir: %{prefix}/doc
URL: http://systemimager.org/
Distribution: System Installation Suite
Requires: systemimager-common, systemconfigurator, libappconfig-perl, rsync >= 2.4.6, /usr/bin/perl, mtools (specifically minfo.  Thought I'd let you do this right, Sean. -BEF-)
AutoReqProv: no

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

%changelog
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
%setup

%build
cd $RPM_BUILD_DIR/%{name}-%{version}/
make all

%install
cd $RPM_BUILD_DIR/%{name}-%{version}/
make install_server_all DESTDIR=/tmp/%{name}-%{ver}-root PREFIX=%prefix
make install_client_all DESTDIR=/tmp/%{name}-%{ver}-root PREFIX=%prefix

%clean
cd $RPM_BUILD_DIR/%{name}-%{version}/
make distclean
rm -rf $RPM_BUILD_ROOT

%post server
# First we check for rsync service under xinetd and get rid of it
# also note the use of DURING_INSTALL, which is used to
# support using this package in Image building without affecting
# processes running on the parrent
if [[ -a /etc/xinetd.d/rsync ]]; then
    mv /etc/xinetd.d/rsync /etc/xinetd.d/rsync.presis~
    `pidof xinetd > /dev/null`
    if [[ $? == 0 ]]; then
        if [ -z $DURING_INSTALL ]; then
            /sbin/service xinetd restart
        fi
    fi
fi

/sbin/chkconfig --add systemimager

if [ -z $DURING_INSTALL ]; then
    /sbin/service systemimager start
fi

%preun server
/sbin/service systemimager stop
/sbin/chkconfig --del systemimager

if [[ -a /etc/xinetd.d/rsync.presis~ ]]; then
    mv /etc/xinetd.d/rsync.presis~ /etc/xinetd.d/rsync
    `pidof xinetd > /dev/null`
    if [[ $? == 0 ]]; then
        /sbin/service xinetd restart
    fi
fi


%files common
%defattr(-, root, root)
%prefix/bin/lsimage
%prefix/share/man/man8/lsimage*
%dir %prefix/lib/systemimager
%prefix/lib/systemimager/perl/SystemImager/Common.pm

%files %{_build_arch}boot
%defattr(-, root, root)
%dir %prefix/share/systemimager/%{_build_arch}-boot
%prefix/share/systemimager/%{_build_arch}-boot/*

%files server
%defattr(-, root, root)
%doc CHANGE.LOG COPYING CREDITS README TODO VERSION
%doc doc/manual/systemimager* doc/manual/html doc/manual/examples
%doc doc/autoinstall* doc/local.cfg
%dir /var/log/systemimager
%dir /var/lib/systemimager/images
%dir /var/lib/systemimager/scripts
%dir /etc/systemimager
%config /etc/systemimager/rsyncd.conf
%config /etc/systemimager/server.conf
/etc/init.d/systemimager
/var/lib/systemimager/images/*
%prefix/sbin/addclients
%prefix/sbin/cpimage
%prefix/sbin/getimage
%prefix/sbin/mkautoinstallscript
%prefix/sbin/mkbootserver
%prefix/sbin/mkdhcpserver
%prefix/sbin/mkdhcpstatic
%prefix/sbin/mvimage
%prefix/sbin/pushupdate
%prefix/sbin/rmimage
%prefix/bin/mkautoinstall*
%prefix/lib/systemimager/perl/SystemImager/Server.pm
%prefix/share/man/man5/systemimager*
%prefix/share/man/man8/addclients*
%prefix/share/man/man8/cpimage*
%prefix/share/man/man8/getimage*
%prefix/share/man/man8/mk*
%prefix/share/man/man8/mvimage*
%prefix/share/man/man8/rmimage*

%files client
%defattr(-, root, root)
%doc CHANGE.LOG COPYING CREDITS README TODO VERSION
%dir /etc/systemimager
%config /etc/systemimager/updateclient.local.exclude
%config /etc/systemimager/client.conf
# %prefix/lib/systemimager/perl/SystemImager/Client.pm
%prefix/sbin/updateclient
%prefix/sbin/prepareclient
%prefix/share/man/man8/updateclient*
%prefix/share/man/man8/prepareclient*

