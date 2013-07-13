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
#include "queue.h"

struct prefix;
struct field;
struct enumer;

SIMPLEQ_HEAD(prefixes, prefix);
SIMPLEQ_HEAD(fields, field);
SIMPLEQ_HEAD(enumers, enumer);
struct prefix {
	SIMPLEQ_ENTRY(prefix) entry;
	char *name;
	int size;
	struct fields fields;
};
struct field {
	SIMPLEQ_ENTRY(field) entry;
	char *name;
	int offset;
	int width;
	struct enumers enumers;
	struct enumer *cur_enumer;
};
struct enumer {
	SIMPLEQ_ENTRY(enumer) entry;
	char *name;
	int v;
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
	int access;
	int verbose;
	int full;
	struct prefixes prefixes;
	struct prefix *cur_prefix, *prev_prefix;
	struct field *cur_field, *prev_field;
	struct enumer *cur_enumer, *prev_enumer;
	enum endian target;
} global_storage = {
	.prefixes = SIMPLEQ_HEAD_INITIALIZER(global_storage.prefixes),
	.target = LITTLE,
}, *global = &global_storage;
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
	// XXX strtonum
	global->cur_prefix->size = atoi(yytext);
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
		// XXX strtonum
		global->cur_enumer->v = atoi(yytext);
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
	assert(global->cur_enumer->v != -1);
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

#include "bf.h"

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
		int a;
		switch (c) {
		case 'a':
			a = atoi(optarg);
			switch (a) {
			case 8:
			case 16:
			case 32:
			case 64:
				global->access |= a;
				break;
			default:
				fprintf(stderr, "invalid access size (%d)\n", a);
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
	assert(global->cur_field == NULL);
	global->cur_field = field_alloc();
	global->cur_field->width = atoi(yytext);
}

static void
field_stop(void)
{
	struct field *prev = global->prev_field;
	const int offset = prev ? (prev->offset + prev->width) : 0;

	if (offset + global->cur_field->width > global->cur_prefix->size) {
		fprintf(stderr, "%s: field %s exceeding size "
		    "(offset=%d width=%d size=%d)\n",
		    __func__, global->cur_field->name,
		    offset, global->cur_field->width, global->cur_prefix->size);
		exit(1);
	}
	assert(offset + global->cur_field->width <= global->cur_prefix->size);
	global->cur_field->offset = offset;
	global->prev_field = global->cur_field;
	field_print(global->cur_field);
	global->cur_field = NULL;
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
	new_enumer->v = -1;
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

struct mask {
	int S, E;
};

/* Value represented as byte vector. */
struct vec {
	uint8_t vs[8];
};

/* Value with shift. */
struct sv {
	int shift;
	union {
		/* Real value is (mask << shift). */
		struct mask mask;
		/* Real value is ((vec[0] | vec[(1] << 8) | ...) << shift). */
		struct vec vec;
		/* Real value is (v << shift). */
		int v;
	} u;
};

/* Value with access-size and index. */
struct asv {
	/* Real value is, (v << shift + (asiz * index)). */
	int asiz;
	int index;
	struct sv sv;
};

/* Access. */
struct accs {
	const struct field *field;
	enum endian target;
	int align;
	int accs;
	int index;
	int shift;
	struct asv asv;
};

static void print_field(const struct field *);
static void print_accs(const char *, const struct accs *);
static int calc_access_size(const struct accs *);
static int calc_access_shift(const struct accs *);
static void make_maskstr(char *, size_t, const struct accs *);
static void print_enumers(const char *, const struct accs *);
static void make_enumerstr(char *, const size_t, const struct accs *,
    const int);
static void print_maskvec(char *, const size_t, const int, const struct vec *);
static void mask2vec(const struct asv *, struct asv *);
static void v2vec(const struct asv *, struct asv *);

#define O	accs->field->offset
#define W	accs->field->width

static void
field_print(const struct field *field)
{
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
		print_field(field);
	}
}

static void
print_field(const struct field *field)
{
	struct accs accs_storage = {
		.field = field,
		.target = global->target,
	}, *accs = &accs_storage;

	/*
	 * Calc alignment by checking the right most bit.
	 * Ignore alignment more than 64-bit (8).
	 */
	const int S = O;
	const int E = O + W;
	const int align = MIN(MIN(_BfAlign(S), _BfAlign(E)), 8) << 3;

	accs->align = align;
	accs->asv.sv.u.mask.S = S;
	accs->asv.sv.u.mask.E = E;

	/* Minimal register access width == alignment size. */
	const int A = calc_access_size(accs);

	const char * const name = accs->field->name;
	char prefixstr[256];
	snprintf(prefixstr, sizeof(prefixstr), "%s%s%s",
	    global->cur_prefix->name ? global->cur_prefix->name : "",
	    global->cur_prefix->name ? "_" : "", name);

	/* Provide all access widths >A. */
	int a;
	for (a = A; a <= 64; a <<= 1) {
		/* Follow explicit access sizes when specified. */
		if (global->access != 0 && (global->access & a) == 0)
			continue;
		accs->accs = a;
		accs->index = O / accs->accs;
		accs->shift = calc_access_shift(accs);
#if 1
		accs->asv.asiz = a;
		accs->asv.index = O / accs->accs;
		accs->asv.sv.shift = calc_access_shift(accs);
#endif
		print_accs(prefixstr, accs);
		print_enumers(prefixstr, accs);
	}
}

/* Print accessors.  Assume the resulting code uses bf.h. */
static void
print_accs(const char *prefixstr, const struct accs *accs)
{
	const int A = accs->accs;
#define P prefixstr

	printf("#define %s_INDEX_%d %d\n", P, A, accs->index);

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

	static char readstr[256];
	static char issetstr[256];
	static char clearstr[256];
	static char setstr[256];
	static char writestr[256];
	if (accs->accs == accs->align) {
		if (global->full) {
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
		}
	} else {
		const struct mask *mask = &accs->asv.sv.u.mask;
		char maskstr[32];
		make_maskstr(maskstr, sizeof(maskstr), accs);
		printf("#define %s_SHIFT_%d %d\n",
		    P, A, accs->shift);
		printf("#define %s_WIDTH_%d %d\n",
		    P, A, mask->E - mask->S);
		printf("#define %s_MASK_%d UINT%d_C(0x%s)\n",
		    P, A, A, maskstr);
		if (global->full) {
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
			    P, A, P, A, P, A,
			    P, A, P, A);
		}
	}
	if (global->full) {
		printf("#define %s_READ_%d(p) %s\n", P, A, readstr);
		printf("#define %s_ISSET_%d(p) %s\n", P, A, issetstr);
		printf("#define %s_CLEAR_%d(p) %s\n", P, A, clearstr);
		printf("#define %s_SET_%d(p) %s\n", P, A, setstr);
		printf("#define %s_WRITE_%d(p, v) %s\n", P, A, writestr);
	}
}

