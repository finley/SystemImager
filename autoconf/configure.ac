#                                               -*- Autoconf -*-
# Process this file with autoconf to produce a configure script.

AC_PREREQ(2.59)
AC_INIT(SystemImager, 3.5.2, sisuite-devel@lists.sf.net)
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
AC_PROG_INSTALL
AC_PROG_LN_S
AC_PROG_MAKE_SET
AC_PROG_RANLIB

# Checks for libraries.
# FIXME: Replace `main' with a function in `-lcrypt':
AC_CHECK_LIB([crypt], [main])
# FIXME: Replace `main' with a function in `-lm':
AC_CHECK_LIB([m], [main])
# FIXME: Replace `main' with a function in `-lncurses':
AC_CHECK_LIB([ncurses], [main])

# Checks for header files.
AC_FUNC_ALLOCA
AC_HEADER_DIRENT
AC_HEADER_STDC
AC_HEADER_MAJOR
AC_HEADER_SYS_WAIT
#AC_CHECK_HEADERS([argz.h arpa/inet.h fcntl.h inttypes.h langinfo.h libintl.h limits.h locale.h malloc.h memory.h mntent.h netdb.h netinet/in.h paths.h sgtty.h shadow.h stddef.h stdint.h stdlib.h string.h strings.h sys/file.h sys/ioctl.h sys/mount.h sys/param.h sys/socket.h sys/time.h sys/vfs.h syslog.h termios.h unistd.h utime.h utmp.h wchar.h wctype.h])

# Checks for typedefs, structures, and compiler characteristics.
AC_HEADER_STAT
AC_HEADER_STDBOOL
AC_C_CONST
AC_TYPE_UID_T
AC_C_INLINE
AC_TYPE_MODE_T
AC_FUNC_OBSTACK
AC_TYPE_OFF_T
AC_TYPE_PID_T
AC_TYPE_SIZE_T
AC_CHECK_MEMBERS([struct stat.st_blksize])
AC_STRUCT_ST_BLOCKS
AC_CHECK_MEMBERS([struct stat.st_rdev])
AC_HEADER_TIME
AC_STRUCT_TM
AC_STRUCT_TIMEZONE
AC_C_VOLATILE
AC_CHECK_TYPES([ptrdiff_t])

# Checks for library functions.
AC_FUNC_VPRINTF
AC_FUNC_CHOWN
AC_FUNC_CLOSEDIR_VOID
AM_GNU_GETTEXT
AC_FUNC_ERROR_AT_LINE
AC_REPLACE_FNMATCH
AC_FUNC_FORK
AC_FUNC_GETGROUPS
AC_FUNC_GETMNTENT
AC_FUNC_GETPGRP
AC_PROG_GCC_TRADITIONAL
AC_FUNC_LSTAT
AC_FUNC_LSTAT_FOLLOWS_SLASHED_SYMLINK
AC_FUNC_MALLOC
AC_FUNC_MBRTOWC
AC_FUNC_MEMCMP
AC_FUNC_MKTIME
AC_FUNC_MMAP
AC_FUNC_REALLOC
AC_FUNC_SELECT_ARGTYPES
AC_FUNC_SETPGRP
AC_FUNC_SETVBUF_REVERSED
AC_TYPE_SIGNAL
AC_FUNC_STAT
AC_FUNC_STRCOLL
AC_FUNC_STRERROR_R
AC_FUNC_STRFTIME
AC_FUNC_STRTOD
AC_FUNC_UTIME_NULL
AC_FUNC_WAIT3
#AC_CHECK_FUNCS([__argz_count __argz_next __argz_stringify alarm atexit bzero clock_gettime dup2 endgrent endpwent fchdir ftruncate getcwd getdelim gethostbyaddr gethostbyname gethostname getmntent getpagesize getspnam gettimeofday getusershell inet_ntoa isascii iswprint lchown memchr memmove mempcpy memset mkdir mkfifo munmap nl_langinfo pathconf pow putenv realpath regcomp rmdir rpmatch select setenv sethostname setlocale socket sqrt stime stpcpy strcasecmp strchr strcspn strdup strerror strncasecmp strndup strpbrk strrchr strspn strstr strtol strtoul strtoull strtoumax sysinfo tzset uname utime utmpname])

AC_CONFIG_FILES([config.inc])

AC_OUTPUT
