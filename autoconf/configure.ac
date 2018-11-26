#
# Brian Elliott Finley <brian@thefinleys.com>
# - Comment out a few things for now to get it to work.  Fix later (maybe)
# Olivier Lahaye <olivier.lahaye@cea.Fr>
# - Fix for newer systemimager.
#
#                                               -*- Autoconf -*-
# Process this file with autoconf to produce a configure script.

AC_PREREQ(2.59)
AC_INIT(SystemImager, 4.9.0, sisuite-devel@lists.sourceforge.net)
AC_CONFIG_AUX_DIR(autoconf)
#AC_CONFIG_SRCDIR([src/bc-1.06/acconfig.h])
#AC_CONFIG_HEADER([config.h])

# Checks for programs.
AC_PROG_INSTALL
AC_PROG_LN_S
AC_PROG_MAKE_SET

AC_PATH_PROG(RSYNC, rsync)
if test -z "$RSYNC" ; then
    SI_CHECK_FAIL(rsync,,,
        [*** 'rsync' missing, please install or fix your PATH ***])
fi

AC_PATH_PROG(DRACUT, dracut)
if test -z "$DRACUT"; then
    SI_CHECK_FAIL(mkcramfs,,,
        [*** 'dracut' not found, please install dracut tools or fix your PATH ***])
fi

AC_PATH_PROG(PERL, perl)
if test -z "$PERL"; then
    SI_CHECK_FAIL(perl,,,
        [*** 'perl' not found, please install perl interpreter or fix your PATH ***])
fi

AC_PATH_PROG(BASH, bash)
if test -z "$BASH"; then
    SI_CHECK_FAIL(bash,,,
        [*** 'bash' not found, please install bash shell or fix your PATH ***])
fi


# where is python
AC_PATH_PROG(python_exec,python2)
AC_PATH_PROG(python_exec,python)
AC_SUBST(PYTHON_PATH,$python_exec)

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