static void
print_enumers(const char *prefixstr, const struct accs *accs)
{
	const int A = accs->accs;
	struct enumer *enumer;

	SIMPLEQ_FOREACH(enumer, &accs->field->enumers, entry) {
		char enumerstr[32];
		make_enumerstr(enumerstr, sizeof(enumerstr), accs, enumer->v);
		printf("#define %s_ENUM_%d_%s UINT%d_C(0x%s)\n",
		    P, A, enumer->name, A, enumerstr);
	}
}

static int
calc_access_size(const struct accs *accs)
{
	if (accs->align > 0) {
		return accs->align;
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
		const struct mask *mask = &accs->asv.sv.u.mask;
		int i = mask->S / NBBY;
		int j = (mask->E - 1) / NBBY;

		int a = 1;

		while (i > 0 && j > 0) {
			/*
			 * (S, E) have the same index
			 * -> not crossing boundary.
			 */
			if (i == j)
				break;
			/* Max is 8 (== 64-bit) access. */
			if (a == 8)
				break;
			/* Larger alignment next. */
			a <<= 1;
			i >>= 1;
			j >>= 1;
		}

		return a << 3;
	}
}

static int
calc_access_shift(const struct accs *accs)
{
	const int A = accs->accs;
	const struct mask *mask = &accs->asv.sv.u.mask;

	/* Shift in register. */
	return
	    /* Aligned access - no shift needed. */
	    (accs->accs == accs->align) ? 0 :
	    /* Unaligned access. */
	    (accs->target == BIG) ?
		/*
		 * Big endian .bf definition is in real memory, not view.
		 * Calc shift from right.
		 */
		((mask->E % A) == 0 ? 0 : (A - (mask->E % A))) :
		/*
		 * Little endian .bf definition is in little endian view.
		 * Simply calc shift from left.
		 */
		(mask->S % A);
}

static void
make_maskstr(char *str, const size_t len, const struct accs *accs)
{
	struct asv Vec_storage, *Vec = &Vec_storage;
	mask2vec(&accs->asv, Vec);
	print_maskvec(str, len, accs->accs, &Vec->sv.u.vec);
}

static void
make_enumerstr(char *str, const size_t len, const struct accs *accs,
    const int v)
{
	struct asv sv_storage, *sv = &sv_storage;
	*sv = accs->asv;
	sv->sv.u.v = v;

	struct asv vec_storage, *vec = &vec_storage;
	v2vec(sv, vec);
	print_maskvec(str, len, accs->accs, &vec->sv.u.vec);
}

static void
mask2vec(const struct asv *asv, struct asv *vec)
{
	const struct mask *mask = &asv->sv.u.mask;
	const int s = asv->sv.shift;
	const int e = s + (mask->E - mask->S);
	int i;
	for (i = 0; i < asv->asiz; i += 8) {
		const int p = MAX(0, s - i);
		const int q = MAX(0, e - i);
		vec->sv.u.vec.vs[i / 8] = _BfMaskWN(1, p, q - p);
	}
}

static void
v2vec(const struct asv *asv, struct asv *vec)
{
	const int v = asv->sv.u.v;
	int i;
	for (i = 0; i < asv->asiz; i += 8) {
		const int shift = asv->sv.shift - i;
		if (shift > 8 || shift < -31)
			vec->sv.u.vec.vs[i / 8] = 0;
		else
			vec->sv.u.vec.vs[i / 8] = (shift > 0) ?
			    (v << shift) : (v >> -shift);
	}
}

static void
print_maskvec(char *str, const size_t len, const int A, const struct vec *vec)
{
	/* Print mask by 8-bit from MSB. */
	int n = 0;
	int a;
	for (a = A - 8; a >= 0; a -= 8) {
		assert(n < len);
		n += snprintf(str + n, len - n, "%02x", vec->vs[a / 8]);
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
	char *name = global->cur_prefix->name;

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
	for (i = 8; i <= 64; i <<= 1) {
		printf(" * %s endian memory layout view (%d-bit access):\n",
		    (i == 8) ? "little" : "big", i);
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
	layout->size = (global->cur_prefix->size + 64) & ~(64 - 1);
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
			    /* Little endian layout index - insane. */
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
		char * const name =
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
