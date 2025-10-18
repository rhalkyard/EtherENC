/*
 * syslog.h
 *
 * SysLog C header file
 *
 * (c) DoggySoft Ltd., 1996
 *
 */

#ifndef _syslog_h
#define _syslog_h

#include "kernel.h"

#define SYSLOG_MAX 1024

extern void syslog_logmessage(const char *logname, const char *text,
                              int priority);
extern int syslog_getloglevel(const char *logname);
extern void syslog_flushlog(const char *logname);
extern void syslog_setloglevel(const char *logname, int priority);
extern void syslog_logunstamped(const char *logname, const char *text,
                                int priority);
extern void syslog_indent(const char *logname);
extern void syslog_unindent(const char *logname);
extern void syslog_noindent(const char *logname);
extern const char *syslog_opensessionlog(const char *logname, int priority);
extern void syslog_closesessionlog(const char *logname);
extern void syslog_logdata(const char *logname, int priority,
                           const void *data, unsigned int size, int offset);
extern const char *syslog_readerrormessage(int errnum);
extern void syslog_logcomplete(const char *logname);
extern void syslog_irqmode(int flag);
extern void syslogf(const char *logname, int priority, const char *format,
                    ...);
extern _kernel_oserror *xsyslog_logmessage(const char *logname,
                                          const char *text, int priority);
extern _kernel_oserror *xsyslog_getloglevel(const char *logname,
                                            int *priority);
extern _kernel_oserror *xsyslog_flushlog(const char *logname);
extern _kernel_oserror *xsyslog_setloglevel(const char *logname,
                                            int priority);
extern _kernel_oserror *xsyslog_logunstamped(const char *logname,
                                             const char *text, int priority);
extern _kernel_oserror *xsyslog_indent(const char *logname);
extern _kernel_oserror *xsyslog_unindent(const char *logname);
extern _kernel_oserror *xsyslog_noindent(const char *logname);
extern _kernel_oserror *xsyslog_opensessionlog(const char *logname,
                                               int priority, char **session);
extern _kernel_oserror *xsyslog_closesessionlog(const char *logname);
extern _kernel_oserror *xsyslog_logdata(const char *logname, int priority,
                                        const void *data, unsigned int size,
                                        int offset);
extern _kernel_oserror *xsyslog_readerrormessage(int errnum, char **message);
extern _kernel_oserror *xsyslog_logcomplete(const char *logname);
extern _kernel_oserror *xsyslog_irqmode(int flag);
extern _kernel_oserror *xsyslogf(const char *logname, int priority,
                                 const char *format, ...);

#endif
