/***********************************************************************
*                                                                      *
*               This software is part of the ast package               *
*          Copyright (c) 1982-2011 AT&T Intellectual Property          *
*                      and is licensed under the                       *
*                 Eclipse Public License, Version 1.0                  *
*                    by AT&T Intellectual Property                     *
*                                                                      *
*                A copy of the License is available at                 *
*          http://www.eclipse.org/org/documents/epl-v10.html           *
*         (with md5 checksum b35adb5213ca9657e911e9befb180842)         *
*                                                                      *
*              Information and Software Systems Research               *
*                            AT&T Research                             *
*                           Florham Park NJ                            *
*                                                                      *
*                  David Korn <dgk@research.att.com>                   *
*                                                                      *
***********************************************************************/
#pragma prototyped

#include	"defs.h"
#include	"name.h"
#include	"shtable.h"

/*
 * This is the list of invocation and set options
 * This list must be in in ascii sorted order
 */

const Shtable_t shtab_options[] =
{
	"allexport",			SH_ALLEXPORT,
	"bgnice",			SH_BGNICE,
	"braceexpand",			SH_BRACEEXPAND,
	"noclobber",			SH_NOCLOBBER,
	"emacs",			SH_EMACS,
	"errexit",			SH_ERREXIT,
	"noexec",			SH_NOEXEC,
	"noglob",			SH_NOGLOB,
	"globstar",			SH_GLOBSTARS,
	"gmacs",			SH_GMACS,
#if SHOPT_HISTEXPAND
	"histexpand",			SH_HISTEXPAND,
#endif
	"ignoreeof",			SH_IGNOREEOF,
	"interactive",			SH_INTERACTIVE|SH_COMMANDLINE,
	"keyword",			SH_KEYWORD,
	"letoctal",			SH_LETOCTAL,
	"nolog",			SH_NOLOG,
	"login_shell",			SH_LOGIN_SHELL|SH_COMMANDLINE,
	"markdirs",			SH_MARKDIRS,
	"monitor",			SH_MONITOR,
	"multiline",			SH_MULTILINE,
	"notify",			SH_NOTIFY,
	"pipefail",			SH_PIPEFAIL,
	"posix",			SH_POSIX,
	"privileged",			SH_PRIVILEGED,
#if SHOPT_PFSH
	"profile",			SH_PFSH|SH_COMMANDLINE,
#endif
	"rc",				SH_RC|SH_COMMANDLINE,
	"restricted",			SH_RESTRICTED,
	"showme",			SH_SHOWME,
	"trackall",			SH_TRACKALL,
	"nounset",			SH_NOUNSET,
	"verbose",			SH_VERBOSE,
	"vi",				SH_VI,
	"viraw",			SH_VIRAW,
	"xtrace",			SH_XTRACE,
	"",				0
};

const Shtable_t shtab_attributes[] =
{
	{"-Sshared",	NV_REF|NV_TAGGED},
	{"-nnameref",	NV_REF},
	{"-xexport",	NV_EXPORT},
	{"-rreadonly",	NV_RDONLY},
	{"-ttagged",	NV_TAGGED},
	{"-Aassociative array",	NV_ARRAY},
	{"-aindexed array",	NV_ARRAY},
	{"-llong",	(NV_DOUBLE|NV_LONG)},
	{"-Eexponential",(NV_DOUBLE|NV_EXPNOTE)},
	{"-Xhexfloat",	(NV_DOUBLE|NV_HEXFLOAT)},
	{"-Ffloat",	NV_DOUBLE},
	{"-llong",	(NV_INTEGER|NV_LONG)},
	{"-sshort",	(NV_INTEGER|NV_SHORT)},
	{"-uunsigned",	(NV_INTEGER|NV_UNSIGN)},
	{"-iinteger",	NV_INTEGER},
	{"-Hfilename",	NV_HOST},
	{"-bbinary",    NV_BINARY},
	{"-ltolower",	NV_UTOL},
	{"-utoupper",	NV_LTOU},
	{"-Zzerofill",	NV_ZFILL},
	{"-Lleftjust",	NV_LJUST},
	{"-Rrightjust",	NV_RJUST},
	{"++namespace",	NV_TABLE},
	{"",		0}
};
