/* Copyright (C) 2013 Free Software Foundation, Inc.
   This file is part of the GNU C Library.

   The GNU C Library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2.1 of the License, or (at your option) any later version.

   The GNU C Library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Lesser General Public License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with the GNU C Library; if not, see
   <http://www.gnu.org/licenses/>.  */

#include <sysdep.h>

	.text
ENTRY (__exit_thread)
        movq %rdi, %rsi		/* we will need it later, 
				%rsi is saved by kernel */
	mov %fs:0, %rdi
        addq $TID, %rdi		/* should be KTID, but
				they are at the same place anyway */
        DO_CALL (thr_exit, 1)
	/* It does return only for last thread of process */
	movq %rsi, %rdi /* use saved value */
	DO_CALL (exit, 1)
	/* Shouldn't get here.  */
	hlt
END   (__exit_thread)
