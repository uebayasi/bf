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

#ifndef nitems
#define nitems(x)	(sizeof(x) / sizeof(x[0]))
#endif

struct prefix;
struct field;

SIMPLEQ_HEAD(prefixes, prefix);
SIMPLEQ_HEAD(fields, field);
struct prefix {
	SIMPLEQ_ENTRY(prefix) entry;
	char *name;
	int size;
	struct fields fields;
	struct field *cur, *prev;
};
struct field {
	SIMPLEQ_ENTRY(field) entry;
	char *name;
	int offset;
	int width;
};
enum endian {
	LITTLE = 0,
	BIG = 1,
};

static void prefix_start(void);
static void prefix_stop(void);
static void field_start(void);
static void field_stop(void);

struct global {
	int verbose;
	int full;
	struct prefixes prefixes;
	struct prefix *prefix;
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
	assert(global->prefix->name == NULL);
	global->prefix->name = strdup(yytext);
	BEGIN INITIAL;
}
<PREFIX>{nl} {
	assert(global->prefix->name == NULL);
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
	assert(global->prefix->size == 0);
	global->prefix->size = atoi(yytext);
	assert(global->prefix->cur == NULL);
	BEGIN INITIAL;
}

<FIELD>{id} {
	global->prefix->cur->name = strdup(yytext);
}
<FIELD>{blank} {
}
<FIELD>{char} {
}
<FIELD>{nl} {
	field_stop();
	BEGIN INITIAL;
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

	while ((c = getopt(argc, argv, "fv")) != -1) {
		switch (c) {
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
	if (global->full)
		printf("#include <bf.h>\n");
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
	assert(global->prefix == NULL);
	global->prefix = prefix_alloc();
}

static void
prefix_stop(void)
{
	if (global->prefix != NULL) {
		if (global->verbose)
			dump(global->prefix);
		prefix_free(global->prefix);
		global->prefix = NULL;
	}
	assert(global->prefix == NULL);
}

static void
field_start(void)
{
	assert(global->prefix->cur == NULL);
	global->prefix->cur = field_alloc();
	global->prefix->cur->width = atoi(yytext);
}

static void
field_stop(void)
{
	struct field *prev = global->prefix->prev;
	const int offset = prev ? (prev->offset + prev->width) : 0;

	assert(offset + global->prefix->cur->width <= global->prefix->size);
	global->prefix->cur->offset = offset;
	global->prefix->prev = global->prefix->cur;
	field_print(global->prefix->cur);
	global->prefix->cur = NULL;
}

static struct prefix *
prefix_alloc(void)
{
	struct prefix *new_prefix;

	new_prefix = calloc(sizeof(*new_prefix), 1);
	SIMPLEQ_INIT(&new_prefix->fields);
	SIMPLEQ_INSERT_TAIL(&global->prefixes, new_prefix, entry);
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
	SIMPLEQ_INSERT_TAIL(&global->prefix->fields, new_field, entry);
	return new_field;
}

static void
field_free(struct field *field)
{
	free(field);
}

/*
 * Print bit-field accessors.
 */

struct accs {
	const struct field *field;
	enum endian target;
	int align;
	int accs;
	int index;

	/* Unaligned specific. */
	int shift;
	int S, E;
};

static void print_field(const struct field *);
static void print_accs(const struct accs *);
static int calc_access_size(struct accs *);
static void calc_access_shift(struct accs *);
static void unaligned_maskstr(char *, size_t, const struct accs *);

#define O	accs->field->offset
#define W	accs->field->width

static void
field_print(const struct field *field)
{
	putchar('\n');

	const char *fmt = "/* field: name=%s offset=%d width=%d */\n";

	if (field->name == NULL) {
		/* Unused bits (pads). */
		if (global->verbose) {
			printf(fmt, "(unused)", field->offset, field->width);
		}
	} else {
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

	accs->S = S;
	accs->E = E;
	accs->align = align;

	/* Minimal register access width == alignment size. */
	const int A = calc_access_size(accs);

	/* Privide all access widths >A. */
	int a;
	for (a = A; a <= 64; a <<= 1) {
		accs->accs = a;
		accs->index = accs->S / accs->accs;
		calc_access_shift(accs);
		print_accs(accs);
	}
}

static void
print_accs(const struct accs *accs)
{
	const char * const name = accs->field->name;

	const int A = accs->accs;
	char prefixstr[256];

	snprintf(prefixstr, sizeof(prefixstr), "%s%s%s",
	    global->prefix->name ? global->prefix->name : "",
	    global->prefix->name ? "_" : "", name);

	printf("#define %s_INDEX_%d %d\n", prefixstr, A, accs->index);

	if (global->full) {
		printf("#define %s_OCV_%d(p) (*((const uint%d_t *)(p) + %s_INDEX_%d))\n",
		    prefixstr, A, A, prefixstr, A);
		printf("#define %s_OV_%d(p) (*((uint%d_t *)(p) + %s_INDEX_%d))\n",
		    prefixstr, A, A, prefixstr, A);
	}

	if (global->full) {
		char swapstr[16];
		snprintf(swapstr, sizeof(swapstr), "_BfSwap%s%d",
		    (global->target == LITTLE) ? "Le" : "Be", A >> 3);
		printf("#define %s_CV_%d(p) %s(%s_OCV_%d(p))\n",
		    prefixstr, A, swapstr, prefixstr, A);
		printf("#define %s_V_%d(p, v) do { %s_OV_%d(p) = %s(v); } while (0)\n",
		    prefixstr, A, prefixstr, A, swapstr);
	}

	static char readstr[256];
	static char issetstr[256];
	static char clearstr[256];
	static char setstr[256];
	static char writestr[256];
	if (accs->accs == accs->align) {
		if (global->full) {
			snprintf(readstr, sizeof(readstr),
			    "%s_CV_%d(p)", prefixstr, A);
			snprintf(issetstr, sizeof(readstr),
			    "(%s_CV_%d(p) != 0)", prefixstr, A);
			snprintf(clearstr, sizeof(clearstr),
			    "do { %s_V_%d(p, 0); } while (0)", prefixstr, A);
			snprintf(setstr, sizeof(setstr),
			    "do { %s_V_%d(p, (%s_CV_%d | ~%s_CV_%d(p))); } while (0)",
			    prefixstr, A, prefixstr, A, prefixstr, A);
			snprintf(writestr, sizeof(writestr),
			    "do { %s_V_%d(p, v); } while (0)",
			    prefixstr, A);
		}
	} else {
		char maskstr[32];
		unaligned_maskstr(maskstr, sizeof(maskstr), accs);
		printf("#define %s_MASK_%d UINT%d_C(0x%s)\n",
		    prefixstr, A, A, maskstr);
		printf("#define %s_SHIFT_%d %d\n",
		    prefixstr, A, accs->shift);
		if (global->full) {
			snprintf(readstr, sizeof(readstr),
			    "((%s_CV_%d(p) & %s_MASK_%d) >> %s_SHIFT_%d)",
			    prefixstr, A, prefixstr, A, prefixstr, A);
			snprintf(issetstr, sizeof(issetstr),
			    "((%s_CV_%d(p) & %s_MASK_%d) != 0)",
			    prefixstr, A, prefixstr, A);
			snprintf(clearstr, sizeof(clearstr),
			    "do { %s_V_%d(p, (%s_CV_%d(p) & ~%s_MASK_%d)); } while (0)",
			    prefixstr, A, prefixstr, A, prefixstr, A);
			snprintf(setstr, sizeof(setstr),
			    "do { %s_V_%d(p, (%s_CV_%d(p) | ((~%s_CV_%d(p)) & %s_MASK_%d))); } while (0)",
			    prefixstr, A, prefixstr, A, prefixstr, A, prefixstr, A);
			snprintf(writestr, sizeof(writestr),
			    "do { "
				"%s_V_%d(p, "
			            "(%s_CV_%d(p) & ~%s_MASK_%d) | "
				    "(((v) << %s_SHIFT_%d) & %s_MASK_%d)); "
			    "} while (0)",
			    prefixstr, A, prefixstr, A, prefixstr, A, prefixstr, A, prefixstr, A);
		}
	}
	if (global->full) {
		printf("#define %s_READ_%d(p) %s\n", prefixstr, A, readstr);
		printf("#define %s_ISSET_%d(p) %s\n", prefixstr, A, issetstr);
		printf("#define %s_CLEAR_%d(p) %s\n", prefixstr, A, clearstr);
		printf("#define %s_SET_%d(p) %s\n", prefixstr, A, setstr);
		printf("#define %s_WRITE_%d(p, v) %s\n", prefixstr, A, writestr);
	}
}

static int
calc_access_size(struct accs *accs)
{
	if (accs->align > 0) {
		return accs->align;
	} else {
		/* (Minimal) access size. */

		/* 8-bit indexes. */
		int i = accs->S / NBBY;
		int j = (accs->E - 1) / NBBY;

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

static void
calc_access_shift(struct accs *accs)
{
	const int A = accs->accs;

	/* Shift in register. */
	accs->shift =
	    /* Aligned access - no shift needed. */
	    (accs->accs == accs->align) ? 0 :
	    /* Unaligned access. */
	    (accs->target == BIG) ?
		/*
		 * Big endian .bf definition is in real memory, not view.
		 * Calc shift from right.
		 */
		((accs->E % A) == 0 ? 0 : (A - (accs->E % A))) :
		/*
		 * Little endian .bf definition is in little endian view.
		 * Simply calc shift from left.
		 */
		(accs->S % A);
}

static void
unaligned_maskstr(char *str, const size_t len, const struct accs *accs)
{
	int a;
	int n = 0;

	const int s = accs->shift;
	const int e = s + (accs->E - accs->S);

	/* Print mask by 8-bit from MSB. */
	for (a = accs->accs - 8; a >= 0; a -= 8) {
		const int S = MAX(0, s - a);
		const int E = MAX(0, e - a);
		const uint8_t m = _BfMaskWN(1, S, E - S);

		assert(n < len);
		n += snprintf(str + n, len - n, "%02x", m);
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
	char *name = global->prefix->name;

	putchar('\n');
	printf("/*\n");
	printf(" * %s%s(prefix=%s size=%d target=%d)\n",
	    name ? name : "", name ? " " : "",
	    name, global->prefix->size, global->target);
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
	layout->size = (global->prefix->size + 64) & ~(64 - 1);
	layout->buf = malloc(layout->size);
	memset(layout->buf, '.', layout->size);

	struct field *field;
	char C = 'a';
	int i = 0;
	SIMPLEQ_FOREACH(field, &global->prefix->fields, entry) {
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
	for (i = 0; i < global->prefix->size; i += NBBY) {
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
	for (i = 0; i < global->prefix->size; i += NBBY) {
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
	SIMPLEQ_FOREACH(field, &global->prefix->fields, entry) {
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
