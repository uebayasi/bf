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

#ifndef _KERNEL
#include <stdint.h>
#else
#include <sys/stdint.h>
#endif

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
 * Accessors.
 */

#define BF_OCV(name, N, p)	(*((const uint##N##_t *)(p) + name##_INDEX_##N))
#define BF_OV(name, N, p)	(*((uint##N##_t *)(p) + name##_INDEX_##N))
#define BF_CV(name, N, p)	name##_SWAP_##N(BF_OCV(name, N, p))
#define BF_V(name, N, p, v)	do { \
					BF_OV(name, N, p) = name##_SWAP_##N(v); \
				} while (0)
#define BF_V_AND(name, N, p, v)	do { \
					BF_OV(name, N, p) &= name##_SWAP_##N(v); \
				} while (0)
#define BF_V_OR(name, N, p, v)	do { \
					BF_OV(name, N, p) |= name##_SWAP_##N(v); \
				} while (0)
#define BF_V_XOR(name, N, p, v)	do { \
					BF_OV(name, N, p) ^= name##_SWAP_##N(v); \
				} while (0)

#define BF_READ(name, N, p)	((BF_CV(name, N, p) & name##_MASK_##N) >> name##_SHIFT_##N)
#define BF_ISSET(name, N, p)	((BF_CV(name, N, p) & name##_MASK_##N) != 0)
#define BF_CLEAR(name, N, p)	do { \
				    BF_V_AND(name, N, p, ~(name##_MASK_##N)); \
				} while (0)
#define BF_SET(name, N, p)	do { \
				    BF_V_OR(name, N, p, name##_MASK_##N); \
				} while (0)
#define BF_WRITE(name, N, p, v)	do { \
				    BF_V(name, N, p, \
					(BF_CV(name, N, p) & ~name##_MASK_##N) | \
					 ((v) << name##_SHIFT_##N)); \
				} while (0)

#endif /* __BF_H__ */
