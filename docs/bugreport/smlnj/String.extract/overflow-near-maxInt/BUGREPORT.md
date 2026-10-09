# SML/NJ 110.99.9 and 2026.2: `String.extract (s, i, SOME j)` near `Int.maxInt` crashes the system instead of raising `Subscript`

## Status: not reported

The issue trackers of smlnj/legacy and smlnj/smlnj have nothing on
`String.extract` (searched 2026-10-09). The code is the same in
smlnj/legacy `main` at `12f1dfe` (2026-10-03) and in smlnj/smlnj `main` at
`033dd76` (2026-10-09), so 110.99.9, the 2026 series and what comes next
all have it. The program was run on the 110.99.9 64-bit release and on
2026.2.

**What is worth sending SML/NJ:** a new issue on smlnj/legacy, which also
asks for smlnj/smlnj, with `bug.sml` and `fix.diff` (`upstream.md`).

## Summary

* **The trigger:** `String.extract (s, i, SOME j)` where `i + j` passes
  `Int.maxInt`, such as `extract ("abcde", Int.maxInt, SOME 1)` or
  `extract ("abcde", 1, SOME Int.maxInt)`.
* **What goes wrong:** no `Subscript`; the system dies.
  - `extract (s, maxInt, SOME 1)` reads the character at index `maxInt`
    and dies with `Fatal error -- bogus overflow fault ... sig = 11`.
  - `extract (s, 1, SOME maxInt)` and `extract (s, maxInt, SOME maxInt)`
    allocate a string of `maxInt` characters and die with `Fatal error --
    unable to allocate minimum size`.
* **Required behaviour:** the
  [Basis `STRING` specification](https://smlfamily.github.io/Basis/string.html):
  "`extract (s, i, SOME j)` returns the substring of size j starting at
  index i, i.e., the string s[i..i+j-1]. It raises Subscript if i < 0 or
  j < 0 or |s| < i + j." `String.substring`, which the specification says is
  equivalent, raises `Subscript` for the same arguments. MLton, Poly/ML and
  MLKit raise `Subscript`.

## Where it happens

| Build | wrong of 3 |
|---|---|
| 110.99.9, 64-bit release | 3 (the first kills the system) |
| 2026.2 | 3 (likewise) |
| `extract` with `fix.diff`, as a program on 110.99.9 (below) | 0 |

```
$ sml bug.sml                           # 110.99.9 or 2026.2, 64-bit
String.substring ("abcde", 1, big) (for contrast): Subscript (expected)
/home/.../bin/sml: Fatal error -- bogus overflow fault: pc = 0x784d65cc29b9, sig = 11
```

Each call of `extract` alone (the program stops at the first):

```
String.extract ("abcde", big, SOME 1)     Fatal error -- bogus overflow fault: ..., sig = 11
String.extract ("abcde", big, SOME big)   Error -- unable to map 3145728 bytes, errno = 12
                                          Fatal error -- unable to allocate minimum size
String.extract ("abcde", 1, SOME big)     (the same)
```

## The cause

`system/Basis/Implementation/string.sml` adds the start and the length
with `++`, which is `InlineT.Int.fast_add`, the addition without the test
of `Overflow`:

```sml
  (* fast add/subtract avoiding the overflow test *)
    infix -- ++
    fun x -- y = InlineT.Int.fast_sub(x, y)
    fun x ++ y = InlineT.Int.fast_add(x, y)
...
	      | (_, SOME 1) =>
		  if ((base < 0) orelse (len < (base ++ 1)))
		    then raise General.Subscript
		    else str(unsafeSub(v, base))
	      | (_, SOME n) =>
		  if ((base < 0) orelse (n < 0) orelse (len < (base ++ n)))
		    then raise General.Subscript
		    else newVec n
```

Near `Int.maxInt` the sum wraps round to a negative number, the test
`len < base ++ n` is false, and the region passes: `SOME 1` reads
`unsafeSub (v, maxInt)`, and `SOME n` allocates `n` characters
(`Assembly.A.create_s`) and copies them with `unsafeSub`. `substring`
(`smlnj/init/pervasive.sml`) does the test in words and is right.

## The fix

`fix.diff` (against smlnj/legacy `12f1dfe`, which has the file of
110.99.9; with `system/` for `base/system/` it applies to 2026.2 and to
smlnj/smlnj `033dd76`) tests without adding: `len <= base` for one
character, and `len < base orelse len -- base < n` for `n`, where
`len -- base` cannot overflow once `0 <= base <= len`.

**How it was tested:** a rebuild of SML/NJ's Basis was not made. Instead
`extract`, as `string.sml` has it, was compiled as a program on 110.99.9
with what it takes of the compiler stood in for (`++` and `--` wrapping
round as `fast_add` and `fast_sub` do, `Unsafe.CharVector` for the
string primitives):

* without the fix the stand-in dies as the library does;
* with the fix `bug.sml` gives `Subscript` three times;
* with the fix in place of `String.extract`, Rune's Basis suite's
  `tests/basis/string.sml` passes all 104 checks of `String.extract` on
  110.99.9; its other failures are the known ones of `isSubstring`,
  `fromString` and `fromCString`.

## How Rune met it

Natively the suite's section `string/extract-overflow` ends the run
(`deviations.txt`: `native:smlnj*@* | @section/string/extract-overflow`).
In `xc2:smlnj-legacy`, which compiles SML/NJ's own library with Rune
(`tests/basis/xc2`), the same code runs to the end: the region passes and
the string of `j` characters raises `Size` on Rune's machine, which showed
what the check does.
