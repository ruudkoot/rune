# signature BIT_FLAGS

[The Standard ML Basis Library](../README.md) &rsaquo; **BIT_FLAGS**

|  |  |
| --- | --- |
| Status | required |
| Implementations | 9 |
| Documentation | 0 of 9 entries documented |
| Tests | 70 checks of 9 entries |
| Source | [lib/basis/sig\_bit\_flags.sml](../../../../lib/basis/sig_bit_flags.sml) |

## Synopsis

```sml
signature BIT_FLAGS
structure Posix.FileSys.O : BIT_FLAGS
structure Posix.FileSys.S : BIT_FLAGS
structure Posix.IO.FD : BIT_FLAGS
structure Posix.IO.O : BIT_FLAGS
structure Posix.Process.W : BIT_FLAGS
structure Posix.TTY.C : BIT_FLAGS
structure Posix.TTY.I : BIT_FLAGS
structure Posix.TTY.L : BIT_FLAGS
structure Posix.TTY.O : BIT_FLAGS
```

| Implementation |  | Source |
| --- | --- | --- |
| `Posix.FileSys.O` | The flags of open and the bits of a mode, as words. "all represents the union of all flags", also those of the system that O does not name (O\_CLOEXEC, and O\_LARGEFILE, which getfl reports): the bits of a C int. fromWord keeps the bits of all, so that "toWord o fromWord" is "fn w =\> SysWord.andb (w, toWord all)". | [lib/basis/posix\_filesys.sml](../../../../lib/basis/posix_filesys.sml) |
| `Posix.FileSys.S` |  | [lib/basis/posix\_filesys.sml](../../../../lib/basis/posix_filesys.sml) |
| `Posix.IO.FD` | The flags of a descriptor, as words; like the flags of open, all of them are the bits of a C int (Posix.FileSys.O). | [lib/basis/posix\_io.sml](../../../../lib/basis/posix_io.sml) |
| `Posix.IO.O` |  | [lib/basis/posix\_io.sml](../../../../lib/basis/posix_io.sml) |
| `Posix.Process.W` | The flags of waitpid. WNOHANG is not one of them: waitpid\_nh adds it. | [lib/basis/posix\_process.sml](../../../../lib/basis/posix_process.sml) |
| `Posix.TTY.C` |  | [lib/basis/posix\_tty.sml](../../../../lib/basis/posix_tty.sml) |
| `Posix.TTY.I` |  | [lib/basis/posix\_tty.sml](../../../../lib/basis/posix_tty.sml) |
| `Posix.TTY.L` |  | [lib/basis/posix\_tty.sml](../../../../lib/basis/posix_tty.sml) |
| `Posix.TTY.O` |  | [lib/basis/posix\_tty.sml](../../../../lib/basis/posix_tty.sml) |

signature BIT\_FLAGS, transcribed from
<https://smlfamily.github.io/Basis/bit-flags.html>

The flag substructures of the Posix signatures include it:
Posix.FileSys.S (where type flags = mode) and Posix.FileSys.O
(spec-sigs/POSIX\_FILE\_SYS.sml), Posix.IO.FD and Posix.IO.O
(spec-sigs/POSIX\_IO.sml), and Posix.Process.W and the flags of Posix.TTY
on their pages.

## Interface

<pre>
signature BIT_FLAGS =
sig
  eqtype <a href="#type-flags">flags</a>
  val <a href="#val-toword">toWord</a> : flags -&gt; SysWord.word
  val <a href="#val-fromword">fromWord</a> : SysWord.word -&gt; flags
  val <a href="#val-all">all</a> : flags
  val <a href="#val-flags">flags</a> : flags list -&gt; flags
  val <a href="#val-intersect">intersect</a> : flags list -&gt; flags
  val <a href="#val-clear">clear</a> : flags * flags -&gt; flags
  val <a href="#val-allset">allSet</a> : flags * flags -&gt; bool
  val <a href="#val-anyset">anySet</a> : flags * flags -&gt; bool
end
</pre>

### <a name="type-flags"></a>`flags`

```sml
eqtype flags
```

<details><summary>Tests (10)</summary>

