# signature POSIX_ERROR

[The Standard ML Basis Library](../README.md) &rsaquo; **POSIX_ERROR**

|  |  |
| --- | --- |
| Status | required |
| Implementations | 1 |
| Documentation | 0 of 49 entries documented |
| Tests | 81 checks of 49 entries |
| Source | [lib/basis/sig\_posix\_error.sml](../../../../lib/basis/sig_posix_error.sml) |

## Synopsis

```sml
signature POSIX_ERROR
structure Posix.Error : POSIX_ERROR
```

| Implementation |  | Source |
| --- | --- | --- |
| `Posix.Error` |  | [lib/basis/posix.sml](../../../../lib/basis/posix.sml) |

signature POSIX\_ERROR, transcribed from
<https://smlfamily.github.io/Basis/posix-error.html>

The page writes `eqtype syserror = OS.Process.syserror`. OS.Process has no
type syserror, and the description says the type "is identical to the type
OS.syserror"; SML '97 has no `eqtype t = ty` specification either, so it is
written `type syserror = OS.syserror`, which is an equality type.

## Interface

<pre>
signature POSIX_ERROR =
sig
  type <a href="#type-syserror">syserror</a> = OS.syserror

  val <a href="#val-toword">toWord</a> : syserror -&gt; SysWord.word
  val <a href="#val-fromword">fromWord</a> : SysWord.word -&gt; syserror

  val <a href="#val-errormsg">errorMsg</a> : syserror -&gt; string
  val <a href="#val-errorname">errorName</a> : syserror -&gt; string
  val <a href="#val-syserror">syserror</a> : string -&gt; syserror option

  val <a href="#val-acces">acces</a> : syserror
  val <a href="#val-again">again</a> : syserror
  val <a href="#val-badf">badf</a> : syserror
  val <a href="#val-badmsg">badmsg</a> : syserror
  val <a href="#val-busy">busy</a> : syserror
  val <a href="#val-canceled">canceled</a> : syserror
  val <a href="#val-child">child</a> : syserror
  val <a href="#val-deadlk">deadlk</a> : syserror
  val <a href="#val-dom">dom</a> : syserror
  val <a href="#val-exist">exist</a> : syserror
  val <a href="#val-fault">fault</a> : syserror
  val <a href="#val-fbig">fbig</a> : syserror
  val <a href="#val-inprogress">inprogress</a> : syserror
  val <a href="#val-intr">intr</a> : syserror
  val <a href="#val-inval">inval</a> : syserror
  val <a href="#val-io">io</a> : syserror
  val <a href="#val-isdir">isdir</a> : syserror
  val <a href="#val-loop">loop</a> : syserror
  val <a href="#val-mfile">mfile</a> : syserror
  val <a href="#val-mlink">mlink</a> : syserror
  val <a href="#val-msgsize">msgsize</a> : syserror
  val <a href="#val-nametoolong">nametoolong</a> : syserror
  val <a href="#val-nfile">nfile</a> : syserror
  val <a href="#val-nodev">nodev</a> : syserror
  val <a href="#val-noent">noent</a> : syserror
  val <a href="#val-noexec">noexec</a> : syserror
  val <a href="#val-nolck">nolck</a> : syserror
  val <a href="#val-nomem">nomem</a> : syserror
  val <a href="#val-nospc">nospc</a> : syserror
  val <a href="#val-nosys">nosys</a> : syserror
  val <a href="#val-notdir">notdir</a> : syserror
  val <a href="#val-notempty">notempty</a> : syserror
  val <a href="#val-notsup">notsup</a> : syserror
  val <a href="#val-notty">notty</a> : syserror
  val <a href="#val-nxio">nxio</a> : syserror
  val <a href="#val-perm">perm</a> : syserror
  val <a href="#val-pipe">pipe</a> : syserror
  val <a href="#val-range">range</a> : syserror
  val <a href="#val-rofs">rofs</a> : syserror
  val <a href="#val-spipe">spipe</a> : syserror
  val <a href="#val-srch">srch</a> : syserror
  val <a href="#val-toobig">toobig</a> : syserror
  val <a href="#val-xdev">xdev</a> : syserror
end
</pre>

### <a name="type-syserror"></a>`syserror`

```sml
type syserror = OS.syserror
```

<details><summary>Tests (4)</summary>

For `Posix.Error`, in [tests/basis/posix\_error.sml](../../../../tests/basis/posix_error.sml): `inverts-errorName-all` &middot; `unknown-name` &middot; `empty-name` &middot; `is-OS.syserror`

</details>

### <a name="val-toword"></a>`toWord`

