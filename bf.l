%{
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
 * bf - Portable bit-field operation
 */

#include <assert.h>
#include <stdlib.h>
#include <string.h>
#include "queue.h"

#ifndef YY_PROTO
#define YY_PROTO(x) x
#endif

#define MINASIZ (1 * NBBY)
#define MAXASIZ (8 * NBBY)

long long strtonum(const char *, long long, long long, const char **);

struct prefix;
struct field;
struct enumer;

/* Contiguous mask bits between S-th bit and E-th bit. */
struct mask {
	int S, E;
};

struct num {
	int v;
};

SIMPLEQ_HEAD(prefixes, prefix);
SIMPLEQ_HEAD(fields, field);
SIMPLEQ_HEAD(enumers, enumer);
struct prefix {
	SIMPLEQ_ENTRY(prefix) entry;
	const char *name;
	int size;
	struct fields fields;
};
struct field {
	SIMPLEQ_ENTRY(field) entry;
	const char *name;
	int offset;
	int width;
	struct mask mask;
	struct enumers enumers;
};
struct enumer {
	SIMPLEQ_ENTRY(enumer) entry;
	const char *name;
	struct num num;
};
enum endian {
	LITTLE = 1,
	BIG = 2,
};

static void prefix_start(void);
static void prefix_stop(void);
static void field_start(void);
static void field_stop(void);
static void enumer_start(void);
static void enumer_stop(void);

struct global {
	int asiz;
	int verbose;
	int full;
	struct prefixes prefixes;
	struct prefix *cur_prefix, *prev_prefix;
	struct field *cur_field, *prev_field;
	struct enumer *cur_enumer, *prev_enumer;
	enum endian target;
} global_storage = {
	.prefixes = SIMPLEQ_HEAD_INITIALIZER(global_storage.prefixes),
}, *global = &global_storage;

static void yyunput YY_PROTO(( int c, char *buf_ptr )) __unused;
static int input(void) __unused;
%}