For `Posix.Process.W`, in [tests/basis/posix\_process.sml](../../../../tests/basis/posix_process.sml): `empty` &middot; `one` &middot; `union`

For `Posix.FileSys.O`, in [tests/basis/posix\_filesys.sml](../../../../tests/basis/posix_filesys.sml): `append-and-sync`

In [tests/basis/fn/bit\_flags\_fn.sml](../../../../tests/basis/fn/bit_flags_fn.sml), applied to `Posix.Process.W`, `Posix.FileSys.O`, `Posix.FileSys.S`, `Posix.IO.FD`, `Posix.IO.O`, `Posix.TTY.I`, `Posix.TTY.O`, `Posix.TTY.C`, `Posix.TTY.L`: `empty-list` &middot; `singleton` &middot; `idempotent` &middot; `commutative` &middot; `three` &middot; `of-all-named`

</details>

### <a name="val-toword"></a>`toWord`

```sml
val toWord : flags -> SysWord.word
```

<details><summary>Tests (6)</summary>

For `Posix.Process.W`, in [tests/basis/posix\_process.sml](../../../../tests/basis/posix_process.sml): `of-fromWord`

For `Posix.FileSys.S`, in [tests/basis/posix\_filesys.sml](../../../../tests/basis/posix_filesys.sml): `values-of-the-C-binding`

In [tests/basis/fn/bit\_flags\_fn.sml](../../../../tests/basis/fn/bit_flags_fn.sml), applied to `Posix.Process.W`, `Posix.FileSys.O`, `Posix.FileSys.S`, `Posix.IO.FD`, `Posix.IO.O`, `Posix.TTY.I`, `Posix.TTY.O`, `Posix.TTY.C`, `Posix.TTY.L`: `empty-set-is-zero` &middot; `union-is-orb` &middot; `fromWord-of-named` &middot; `union-is-orb-random`

</details>

### <a name="val-fromword"></a>`fromWord`

```sml
val fromWord : SysWord.word -> flags
```

<details><summary>Tests (9)</summary>

For `Posix.Process.W`, in [tests/basis/posix\_process.sml](../../../../tests/basis/posix_process.sml): `of-toWord`

In [tests/basis/fn/bit\_flags\_fn.sml](../../../../tests/basis/fn/bit_flags_fn.sml), applied to `Posix.Process.W`, `Posix.FileSys.O`, `Posix.FileSys.S`, `Posix.IO.FD`, `Posix.IO.O`, `Posix.TTY.I`, `Posix.TTY.O`, `Posix.TTY.C`, `Posix.TTY.L`: `inverts-toWord-on-named` &middot; `inverts-toWord-on-all-and-empty` &middot; `inverts-toWord-random` &middot; `zero-is-empty` &middot; `word-of-all` &middot; `bits-beyond-all` &middot; `random-words-beyond-all` &middot; `result-within-all`

</details>

### <a name="val-all"></a>`all`

```sml
val all : flags
```

<details><summary>Tests (4)</summary>

For `Posix.Process.W`, in [tests/basis/posix\_process.sml](../../../../tests/basis/posix_process.sml): `union-of-all`

In [tests/basis/fn/bit\_flags\_fn.sml](../../../../tests/basis/fn/bit_flags_fn.sml), applied to `Posix.Process.W`, `Posix.FileSys.O`, `Posix.FileSys.S`, `Posix.IO.FD`, `Posix.IO.O`, `Posix.TTY.I`, `Posix.TTY.O`, `Posix.TTY.C`, `Posix.TTY.L`: `contains-named` &middot; `union-with-named` &middot; `not-empty`

</details>

### <a name="val-flags"></a>`flags`

```sml
val flags : flags list -> flags
```

<details><summary>Tests (10)</summary>

For `Posix.Process.W`, in [tests/basis/posix\_process.sml](../../../../tests/basis/posix_process.sml): `empty` &middot; `one` &middot; `union`

For `Posix.FileSys.O`, in [tests/basis/posix\_filesys.sml](../../../../tests/basis/posix_filesys.sml): `append-and-sync`

