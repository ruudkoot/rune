# How the library reads its specification

[The Standard ML Basis Library](README.md)

The notes of the documentation, from the comments of the library. The name of a note is the label of
the check of the test suite that pins it, where there is one.

## Readings

Where the text is silent, ambiguous or contradicts itself, and what it is taken to say.

- `Bool.scan/wsx-*` &mdash; [`BOOL.scan`](sig/BOOL.md#val-scan). "Initial whitespace" is what [`Char.isSpace`](sig/CHAR.md#val-isspace) accepts, as for [`StringCvt.skipWS`](sig/STRING_CVT.md#val-skipws): the space, and the characters `\t`, `\n`, `\v`, `\f` and `\r`.
- `Bool.fromString/none-not-whitespace-*` &mdash; [`BOOL.fromString`](sig/BOOL.md#val-fromstring). The characters whose codes are next to those of the white space characters (0, 8, 14, 31, 33, 95 and 127) are not white space: a string that begins with one of them gives `NONE`.
- `Char.compare/127-128` &mdash; [`CHAR.compare`](sig/CHAR.md#val-compare). The codes are not negative, so 127 comes before 128 and 255 after 0: a character is not a signed byte.
- `Char.isAlpha/latin1` &mdash; [`CHAR.isAscii`](sig/CHAR.md#val-isascii). The classes below are the sets that the specification's discussion lists, whatever the locale: no character above 127 is in any of them, and `toLower` and `toUpper` change the 52 letters of ASCII only.
- `Char.scan/formatting` &mdash; [`CHAR.scan`](sig/CHAR.md#val-scan). A formatting sequence, a backslash, white space and another backslash, stands for nothing. Such sequences are passed over before the character, and after it as well, so that what is left of the stream never begins with one. *(no check pins it)*
- `Char.fromString/printable-only-all-rejected` &mdash; [`CHAR.fromString`](sig/CHAR.md#val-fromstring). A first character outside the printable range, codes 32 to 126, gives `NONE`, and so does a backslash by itself; every other printable character is converted to itself.
- `Char.fromString/unescaped-double-quote` (the suite differs) &mdash; [`CHAR.fromString`](sig/CHAR.md#val-fromstring). The specification says that the text is read "as allowed in an SML program" and names only characters that do not print and bad escapes as what stops a scan. Rune therefore converts a double quote that has no backslash to itself, as Poly/ML does; MLton and SML/NJ answer `NONE`, and that is what the suite expects.
- `Char.fromCString/hex-huge-does-not-fit` &mdash; [`CHAR.fromCString`](sig/CHAR.md#val-fromcstring). A `\x` escape whose value is no character gives `NONE` however many digits it has: [`Overflow`](sig/GENERAL.md#exn-overflow) is not raised.
- `Char.fromCString/printable-only-all-converted` &mdash; [`CHAR.fromCString`](sig/CHAR.md#val-fromcstring). Every printable character but the double quote and the backslash is converted to itself, the single quote included; what does not print is rejected.
- `OS.IO.kind/other-kinds` &mdash; [`OS_IO.kind`](sig/OS_IO.md#val-kind). "A given implementation may define other iodesc values": the result need not be one of the seven of `Kind`. An `iodesc_kind` is a name here, and a descriptor of something else has a name that `Kind` does not list. *(no check pins it)*
- `OS.IO.poll/closed-SysErr` &mdash; [`OS_IO.poll`](sig/OS_IO.md#val-poll). The specification gives "one of the file descriptors refers to a closed file" as an example of what raises [`OS.SysErr`](sig/OS.md#exn-syserr). The operating system itself reports such a descriptor as ready, so every descriptor is looked at before the wait, and a closed one raises [`OS.SysErr`](sig/OS.md#exn-syserr).
- `StringCvt.SCI/carries-negative` &mdash; [`STRING_CVT.realfmt`](sig/STRING_CVT.md#type-realfmt). A constructor carries any `int option`, also one that no format accepts, such as `SCI (SOME ~1)`: [`Size`](sig/GENERAL.md#exn-size) is raised by `fmt`, not by the constructor.
- `StringCvt.padLeft/width-minInt` &mdash; [`STRING_CVT.padLeft`](sig/STRING_CVT.md#val-padleft). For the smallest `int` the difference `i - size s` does not exist as an `int`; `s` is returned all the same, and [`Overflow`](sig/GENERAL.md#exn-overflow) is not raised.
- `StringCvt.splitl/reads-no-further-than-first-failing` &mdash; [`STRING_CVT.splitl`](sig/STRING_CVT.md#val-splitl). "Will often use lookahead characters" is taken to mean exactly one: the character that stops the scan is read from the source, and nothing after it.

## Errata

Where the specification is wrong.

- `BOOL/bool-spec` &mdash; [`BOOL.bool`](sig/BOOL.md#type-bool). The specification writes `datatype bool = false \| true`. The Definition (Section 2.9) does not allow `true` and `false` to be specified, so the signature replicates the top-level datatype instead; the meaning is the same. *(no check pins it)*
- `CHAR/string-types` &mdash; [`CHAR`](sig/CHAR.md). The specification writes the types of `toString`, `scan`, `fromString`, `toCString` and `fromCString` with [`String.string`](sig/STRING.md#type-string) and [`Char.char`](sig/CHAR.md#type-char) rather than with the `string` and `char` of the signature, because the text is always one of 8-bit characters, also for [`WideChar`](sig/CHAR.md). They are kept as written; that [`Char.char`](sig/CHAR.md#type-char) is `char` and [`Char.string`](sig/CHAR.md#type-string) is [`String.string`](sig/STRING.md#type-string) is a constraint on the structure [`Char`](sig/CHAR.md). *(no check pins it)*
- `CHAR/fromString-sample` &mdash; [`CHAR`](sig/CHAR.md). The third example of the page's table for `fromString` is not the text of an SML string; the page of [`STRING`](sig/STRING.md) has the table as it was meant.
- `LIST/list-spec` &mdash; [`LIST.list`](sig/LIST.md#type-list). The specification writes the datatype out in the signature. The Definition (Section 2.9) does not allow `nil` and `::` to be specified, so the signature replicates the top-level datatype instead; the meaning is the same. *(no check pins it)*
- `OPTION/option-spec` &mdash; [`OPTION.option`](sig/OPTION.md#type-option). `NONE` and `SOME` may be specified, unlike the constructors of [`bool`](sig/BOOL.md#type-bool) and [`list`](sig/LIST.md#type-list), so the datatype stands here as the specification writes it. *(no check pins it)*

## Deviations

Where the library departs from the specification.

- `StringCvt.cs/transparent` &mdash; [`STRING_CVT.cs`](sig/STRING_CVT.md#type-cs). The specification keeps the type abstract. [`StringCvt`](sig/STRING_CVT.md) is not sealed, so `cs` is visibly `int`, the index of the next character; a program that uses that is not portable. *(no check pins it)*

## Choices of the implementation

What the specification leaves open, and what the library does.

- `Char.char/eight-bits` &mdash; [`CHAR.char`](sig/CHAR.md#type-char). [`Char.char`](sig/CHAR.md#type-char) is the top-level `char`, a character of 8 bits: its codes run from 0 to 255. *(no check pins it)*
- `Char.maxOrd/value` &mdash; [`CHAR.maxOrd`](sig/CHAR.md#val-maxord). 255 for [`Char`](sig/CHAR.md), and 1114111, the last code point of Unicode, for [`WideChar`](sig/CHAR.md).
- `IntInf.int/limbs` &mdash; [`INT_INF`](sig/INT_INF.md). A sign and a list of digits in base 2^30, written in SML on top of the 64-bit `int`; equal numbers are equal values, so `=` compares them. [`LargeInt`](sig/INTEGER.md) is [`IntInf`](sig/INT_INF.md). *(no check pins it)*
- `OS.IO.iodesc/descriptor` &mdash; [`OS_IO.iodesc`](sig/OS_IO.md#type-iodesc). The file descriptor of the operating system, a small integer in a datatype of its own. *(no check pins it)*
- `OS.IO.pollDesc/always` &mdash; [`OS_IO.pollDesc`](sig/OS_IO.md#val-polldesc). Every descriptor can be polled: the answer is never `NONE`. *(no check pins it)*
- `OS.IO.Poll/never` &mdash; [`OS_IO.Poll`](sig/OS_IO.md#exn-poll). It is never raised: the operating system is asked about every event, and answers when `poll` is called. *(no check pins it)*

---

<sub>Generated by runedoc; do not edit.</sub>
