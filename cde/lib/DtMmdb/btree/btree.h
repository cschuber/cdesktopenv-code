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
 * $XConsortium: mmdb_btree.h /main/3 1996/06/11 17:14:37 cde-hal $
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


#ifndef _btree_h
#define _btree_h 1

#include "storage/unixf_storage.h"
#include "dynhash/data_t.h"

#if defined(SVR4) || defined(__linux__)

#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>

#else

#include <sys/file.h>
#include <sys/types.h>
#include <limits.h>

#endif

#include <cstdlib>
#include <lmdb.h>

#include "dstr/index_agent.h"


class btree : public index_agent
{

public:
   btree(const char* btree_file_name );
   ~btree();

   void clean();

   Boolean insert(data_t& w);
   Boolean remove(data_t& w);
   Boolean member(data_t& w);

   ostream& asciiOut(ostream& out);
   istream& asciiIn(istream& in);

protected:
   MDB_val key_DBT;
   MDB_dbi btree_DB;
   MDB_env *btree_env;

protected:
   void data_t_2_DBT(data_t& w);
   MDB_txn *txn_begin(unsigned int flags = 0);
   void txn_commit(MDB_txn *txn);
};

#endif
