#                                               -*- Autoconf -*-
# Process this file with autoconf to produce a configure script.

AC_PREREQ(2.59)
AC_INIT(SystemImager, 4.1.4, sisuite-devel@lists.sourceforge.net)
AC_CONFIG_AUX_DIR(autoconf)
#AC_CONFIG_SRCDIR([src/bc-1.06/acconfig.h])
#AC_CONFIG_HEADER([config.h])

# Checks for programs.
AC_PROG_CXX
AC_PROG_AWK
AC_PROG_YACC
AC_PROG_CC
AC_PROG_CPP
AC_PROG_LEX
case $LEX in
    :) SI_CHECK_FAIL(lex,flex,,You cannot build many components without the flex parser);;
esac
AC_PROG_INSTALL
AC_PROG_LN_S
AC_PROG_MAKE_SET
#AC_PROG_RANLIB

AC_PATH_PROG(RSYNC, rsync)
if test -z "$RSYNC" ; then
    SI_CHECK_FAIL(rsync,,,
        [*** 'rsync' missing, please install or fix your PATH ***])
fi

AC_PATH_PROG(MKCRAMFS, mkcramfs)
if test -z "$MKCRAMFS"; then
    AC_PATH_PROG(MKCRAMFS, mkfs.cramfs)
    if test -z "$MKCRAMFS"; then
        SI_CHECK_FAIL(mkcramfs,,,
            [*** 'mkcramfs' or 'mkfs.cramfs' not found, please install cramfs tools or fix your PATH ***])
    fi
fi

# Checks for libraries.
# FIXME: Replace `main' with a function in `-lcrypt':
# AC_CHECK_LIB([crypt], [main])
# FIXME: Replace `main' with a function in `-lm':
#AC_CHECK_LIB([m], [main])
# FIXME: Replace `main' with a function in `-lncurses':
# AC_CHECK_LIB([ncurses], [main])

# Checks for header files.
# AC_FUNC_ALLOCA
# AC_HEADER_DIRENT
# AC_HEADER_STDC
# AC_HEADER_MAJOR
# AC_HEADER_SYS_WAIT
#AC_CHECK_HEADERS([argz.h arpa/inet.h fcntl.h inttypes.h langinfo.h libintl.h limits.h locale.h malloc.h memory.h mntent.h netdb.h netinet/in.h paths.h sgtty.h shadow.h stddef.h stdint.h stdlib.h string.h strings.h sys/file.h sys/ioctl.h sys/mount.h sys/param.h sys/socket.h sys/time.h sys/vfs.h syslog.h termios.h unistd.h utime.h utmp.h wchar.h wctype.h])

# Checks for typedefs, structures, and compiler characteristics.
#AC_CHECK_FUNCS([__argz_count __argz_next __argz_stringify alarm atexit bzero clock_gettime dup2 endgrent endpwent fchdir ftruncate getcwd getdelim gethostbyaddr gethostbyname gethostname getmntent getpagesize getspnam gettimeofday getusershell inet_ntoa isascii iswprint lchown memchr memmove mempcpy memset mkdir mkfifo munmap nl_langinfo pathconf pow putenv realpath regcomp rmdir rpmatch select setenv sethostname setlocale socket sqrt stime stpcpy strcasecmp strchr strcspn strdup strerror strncasecmp strndup strpbrk strrchr strspn strstr strtol strtoul strtoull strtoumax sysinfo tzset uname utime utmpname])

#
#  All the above checks were generated with autoscan, adjust as required, but they 
#  seem fine for now
#

AC_PATH_PROG(gcc_exec,gcc)
AC_PATH_PROG(gxx_exec,g++)
AC_SUBST(GCC,$gcc_exec)
AC_SUBST(GXX,$gxx_exec)

# parted needs uuid
AC_CHECK_LIB([uuid], [uuid_generate], [have_uuid=yes], [
	SI_CHECK_FAIL(libuuid,e2fsprogs-devel)
	])

# parted needs readline 

AC_CHECK_LIB([ncurses],[keyok],[LIBS="-lncurses"],
	     [SI_CHECK_FAIL(ncurses,ncurses-devel)])

AC_CHECK_LIB([readline],[rl_initialize],[have_readline=yes], [
	     SI_CHECK_FAIL(readline,readline-devel)])

# where is python
AC_PATH_PROG(python_exec,python2)
AC_PATH_PROG(python_exec,python)
AC_SUBST(PYTHON_PATH,$python_exec)

# do we have devmapper
AC_CHECK_HEADERS([libdevmapper.h],[have_libdevmapper=yes])

AC_ARG_ENABLE([lvm],
    [  --enable-lvm            include lvm support [default=yes] if possible],
    [if test "x$enableval" = "xyes"; then
	if test "x$have_libdevmapper" = "xyes"; then
	    AC_SUBST(BUILD_LVM,1)
	else
	    SI_CHECK_FAIL(libdevmapper,libdevmapper-devel,,
	    [libdevmapper is required for lvm support.  You can build without
	     lvm support by passing the --disable-lvm flag])
	fi
     fi
    ],
    [if test "x$have_libdevmapper" = "xyes"; then
	AC_SUBST(BUILD_LVM,1)
     fi])


# do we have docbook, if not say know
AC_CHECK_PROG(found_docbook2man,[docbook2man],[yes])

AC_ARG_ENABLE([docs],
    [  --enable-docs           build sgml docs [default=yes if docbook2man is installed]],
    [if test "x$enableval" = "xyes"; then
        if test "x$found_docbook2man" = "xyes"; then
            AC_SUBST(BUILD_DOCS,1)
        else
                SI_CHECK_FAIL(docbook2man,docbook-utils,http://net-snmp.sourceforge.net/,
                You can't build SystemImager documentation without docbook.  
                You can build without docs by passing the --disable-docs flag)
        fi
    fi
    ],
    [if test "x$found_docbook2man" = "xyes"; then
            AC_SUBST(BUILD_DOCS,1)
     fi])

# for

AC_CONFIG_FILES([config.inc])

AC_OUTPUT