In [tests/basis/fn/bit\_flags\_fn.sml](../../../../tests/basis/fn/bit_flags_fn.sml), applied to `Posix.Process.W`, `Posix.FileSys.O`, `Posix.FileSys.S`, `Posix.IO.FD`, `Posix.IO.O`, `Posix.TTY.I`, `Posix.TTY.O`, `Posix.TTY.C`, `Posix.TTY.L`: `empty-list` &middot; `singleton` &middot; `idempotent` &middot; `commutative` &middot; `three` &middot; `of-all-named`

</details>

### <a name="val-intersect"></a>`intersect`

```sml
val intersect : flags list -> flags
```

<details><summary>Tests (9)</summary>

For `Posix.Process.W`, in [tests/basis/posix\_process.sml](../../../../tests/basis/posix_process.sml): `empty-is-all` &middot; `two`

In [tests/basis/fn/bit\_flags\_fn.sml](../../../../tests/basis/fn/bit_flags_fn.sml), applied to `Posix.Process.W`, `Posix.FileSys.O`, `Posix.FileSys.S`, `Posix.IO.FD`, `Posix.IO.O`, `Posix.TTY.I`, `Posix.TTY.O`, `Posix.TTY.C`, `Posix.TTY.L`: `empty-list-is-all` &middot; `singleton` &middot; `with-empty` &middot; `with-all` &middot; `is-andb` &middot; `is-andb-random` &middot; `three`

</details>

### <a name="val-clear"></a>`clear`

```sml
val clear : flags * flags -> flags
```

<details><summary>Tests (9)</summary>

For `Posix.Process.W`, in [tests/basis/posix\_process.sml](../../../../tests/basis/posix_process.sml): `difference` &middot; `formula`

In [tests/basis/fn/bit\_flags\_fn.sml](../../../../tests/basis/fn/bit_flags_fn.sml), applied to `Posix.Process.W`, `Posix.FileSys.O`, `Posix.FileSys.S`, `Posix.IO.FD`, `Posix.IO.O`, `Posix.TTY.I`, `Posix.TTY.O`, `Posix.TTY.C`, `Posix.TTY.L`: `definition` &middot; `definition-random` &middot; `self-is-empty` &middot; `empty-clears-nothing` &middot; `all-clears-everything` &middot; `is-set-difference` &middot; `order-of-arguments`

</details>

### <a name="val-allset"></a>`allSet`

```sml
val allSet : flags * flags -> bool
```

<details><summary>Tests (7)</summary>

For `Posix.Process.W`, in [tests/basis/posix\_process.sml](../../../../tests/basis/posix_process.sml): `inclusion`

In [tests/basis/fn/bit\_flags\_fn.sml](../../../../tests/basis/fn/bit_flags_fn.sml), applied to `Posix.Process.W`, `Posix.FileSys.O`, `Posix.FileSys.S`, `Posix.IO.FD`, `Posix.IO.O`, `Posix.TTY.I`, `Posix.TTY.O`, `Posix.TTY.C`, `Posix.TTY.L`: `empty-in-anything` &middot; `reflexive` &middot; `in-union` &middot; `is-inclusion` &middot; `is-inclusion-random` &middot; `order-of-arguments`

</details>

### <a name="val-anyset"></a>`anySet`

```sml
val anySet : flags * flags -> bool
```

<details><summary>Tests (6)</summary>

For `Posix.Process.W`, in [tests/basis/posix\_process.sml](../../../../tests/basis/posix_process.sml): `intersection`

In [tests/basis/fn/bit\_flags\_fn.sml](../../../../tests/basis/fn/bit_flags_fn.sml), applied to `Posix.Process.W`, `Posix.FileSys.O`, `Posix.FileSys.S`, `Posix.IO.FD`, `Posix.IO.O`, `Posix.TTY.I`, `Posix.TTY.O`, `Posix.TTY.C`, `Posix.TTY.L`: `empty-meets-nothing` &middot; `nonempty-meets-itself` &middot; `is-nonempty-intersection` &middot; `is-nonempty-intersection-random` &middot; `symmetric-random`

</details>

---

<sub>Generated by runedoc from lib/basis/sig\_bit\_flags.sml; do not edit.</sub>