comment		[#]
kw_prefix	(PREFIX|prefix)
kw_size		(SIZE|size)
kw_endian	(ENDIAN|endian)
id		[A-Za-z][A-Za-z0-9_]*
number		[0-9][0-9]*
endian		[BbLl][A-Za-z]*
char		.
blank		[ \t]
nl		[\n]

%s COMMENT
%s PREFIX
%s ENDIAN
%s SIZE
%s FIELD
%s FIELD_ENUM

%%

<INITIAL>{comment} {
	BEGIN COMMENT;
}
<INITIAL>{kw_prefix} {
	prefix_stop();
	prefix_start();
	BEGIN PREFIX;
}
<INITIAL>{kw_endian} {
	BEGIN ENDIAN;
}
<INITIAL>{kw_size} {
	BEGIN SIZE;
}
<INITIAL>^{number} {
	BEGIN FIELD;
	field_start();
}
<INITIAL>{blank} {
}
<INITIAL>{char} {
}
<INITIAL>{nl} {
}

<COMMENT>{blank} {
}
<COMMENT>{char} {
}
<COMMENT>{nl} {
	BEGIN INITIAL;
}

<PREFIX>{blank} {
}
<PREFIX>{id} {
	assert(global->cur_prefix->name == NULL);
	global->cur_prefix->name = strdup(yytext);
	BEGIN INITIAL;
}
<PREFIX>{nl} {
	assert(global->cur_prefix->name == NULL);
	BEGIN INITIAL;
}

<ENDIAN>{blank} {
}
<ENDIAN>{endian} {
	switch (yytext[0]) {
	case 'B':
	case 'b':
		global->target = BIG;
		break;
	case 'L':
	case 'l':
		global->target = LITTLE;
		break;
	}
	BEGIN INITIAL;
}

<SIZE>{blank} {
}
<SIZE>{number} {
	assert(global->cur_prefix->size == 0);
	global->cur_prefix->size = strtonum(yytext, 0, 1 << 30, NULL);
	assert(global->cur_field == NULL);
	BEGIN INITIAL;
}

<FIELD>{id} {
	global->cur_field->name = strdup(yytext);
}
<FIELD>{number} {
	if (global->cur_field->name != NULL) {
		BEGIN FIELD_ENUM;
		enumer_start();
		global->cur_enumer->num.v = strtonum(yytext, 0, 1 << 30, NULL);
	} else {
		fprintf(stderr, "field has no name yet!\n");
		exit(1);
	}
}
<FIELD>{blank} {
}
<FIELD>{char} {
}
<FIELD>{nl} {
	field_stop();
	BEGIN INITIAL;
}

<FIELD_ENUM>{id} {
	assert(global->cur_enumer != NULL);
	assert(global->cur_enumer->num.v != -1);
	global->cur_enumer->name = strdup(yytext);
	enumer_stop();
	BEGIN FIELD;
}
<FIELD_ENUM>{blank} {
}
<FIELD_ENUM>{char} {
}

%%

#include <stdio.h>
#include <string.h>
#include <unistd.h>

#ifndef NBBY
#define NBBY		8
#endif
#ifndef NBBYSTR
#define NBBYSTR		"8"
#endif

#ifndef MAX
#define MAX(a, b)	(((a) > (b)) ? (a) : (b))
#endif
#ifndef MIN
#define MIN(a, b)	(((a) < (b)) ? (a) : (b))
#endif

static void setup(int, char *[]);
static void start(void);
static void loop(void);
static void stop(void);
static void dump(struct prefix *);

static struct prefix *prefix_alloc(void);
static void prefix_free(struct prefix *);
static struct field *field_alloc(void);
static void field_free(struct field *);
static void field_print(const struct field *);
static struct enumer *enumer_alloc(void);
static void enumer_free(struct enumer *);

int
main(int argc, char *argv[])
{
	setup(argc, argv);
	start();
	loop();
	stop();
	return 0;
}

static void
setup(int argc, char *argv[])
{
	int c;
	extern char *optarg;

	while ((c = getopt(argc, argv, "a:fv")) != -1) {
		int asiz;
		switch (c) {
		case 'a':
			asiz = strtonum(optarg, MINASIZ, MAXASIZ, NULL);
			switch (asiz) {
			case MINASIZ:
			case 2*MINASIZ:
			case 4*MINASIZ:
			case MAXASIZ:
				global->asiz |= asiz;
				break;
			default:
				fprintf(stderr, "invalid access size (%d)\n",
				    asiz);
				exit(1);
				/* NOTREACHED */
			}
			break;
		case 'f':
			global->full = 1;
			break;
		case 'v':
			global->verbose = 1;
			break;
		}
	}
}

static void
start(void)
{
	if (global->full) {
		printf("#include <bf.h>\n");
	}
}

static void
loop(void)
{
	yylex();
}

static void
stop(void)
{
	prefix_stop();
}

static void
prefix_start(void)
{
	assert(global->cur_prefix == NULL);
	global->cur_prefix = prefix_alloc();
}

static void
prefix_stop(void)
{
	if (global->cur_prefix != NULL) {
		if (global->verbose)
			dump(global->cur_prefix);
		prefix_free(global->cur_prefix);
		global->prev_field = NULL;
		global->cur_prefix = NULL;
	}
	assert(global->cur_prefix == NULL);
}

static void
field_start(void)
{
	if (global->target == 0) {
		fprintf(stderr, "target endian not set\n");
		exit(1);
	}
	assert(global->cur_field == NULL);
	global->cur_field = field_alloc();
	global->cur_field->width = strtonum(yytext, 0, 1 << 30, NULL);
}

static void
field_stop(void)
{
	struct field *cur = global->cur_field, *prev = global->prev_field;

	/* Offset is known now.  Fill mask too. */
	cur->mask.S = cur->offset = prev ? prev->mask.E : 0;
	cur->mask.E = cur->mask.S + cur->width;

	if (cur->mask.E > global->cur_prefix->size) {
		fprintf(stderr, "%s: field %s exceeding size "
		    "(offset=%d width=%d size=%d)\n",
		    __func__, cur->name,
		    cur->offset, cur->width, global->cur_prefix->size);
		exit(1);
	}
	assert(cur->mask.E <= global->cur_prefix->size);
	/* Remember prev for future. */
	global->prev_field = global->cur_field;
	global->cur_field = NULL;
	/* Be done. */
	field_print(cur);
}

static void
enumer_start(void)
{
	assert(global->cur_enumer == NULL);
	assert(global->prev_enumer == NULL);
	global->cur_enumer = enumer_alloc();
}

static void
enumer_stop(void)
{
	SIMPLEQ_INSERT_TAIL(&global->cur_field->enumers, global->cur_enumer,
	    entry);
	global->cur_enumer = NULL;
}

static struct prefix *
prefix_alloc(void)
{
	struct prefix *new_prefix;

	new_prefix = calloc(sizeof(*new_prefix), 1);
	SIMPLEQ_INSERT_TAIL(&global->prefixes, new_prefix, entry);
	SIMPLEQ_INIT(&new_prefix->fields);
	return new_prefix;
}

static void
prefix_free(struct prefix *prefix)
{
	struct field *field;

	while ((field = SIMPLEQ_FIRST(&prefix->fields)) != NULL) {
		SIMPLEQ_REMOVE(&prefix->fields, field, field, entry);
		field_free(field);
	}
	SIMPLEQ_REMOVE(&global->prefixes, prefix, prefix, entry);
	free(prefix);
}

static struct field *
field_alloc(void)
{
	struct field *new_field;

	new_field = calloc(sizeof(*new_field), 1);
	SIMPLEQ_INSERT_TAIL(&global->cur_prefix->fields, new_field, entry);
	SIMPLEQ_INIT(&new_field->enumers);
	return new_field;
}

static void
field_free(struct field *field)
{
	struct enumer *enumer;

	while ((enumer = SIMPLEQ_FIRST(&field->enumers)) != NULL) {
		SIMPLEQ_REMOVE(&field->enumers, enumer, enumer, entry);
		enumer_free(enumer);
	}
	free(field);
}

static struct enumer *
enumer_alloc(void)
{
	struct enumer *new_enumer;

	new_enumer = calloc(sizeof(*new_enumer), 1);
	new_enumer->num.v = -1;
	return new_enumer;
}

static void
enumer_free(struct enumer *enumer)
{
	free(enumer);
}

/*
 * Print bit-field accessors.
 */

/* Value represented as byte vector. */
struct vec {
	uint8_t vs[MAXASIZ / NBBY];
};

/* Value with shift. */
struct sv {
	int shift;
	union {
		/* Real value is (mask << shift). */
		struct mask mask;
		/* Real value is (num.v << shift). */
		struct num num;
		/* Real value is ((vec[0] | vec[(1] << 8) | ...) << shift). */
		struct vec vec;
	} u;
};

/* Value with access-size and index. */
struct aiv {
	/* Real value is, (v << shift + (asiz * aidx)). */
	int asiz;
	int aidx;
	struct sv sv;
};

/* Access. */
struct accs {
	int align;
	int minasiz;
	struct aiv aivs[4];
};

/* 8/16/32/64 -> 0/1/2/3 */
#define asiz2idx(a) \
    (((((a) >> 3) & 0xc) ? 0x2 : 0) | ((((a) >> 3) & 0x6) ? 0x1 : 0))

static void analyze_accs(const struct mask *, struct accs *);
static int calc_access_align(const struct mask *);
static int calc_access_size(const int, const struct mask *);
static int calc_access_shift(const int, const int, const struct mask *);
static void print_accs(const char *, struct accs *, const struct enumers *);
static void print_mask(const char *, const struct aiv *, const int);
static void print_enumer(const char *, const struct aiv *,
    const struct enumer *);
static void print_vec(char *, const size_t, const struct aiv *,
    void (*)(const struct aiv *, struct aiv *));
static void mask2vec(const struct aiv *, struct aiv *);
static void num2vec(const struct aiv *, struct aiv *);

static void
field_print(const struct field *field)
{
	struct accs accs_storage, *accs = &accs_storage;
	analyze_accs(&field->mask, accs);

	const char *fmt = "/* field: name=%s offset=%d width=%d */\n";
	static int once = 0;
	if (field->name == NULL) {
		/* Unused bits (pads). */
		if (global->verbose) {
			if (once++ != 0)
				putchar('\n');
			printf(fmt, "(unused)", field->offset, field->width);
		}
	} else {
		if (once++ != 0)
			putchar('\n');
		if (global->verbose) {
			printf(fmt, field->name, field->offset, field->width);
		}
		const char * const name = field->name;
		char prefixstr[256];
		snprintf(prefixstr, sizeof(prefixstr), "%s%s%s",
		    global->cur_prefix->name ? global->cur_prefix->name : "",
		    global->cur_prefix->name ? "_" : "", name);
		print_accs(prefixstr, accs, &field->enumers);
	}
}

static void
analyze_accs(const struct mask *mask, struct accs *accs)
{
	/* Check alignment.  Aligned access is simpler (only byte-swaps). */
	accs->align = calc_access_align(mask);

	/* Minimal register access width == alignment size. */
	accs->minasiz = calc_access_size(accs->align, mask);

	int asiz;
	for (asiz = accs->minasiz; asiz <= MAXASIZ; asiz <<= 1) {
		struct aiv *aiv = &accs->aivs[asiz2idx(asiz)];
		aiv->asiz = asiz;
		aiv->aidx = mask->S / asiz;
		aiv->sv.shift = calc_access_shift(accs->align, asiz, mask);
		aiv->sv.u.mask = *mask;
	}
}

/* Right most bit set. */
#define _BfAlignRMB(o)	((o) & -(o))
#define _BfAlign(o)	((o) == 0 ? (1 << 30)/*INT_MAX*/ : _BfAlignRMB(o))

static int
calc_access_align(const struct mask *mask)
{
	/*
	 * Calc alignment by checking the right most bit.
	 */
	const int align = MIN(_BfAlign(mask->S), _BfAlign(mask->E));

	/*
	 * Ignore alignment more than 64-bit.
	 */
	return MIN(align, MAXASIZ);
}

static int
calc_access_size(const int align, const struct mask *mask)
{
	if (align > 0) {
		return align;
	} else {
		/*
		 * Determine the (minimal) access size.
		 *
		 * If a 2-bit maak crosses no 8-bit boundary (0x18 for
		 * example), it can be accessed by 8-bit.  If it crosses
		 * 8-bit boundary (0x0180 for example), 16-bit access is
		 * needed.  Find the biggest boundary (8/16/32/64 in
		 * order), then it is the minimal access size!
		 */

		/* 8-bit indexes. */
		int i = mask->S / MINASIZ;
		int j = (mask->E - 1) / MINASIZ;

		int asiz = MINASIZ;

		while (i > 0 && j > 0) {
			/*
			 * (S, E) have the same index
			 * -> not crossing boundary.
			 */
			if (i == j)
				break;
			/* Larger alignment next. */
			asiz <<= 1;
			i >>= 1;
			j >>= 1;
		}

		/* Max is 64-bit access. */
		return MIN(asiz, MAXASIZ);
	}
}

static int
calc_access_shift(const int align, const int asiz, const struct mask *mask)
{
	/* Shift in register. */
	return
	    /* Aligned access - no shift needed. */
	    (asiz == align) ? 0 :
	    /* Unaligned access. */
	    (global->target == BIG) ?
		/*
		 * Big endian .bf definition is in real memory, not view.
		 * Calc shift from right.
		 */
		((mask->E % asiz) == 0 ? 0 : (asiz - (mask->E % asiz))) :
		/*
		 * Little endian .bf definition is in little endian view.
		 * Simply calc shift from left.
		 */
		(mask->S % asiz);
}

static void
print_accs(const char *prefixstr, struct accs *accs,
    const struct enumers *enumers)
{
	/* Provide all access widths >minasiz. */
	int asiz;
	for (asiz = accs->minasiz; asiz <= MAXASIZ; asiz <<= 1) {
		/* Follow explicit access sizes when specified. */
		if (global->asiz != 0 && (global->asiz & asiz) == 0)
			continue;
		struct aiv *aiv = &accs->aivs[asiz2idx(asiz)];
		print_mask(prefixstr, aiv, accs->align);
		struct enumer *enumer;
		SIMPLEQ_FOREACH(enumer, enumers, entry) {
			print_enumer(prefixstr, aiv, enumer);
		}
	}
}

/* Print accessors. */
static void
print_mask(const char *prefixstr, const struct aiv *aiv, const int align)
{
#define P prefixstr
#define A aiv->asiz
	printf("#define %s_INDEX_%d %d\n", P, A, aiv->aidx);

	if (global->full) {
		printf("#define %s_OCV_%d(p) "
		    "(*((const uint%d_t *)(p) + %s_INDEX_%d))\n",
		    P, A, A, P, A);
		printf("#define %s_OV_%d(p) "
		    "(*((uint%d_t *)(p) + %s_INDEX_%d))\n",
		    P, A, A, P, A);
	}

	char swapstr[16];
	snprintf(swapstr, sizeof(swapstr), "_BfSwap%s%d",
	    (global->target == LITTLE) ? "Le" : "Be", A >> 3);
	printf("#define %s_SWAP_%d %s\n", P, A, swapstr);

	if (global->full) {
		printf("#define %s_CV_%d(p) (%s_SWAP_%d(%s_OCV_%d(p)))\n",
		    P, A, P, A, P, A);
		printf("#define %s_V_%d(p, v) do "
		    "{ %s_OV_%d(p) = %s_SWAP_%d(v); } while (0)\n",
		    P, A, P, A, P, A);
	}

	char maskstr[32];
	print_vec(maskstr, sizeof(maskstr), aiv, mask2vec);

	const struct mask *mask = &aiv->sv.u.mask;
	printf("#define %s_SHIFT_%d %d\n",
	    P, A, aiv->sv.shift);
	printf("#define %s_WIDTH_%d %d\n",
	    P, A, mask->E - mask->S);
	printf("#define %s_MASK_%d UINT%d_C(0x%s)\n",
	    P, A, A, maskstr);

	if (global->full) {
		static char readstr[256];
		static char issetstr[256];
		static char clearstr[256];
		static char setstr[256];
		static char writestr[256];
		if (align == aiv->asiz) {
			snprintf(readstr, sizeof(readstr),
			    "%s_CV_%d(p)", P, A);
			snprintf(issetstr, sizeof(readstr),
			    "(%s_CV_%d(p) != 0)", P, A);
			snprintf(clearstr, sizeof(clearstr),
			    "do { %s_V_%d(p, 0); } while (0)", P, A);
			snprintf(setstr, sizeof(setstr),
			    "do { "
			        "%s_V_%d(p, (%s_CV_%d | ~%s_CV_%d(p))); "
			    "} while (0)",
			    P, A, P, A, P, A);
			snprintf(writestr, sizeof(writestr),
			    "do { %s_V_%d(p, v); } while (0)",
			    P, A);
		} else {
			snprintf(readstr, sizeof(readstr),
			    "((%s_CV_%d(p) & %s_MASK_%d) >> %s_SHIFT_%d)",
			    P, A, P, A, P, A);
			snprintf(issetstr, sizeof(issetstr),
			    "((%s_CV_%d(p) & %s_MASK_%d) != 0)",
			    P, A, P, A);
			snprintf(clearstr, sizeof(clearstr),
			    "do { "
			        "%s_V_%d(p, (%s_CV_%d(p) & ~%s_MASK_%d)); "
			    "} while (0)",
			    P, A, P, A, P, A);
			snprintf(setstr, sizeof(setstr),
			    "do { "
			        "%s_V_%d(p, (%s_CV_%d(p) | "
				"((~%s_CV_%d(p)) & %s_MASK_%d))); "
			    "} while (0)",
			    P, A, P, A, P, A, P, A);
			snprintf(writestr, sizeof(writestr),
			    "do { "
				"%s_V_%d(p, "
			            "(%s_CV_%d(p) & ~%s_MASK_%d) | "
				    "(((v) << %s_SHIFT_%d) & %s_MASK_%d)); "
			    "} while (0)",
			    P, A, P, A, P, A, P, A, P, A);
		}
		printf("#define %s_READ_%d(p) %s\n", P, A, readstr);
		printf("#define %s_ISSET_%d(p) %s\n", P, A, issetstr);
		printf("#define %s_CLEAR_%d(p) %s\n", P, A, clearstr);
		printf("#define %s_SET_%d(p) %s\n", P, A, setstr);
		printf("#define %s_WRITE_%d(p, v) %s\n", P, A, writestr);
	}
}

/* Print enum constants. */
static void
print_enumer(const char *prefixstr, const struct aiv *aiv,
    const struct enumer *enumer)
{
	struct aiv v_storage, *v = &v_storage;
	*v = *aiv;
	v->sv.u.num.v = enumer->num.v;

	char enumerstr[32];
	print_vec(enumerstr, sizeof(enumerstr), v, num2vec);

	printf("#define %s_ENUM_%d_%s UINT%d_C(0x%s)\n",
	    P, A, enumer->name, A, enumerstr);
#undef	A
#undef	P
}

static void
print_vec(char *str, const size_t len, const struct aiv *aiv,
    void (*x2vec)(const struct aiv *, struct aiv *))
{
	struct aiv vec_storage, *vec = &vec_storage;
	(*x2vec)(aiv, vec);

	/* Print mask as hex string by 8-bit from MSB. */
	int n = 0;
	int asiz;
	for (asiz = aiv->asiz - NBBY; asiz >= 0; asiz -= NBBY) {
		assert(n < len);
		n += snprintf(str + n, len - n, "%02x",
		    vec->sv.u.vec.vs[asiz / NBBY]);
	}
}

/* 8-bit range mask. */
#define	_BfMask0(s)		((1 << (s)) - 1)
#define	_BfMask(s)		(((s) >= NBBY) ? 0xffU : _BfMask0((s)))
#define _BfMaskR(s, e)		(_BfMask((e)) & ~_BfMask((s)))

static void
mask2vec(const struct aiv *aiv, struct aiv *vec)
{
	const struct mask *mask = &aiv->sv.u.mask;
	int s = aiv->sv.shift;
	int e = s + (mask->E - mask->S);
	int i;
	for (i = 0; i < aiv->asiz; i += NBBY, s -= NBBY, e -= NBBY) {
		uint8_t b;
		if (s >= NBBY || e <= 0)
			b = 0;
		else {
			const int p = MAX(0, s);
			const int q = MAX(0, e);
			b = _BfMaskR(p, q);
		}
		vec->sv.u.vec.vs[i / NBBY] = b;
	}
}

static void
num2vec(const struct aiv *aiv, struct aiv *vec)
{
	const int v = aiv->sv.u.num.v;
	int i;
	for (i = 0; i < aiv->asiz; i += NBBY) {
		const int shift = aiv->sv.shift - i;
		uint8_t b;
		if (shift > NBBY || shift < -31)
			b = 0;
		else
			b = (shift > 0) ?  (v << shift) : (v >> -shift);
		vec->sv.u.vec.vs[i / NBBY] = b;
	}
}

/*
 * Dump info.
 */

struct layout {
	int size;
	char *buf;
};

static struct layout *dump_layout_alloc(void);
static void dump_layout_free(struct layout *);
static void dump_fields_addresses(struct layout *, int);
static void dump_fields_bits(struct layout *, int);
static void dump_fields_legend(void);
static int bits_index(const int, const int, int *);

static void
dump(struct prefix *prefix)
{
	struct layout *layout = dump_layout_alloc();
	const char *name = global->cur_prefix->name;

	putchar('\n');
	printf("/*\n");
	printf(" * %s%s(prefix=%s size=%d target=%d)\n",
	    name ? name : "", name ? " " : "",
	    name, global->cur_prefix->size, global->target);
	printf(" *\n");
	printf(" * real memory layout:\n");
	dump_fields_addresses(layout, 0);
	dump_fields_bits(layout, 0);
	printf(" *\n");

	int i;
	for (i = MINASIZ; i <= MAXASIZ; i <<= 1) {
		printf(" * %s endian memory layout view (%d-bit access):\n",
		    (i == MINASIZ) ? "little" : "big", i);
		dump_fields_addresses(layout, i);
		dump_fields_bits(layout, i);
		printf(" *\n");
	}

	dump_fields_legend();
	printf(" */\n");

	dump_layout_free(layout);
}

static struct layout *
dump_layout_alloc(void)
{
	struct layout *layout;

	layout = calloc(sizeof(*layout), 1);
	layout->size = (global->cur_prefix->size + MAXASIZ) & ~(MAXASIZ - 1);
	layout->buf = malloc(layout->size);
	memset(layout->buf, '.', layout->size);

	struct field *field;
	char C = 'a';
	int i = 0;
	SIMPLEQ_FOREACH(field, &global->cur_prefix->fields, entry) {
		int j;
		for (j = 0; j < field->width; j++) {
			const int x = global->target == BIG ?
			    /* Big endian layout index - simple. */
			    i :
			    /*
			     * Little endian layout index - insane.
			     *
			     * Little endian HWs put bit
			     * 0..7 8..15 16..23 24..31
			     * as
			     * 7..0 15..8 23..16 31..24
			     * in real memory.
			     *
			     * Little endian bf(1) bitfield definition 
			     * is written in little endian "view".  Thus
			     * real memory layout has to be 8-bit swapped.
			     */
			    (i - (i % NBBY) + (NBBY - (i % NBBY) - 1));
			layout->buf[x] = C;
			i++;
		}
		C++;
	}

	return layout;
}

static void
dump_layout_free(struct layout *layout)
{
	free(layout->buf);
	free(layout);
}

static void
dump_fields_addresses(struct layout *layout, int swap)
{
	int i;

	printf(" * ");
	for (i = 0; i < global->cur_prefix->size; i += NBBY) {
		if (i > 0 && i % NBBY == 0)
			putchar(' ');
		if (swap == 0) {
			printf("%-"NBBYSTR"d", i);
		} else {
			const int mask = swap - 1;
			const int offset = i & mask;
			const int n = (i - offset) + (swap - offset) - NBBY;
			printf("%"NBBYSTR"d", n);
		}
	}
	putchar('\n');
}

static void
dump_fields_bits(struct layout *layout, int swap)
{
	int i;

	printf(" * ");
	for (i = 0; i < global->cur_prefix->size; i += NBBY) {
		int index, incr;
		index = bits_index(i, swap, &incr);
		const char *p = layout->buf + index;
		int j;
		for (j = 0; j < NBBY; j++) {
			putchar(*p);
			p += incr;
		}
		putchar(' ');
	}
	putchar('\n');
}

static void
dump_fields_legend(void)
{
	struct field *field;
	char C = 'a';

	printf(" * ");
	SIMPLEQ_FOREACH(field, &global->cur_prefix->fields, entry) {
		const char * const name =
		    (field->name != NULL) ? field->name : "(unused)";
		printf("%s%c:%d:%s",
		    (C == 'a') ? "" : " ", C, field->width, name);
		C++;
	}
	putchar('\n');
}

static int
bits_index(const int index, const int swap_size, int *rincr)
{
	if (swap_size == 0) {
		*rincr = 1;
		return index;
	} else {
		const int mask = (swap_size - 1);
		*rincr = -1;
		return (index & ~mask) + (swap_size - 1) - (index & mask);
	}
}