```sml
val toWord : syserror -> SysWord.word
```

<details><summary>Tests (2)</summary>

For `Posix.Error`, in [tests/basis/posix\_error.sml](../../../../tests/basis/posix_error.sml): `distinct-words` &middot; `nonzero`

</details>

### <a name="val-fromword"></a>`fromWord`

```sml
val fromWord : SysWord.word -> syserror
```

<details><summary>Tests (2)</summary>

For `Posix.Error`, in [tests/basis/posix\_error.sml](../../../../tests/basis/posix_error.sml): `no-validation` &middot; `of-toWord`

</details>

### <a name="val-errormsg"></a>`errorMsg`

```sml
val errorMsg : syserror -> string
```

<details><summary>Tests (4)</summary>

For `Posix.Error`, in [tests/basis/posix\_error.sml](../../../../tests/basis/posix_error.sml): `is-OS.errorMsg` &middot; `nonempty` &middot; `differ` &middot; `of-SysErr`

</details>

### <a name="val-errorname"></a>`errorName`

```sml
val errorName : syserror -> string
```

<details><summary>Tests (4)</summary>

For `Posix.Error`, in [tests/basis/posix\_error.sml](../../../../tests/basis/posix_error.sml): `distinct-errors` &middot; `distinct-names` &middot; `badmsg` &middot; `toobig-not-2big`

</details>

### <a name="val-syserror"></a>`syserror`

```sml
val syserror : string -> syserror option
```

<details><summary>Tests (4)</summary>

For `Posix.Error`, in [tests/basis/posix\_error.sml](../../../../tests/basis/posix_error.sml): `inverts-errorName-all` &middot; `unknown-name` &middot; `empty-name` &middot; `is-OS.syserror`

</details>

### <a name="val-acces"></a>`acces`

```sml
val acces : syserror
```

<details><summary>Tests (2)</summary>

For `Posix.Error`, in [tests/basis/posix\_error.sml](../../../../tests/basis/posix_error.sml): `*` &middot; `open-unreadable-file`

</details>

### <a name="val-again"></a>`again`

```sml
val again : syserror
```

<details><summary>Tests (1)</summary>

For `Posix.Error`, in [tests/basis/posix\_error.sml](../../../../tests/basis/posix_error.sml): `*`

</details>

### <a name="val-badf"></a>`badf`

```sml
val badf : syserror
```

<details><summary>Tests (2)</summary>

For `Posix.Error`, in [tests/basis/posix\_error.sml](../../../../tests/basis/posix_error.sml): `*` &middot; `close-twice`

</details>

### <a name="val-badmsg"></a>`badmsg`

```sml
val badmsg : syserror
```

<details><summary>Tests (1)</summary>

For `Posix.Error`, in [tests/basis/posix\_error.sml](../../../../tests/basis/posix_error.sml): `*`

</details>

### <a name="val-busy"></a>`busy`

```sml
val busy : syserror
```

<details><summary>Tests (1)</summary>

For `Posix.Error`, in [tests/basis/posix\_error.sml](../../../../tests/basis/posix_error.sml): `*`

</details>

### <a name="val-canceled"></a>`canceled`

```sml
val canceled : syserror
```

<details><summary>Tests (1)</summary>

For `Posix.Error`, in [tests/basis/posix\_error.sml](../../../../tests/basis/posix_error.sml): `*`

</details>

### <a name="val-child"></a>`child`

```sml
val child : syserror
```

<details><summary>Tests (2)</summary>

For `Posix.Error`, in [tests/basis/posix\_error.sml](../../../../tests/basis/posix_error.sml): `*` &middot; `wait-without-children`

</details>

### <a name="val-deadlk"></a>`deadlk`

```sml
val deadlk : syserror
```

<details><summary>Tests (1)</summary>

For `Posix.Error`, in [tests/basis/posix\_error.sml](../../../../tests/basis/posix_error.sml): `*`

</details>

### <a name="val-dom"></a>`dom`

```sml
val dom : syserror
```

<details><summary>Tests (1)</summary>

For `Posix.Error`, in [tests/basis/posix\_error.sml](../../../../tests/basis/posix_error.sml): `*`

</details>

### <a name="val-exist"></a>`exist`

```sml
val exist : syserror
```

<details><summary>Tests (2)</summary>

For `Posix.Error`, in [tests/basis/posix\_error.sml](../../../../tests/basis/posix_error.sml): `*` &middot; `mkDir-twice`

</details>

### <a name="val-fault"></a>`fault`

```sml
val fault : syserror
```

<details><summary>Tests (1)</summary>

