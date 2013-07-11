/*
 * Copyright (c) 2013 Masao Uebayashi <uebayasi@tombi.co.jp>
 *
 * Permission to use, copy, modify, and distribute this software for any
 * purpose with or without fee is hereby granted, provided that the above
 * copyright notice and this permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 * WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 * ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 * WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 * ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 * OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 */

/*
 * bf - Portable bit-field operation definition
 */

#ifndef __BF_H__
#define __BF_H__

#include <stdint.h>

/*
 * Base definitions
 */

#ifndef NBBY
#define NBBY			8
#define NBBYSTR			"8"
#endif

/* Base exact-width unsigned integer types. */
#define __U1			uint8_t
#define __U2			uint16_t
#define __U4			uint32_t
#define __U8			uint64_t
#define __U1C(x)		UINT8_C(x)
#define __U2C(x)		UINT16_C(x)
#define __U4C(x)		UINT32_C(x)
#define __U8C(x)		UINT64_C(x)
#define __U1X			UINT8_MAX
#define __U2X			UINT16_MAX
#define __U4X			UINT32_MAX
#define __U8X			UINT64_MAX

/* _BfMask*N()'s return an exact-width unsigned integer value. */
#define	_BfMask0N(N, s)		((__U##N##C(1) << (s)) - 1)
#define	_BfMaskN(N, s)		(((s) >= (N * NBBY)) ? \
				 __U##N##X : _BfMask0N(N, (s)))
/* Mask with width (range mask). */
#define _BfMaskWN(N, s, w)	(_BfMaskN(N, (s) + (w)) & ~_BfMaskN(N, (s)))

/* Mask shift-out/shift-in. */
#define _BfMaskO(b, m, s)	(((b) & (m)) >> (s))
#define _BfMaskI(v, m, s)	(((v) << (s)) & (m))

/* Mask ops (isset, clear, set), here "set" == "|" (or). */
#define _BfIsSet(m)		((m) != 0)
#define _BfStmt(s)		do { s; } while (0)
#define _BfClr(b, m)		_BfStmt((b) &= ~(m))
#define _BfSet(b, m)		_BfStmt((b) |= (m))

/* Bit-field write op is actually clear + set. */
#define _BfClrSet(b, m, n)	_BfStmt(_BfClr((b), (m)); _BfSet((b), (n)))

/*
 * Byte order
 */

#define _BF_E_L			0
#define _BF_E_B			1

/* Configuration; must be solved at installation time, not compilation time. */
/* XXX defined(BYTE_ORDER) && defined(BIG_ENDIAN) && defined(LITTLE_ENDIAN) */
#if 1
#else
#error BYTE_ORDER must be set to either BIG_ENDIAN or LITTLE_ENDIAN!
#endif

/* Determine host endian. */
/* XXX BYTE_ORDER == LITTLE_ENDIAN */
#if 1
#define _BF_E_H			_BF_E_L
#else
#define _BF_E_H			_BF_E_B
#endif

/* Self-contained implementation. */
/* XXX Replace with host-provided functions. */
#define _BfSwap1(x)	(x)
#define _BfSwap2(x)	(0 \
			 | ((x >>  8) & __U2C(0x00ff)) \
			 | ((x <<  8) & __U2C(0xff00)))
#define _BfSwap4(x)	(0 \
			 | ((x >> 24) & __U4C(0x000000ff)) \
			 | ((x >>  8) & __U4C(0x0000ff00)) \
			 | ((x <<  8) & __U4C(0x00ff0000)) \
			 | ((x << 24) & __U4C(0xff000000)))
#define _BfSwap8(x)	(0 \
			 | ((x >> 56) & __U8C(0x00000000000000ff)) \
			 | ((x >> 40) & __U8C(0x000000000000ff00)) \
			 | ((x >> 24) & __U8C(0x0000000000ff0000)) \
			 | ((x >>  8) & __U8C(0x00000000ff000000)) \
			 | ((x <<  8) & __U8C(0x000000ff00000000)) \
			 | ((x << 24) & __U8C(0x0000ff0000000000)) \
			 | ((x << 40) & __U8C(0x00ff000000000000)) \
			 | ((x << 56) & __U8C(0xff00000000000000)))

#if (_BF_E_H == _BF_E_B)
#define _BfSwapLe1(x)	_BfSwap1(x)
#define _BfSwapLe2(x)	_BfSwap2(x)
#define _BfSwapLe4(x)	_BfSwap4(x)
#define _BfSwapLe8(x)	_BfSwap8(x)
#define _BfSwapBe1(x)	(x)
#define _BfSwapBe2(x)	(x)
#define _BfSwapBe4(x)	(x)
#define _BfSwapBe8(x)	(x)
#else
#define _BfSwapLe1(x)	(x)
#define _BfSwapLe2(x)	(x)
#define _BfSwapLe4(x)	(x)
#define _BfSwapLe8(x)	(x)
#define _BfSwapBe1(x)	_BfSwap1(x)
#define _BfSwapBe2(x)	_BfSwap2(x)
#define _BfSwapBe4(x)	_BfSwap4(x)
#define _BfSwapBe8(x)	_BfSwap8(x)
#endif

/*
 * Alignment.
 */

/* (o & -o) is right most bit set. */
#define _BfAlignRMB(o)	((o) & -(o))
#define _BfAlign0(o)	((o) == 0 ? (1 << 30)/*INT_MAX*/ : _BfAlignRMB(o))
/* 0 - unaligned, 1 - 8-bit aligned, 2: 16-bit aligned, ... */
#define _BfAlign(o)	(_BfAlign0(o) >> 3)

#endif /* __BF_H__ */
