/*
 * CDE - Common Desktop Environment
 *
 * Copyright (c) 1993-2012, The Open Group. All rights reserved.
 *
 * These libraries and programs are free software; you can
 * redistribute them and/or modify them under the terms of the GNU
 * Lesser General Public License as published by the Free Software
 * Foundation; either version 2 of the License, or (at your option)
 * any later version.
 *
 * These libraries and programs are distributed in the hope that
 * they will be useful, but WITHOUT ANY WARRANTY; without even the
 * implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
 * PURPOSE. See the GNU Lesser General Public License for more
 * details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with these libraries and programs; if not, write
 * to the Free Software Foundation, Inc., 51 Franklin Street, Fifth
 * Floor, Boston, MA 02110-1301 USA
 */
/*
 * $XConsortium: macro.h /main/4 1996/07/18 14:59:08 drk $
 *
 * Copyright (c) 1993 HAL Computer Systems International, Ltd.
 * All rights reserved.  Unpublished -- rights reserved under
 * the Copyright Laws of the United States.  USE OF A COPYRIGHT
 * NOTICE IS PRECAUTIONARY ONLY AND DOES NOT IMPLY PUBLICATION
 * OR DISCLOSURE.
 * 
 * THIS SOFTWARE CONTAINS CONFIDENTIAL INFORMATION AND TRADE
 * SECRETS OF HAL COMPUTER SYSTEMS INTERNATIONAL, LTD.  USE,
 * DISCLOSURE, OR REPRODUCTION IS PROHIBITED WITHOUT THE
 * PRIOR EXPRESS WRITTEN PERMISSION OF HAL COMPUTER SYSTEMS
 * INTERNATIONAL, LTD.
 * 
 *                         RESTRICTED RIGHTS LEGEND
 * Use, duplication, or disclosure by the Government is subject
 * to the restrictions as set forth in subparagraph (c)(l)(ii)
 * of the Rights in Technical Data and Computer Software clause
 * at DFARS 252.227-7013.
 *
 *          HAL COMPUTER SYSTEMS INTERNATIONAL, LTD.
 *                  1315 Dell Avenue
 *                  Campbell, CA  95008
 * 
 */



#ifndef _macro_h
#define _macro_h 1

/* bit manipulation macros */
#define BIT_TEST(x, y)  ( ((x) & (y)) == (y) )
#define RESET_BIT(x, y)  x &= (~(y)) 
#define SET_BIT(x, y)    x |= (y)  
#define BITS_IN(TYPE)    ( 8*sizeof(TYPE) )

/* comparison macros */
#define INRANGE(x, low, high) ((x>=low) && (x<=high))  

#undef MIN
#undef MAX

#define MIN(x, y) (((x) < (y)) ? (x) : (y))
#define MAX(x, y) (((x) > (y)) ? (x) : (y))

#define TOBOOLEAN(x) ( ((x) == 1 ) ? true : false )
#define TOBIT(x) ( ((x) == true ) ? 1 : 0 )

/* secure XtNewString macro */
#define XtsNewString(str) \
    ((str) != NULL ? (char *)(memcpy(XtMalloc((unsigned)strlen(str) + 1), \
     str, (unsigned)strlen(str) + 1)) : NULL)

/* little endian to/from big endian swap macros. */

#define ORDER_SWAP(type, value)					\
{								\
   type tmp = value;						\
   int n = sizeof(type) - 1;					\
   for (int i = 0; i <= n; ++i)					\
      ((uint8_t *)&value)[i] = ((uint8_t *)&tmp)[n - i];	\
}

#define ORDER_SWAP_FLOAT(x) ORDER_SWAP(float, x)
#define ORDER_SWAP_LONG(x) ORDER_SWAP(long, x)
#define ORDER_SWAP_INT(x) ORDER_SWAP(int, x)
#define ORDER_SWAP_UINT(x) ORDER_SWAP(unsigned int, x)
#define ORDER_SWAP_USHORT(x) ORDER_SWAP(unsigned short, x)
#define ORDER_SWAP_MMDB_POS_T(x) ORDER_SWAP(mmdb_pos_t, x)
#endif