For `Posix.Error`, in [tests/basis/posix\_error.sml](../../../../tests/basis/posix_error.sml): `*`

</details>

### <a name="val-fbig"></a>`fbig`

```sml
val fbig : syserror
```

<details><summary>Tests (1)</summary>

For `Posix.Error`, in [tests/basis/posix\_error.sml](../../../../tests/basis/posix_error.sml): `*`

</details>

### <a name="val-inprogress"></a>`inprogress`

```sml
val inprogress : syserror
```

<details><summary>Tests (1)</summary>

For `Posix.Error`, in [tests/basis/posix\_error.sml](../../../../tests/basis/posix_error.sml): `*`

</details>

### <a name="val-intr"></a>`intr`

```sml
val intr : syserror
```

<details><summary>Tests (1)</summary>

For `Posix.Error`, in [tests/basis/posix\_error.sml](../../../../tests/basis/posix_error.sml): `*`

</details>

### <a name="val-inval"></a>`inval`

```sml
val inval : syserror
```

<details><summary>Tests (2)</summary>

For `Posix.Error`, in [tests/basis/posix\_error.sml](../../../../tests/basis/posix_error.sml): `*` &middot; `rename-into-itself`

</details>

### <a name="val-io"></a>`io`

```sml
val io : syserror
```

<details><summary>Tests (1)</summary>

For `Posix.Error`, in [tests/basis/posix\_error.sml](../../../../tests/basis/posix_error.sml): `*`

</details>

### <a name="val-isdir"></a>`isdir`

```sml
val isdir : syserror
```

<details><summary>Tests (2)</summary>

For `Posix.Error`, in [tests/basis/posix\_error.sml](../../../../tests/basis/posix_error.sml): `*` &middot; `open-directory-for-writing`

</details>

### <a name="val-loop"></a>`loop`

```sml
val loop : syserror
```

<details><summary>Tests (2)</summary>

For `Posix.Error`, in [tests/basis/posix\_error.sml](../../../../tests/basis/posix_error.sml): `*` &middot; `symbolic-link-loop`

</details>

### <a name="val-mfile"></a>`mfile`

```sml
val mfile : syserror
```

<details><summary>Tests (1)</summary>

For `Posix.Error`, in [tests/basis/posix\_error.sml](../../../../tests/basis/posix_error.sml): `*`

</details>

### <a name="val-mlink"></a>`mlink`

```sml
val mlink : syserror
```

<details><summary>Tests (1)</summary>

For `Posix.Error`, in [tests/basis/posix\_error.sml](../../../../tests/basis/posix_error.sml): `*`

</details>

### <a name="val-msgsize"></a>`msgsize`

```sml
val msgsize : syserror
```

<details><summary>Tests (1)</summary>

For `Posix.Error`, in [tests/basis/posix\_error.sml](../../../../tests/basis/posix_error.sml): `*`

</details>

### <a name="val-nametoolong"></a>`nametoolong`

```sml
val nametoolong : syserror
```

<details><summary>Tests (2)</summary>

For `Posix.Error`, in [tests/basis/posix\_error.sml](../../../../tests/basis/posix_error.sml): `*` &middot; `long-file-name`

</details>

### <a name="val-nfile"></a>`nfile`

```sml
val nfile : syserror
```

<details><summary>Tests (1)</summary>

For `Posix.Error`, in [tests/basis/posix\_error.sml](../../../../tests/basis/posix_error.sml): `*`

</details>

### <a name="val-nodev"></a>`nodev`

```sml
val nodev : syserror
```

<details><summary>Tests (1)</summary>

For `Posix.Error`, in [tests/basis/posix\_error.sml](../../../../tests/basis/posix_error.sml): `*`

</details>

### <a name="val-noent"></a>`noent`

```sml
val noent : syserror
```

<details><summary>Tests (2)</summary>

For `Posix.Error`, in [tests/basis/posix\_error.sml](../../../../tests/basis/posix_error.sml): `*` &middot; `open-missing-file`

</details>

### <a name="val-noexec"></a>`noexec`

```sml
val noexec : syserror
```

<details><summary>Tests (2)</summary>

For `Posix.Error`, in [tests/basis/posix\_error.sml](../../../../tests/basis/posix_error.sml): `*` &middot; `exec-of-data`

</details>

### <a name="val-nolck"></a>`nolck`

```sml
val nolck : syserror
```

<details><summary>Tests (1)</summary>

For `Posix.Error`, in [tests/basis/posix\_error.sml](../../../../tests/basis/posix_error.sml): `*`

</details>

### <a name="val-nomem"></a>`nomem`

```sml
val nomem : syserror
```

<details><summary>Tests (1)</summary>

For `Posix.Error`, in [tests/basis/posix\_error.sml](../../../../tests/basis/posix_error.sml): `*`

</details>

### <a name="val-nospc"></a>`nospc`

```sml
val nospc : syserror
```

<details><summary>Tests (1)</summary>

For `Posix.Error`, in [tests/basis/posix\_error.sml](../../../../tests/basis/posix_error.sml): `*`

</details>

### <a name="val-nosys"></a>`nosys`

```sml
val nosys : syserror
```

<details><summary>Tests (1)</summary>

For `Posix.Error`, in [tests/basis/posix\_error.sml](../../../../tests/basis/posix_error.sml): `*`

</details>

### <a name="val-notdir"></a>`notdir`

```sml
val notdir : syserror
```

<details><summary>Tests (2)</summary>

For `Posix.Error`, in [tests/basis/posix\_error.sml](../../../../tests/basis/posix_error.sml): `*` &middot; `path-through-file`

</details>

### <a name="val-notempty"></a>`notempty`

```sml
val notempty : syserror
```

<details><summary>Tests (2)</summary>

For `Posix.Error`, in [tests/basis/posix\_error.sml](../../../../tests/basis/posix_error.sml): `*` &middot; `rmDir-nonempty`

</details>

### <a name="val-notsup"></a>`notsup`

```sml
val notsup : syserror
```

<details><summary>Tests (1)</summary>

For `Posix.Error`, in [tests/basis/posix\_error.sml](../../../../tests/basis/posix_error.sml): `*`

</details>

### <a name="val-notty"></a>`notty`

```sml
val notty : syserror
```

<details><summary>Tests (2)</summary>

For `Posix.Error`, in [tests/basis/posix\_error.sml](../../../../tests/basis/posix_error.sml): `*` &middot; `ttyname-of-dev-null`

</details>

### <a name="val-nxio"></a>`nxio`

```sml
val nxio : syserror
```

<details><summary>Tests (1)</summary>

For `Posix.Error`, in [tests/basis/posix\_error.sml](../../../../tests/basis/posix_error.sml): `*`

</details>

### <a name="val-perm"></a>`perm`

```sml
val perm : syserror
```

<details><summary>Tests (2)</summary>

For `Posix.Error`, in [tests/basis/posix\_error.sml](../../../../tests/basis/posix_error.sml): `*` &middot; `setuid-root`

</details>

### <a name="val-pipe"></a>`pipe`

```sml
val pipe : syserror
```

<details><summary>Tests (2)</summary>

For `Posix.Error`, in [tests/basis/posix\_error.sml](../../../../tests/basis/posix_error.sml): `*` &middot; `write-without-reader`

</details>

### <a name="val-range"></a>`range`

```sml
val range : syserror
```

<details><summary>Tests (1)</summary>

For `Posix.Error`, in [tests/basis/posix\_error.sml](../../../../tests/basis/posix_error.sml): `*`

</details>

### <a name="val-rofs"></a>`rofs`

```sml
val rofs : syserror
```

<details><summary>Tests (1)</summary>

For `Posix.Error`, in [tests/basis/posix\_error.sml](../../../../tests/basis/posix_error.sml): `*`

</details>

### <a name="val-spipe"></a>`spipe`

```sml
val spipe : syserror
```

<details><summary>Tests (2)</summary>

For `Posix.Error`, in [tests/basis/posix\_error.sml](../../../../tests/basis/posix_error.sml): `*` &middot; `lseek-on-pipe`

</details>

### <a name="val-srch"></a>`srch`

```sml
val srch : syserror
```

<details><summary>Tests (2)</summary>

For `Posix.Error`, in [tests/basis/posix\_error.sml](../../../../tests/basis/posix_error.sml): `*` &middot; `kill-reaped-child`

</details>

### <a name="val-toobig"></a>`toobig`

```sml
val toobig : syserror
```

<details><summary>Tests (2)</summary>

For `Posix.Error`, in [tests/basis/posix\_error.sml](../../../../tests/basis/posix_error.sml): `*` &middot; `exec-huge-argument`

</details>

### <a name="val-xdev"></a>`xdev`

```sml
val xdev : syserror
```

<details><summary>Tests (1)</summary>

For `Posix.Error`, in [tests/basis/posix\_error.sml](../../../../tests/basis/posix_error.sml): `*`

</details>

---

<sub>Generated by runedoc from lib/basis/sig\_posix\_error.sml; do not edit.</sub>
