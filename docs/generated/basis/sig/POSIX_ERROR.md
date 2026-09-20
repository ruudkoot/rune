# signature POSIX_ERROR

[The Standard ML Basis Library](../README.md) &rsaquo; **POSIX_ERROR**

|  |  |
| --- | --- |
| Status | required |
| Documentation | 0 of 49 entries documented |
| Source | [lib/basis/sig\_posix\_error.sml](../../../../lib/basis/sig_posix_error.sml) |

## Synopsis

```sml
signature POSIX_ERROR
```

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

### <a name="val-toword"></a>`toWord`

```sml
val toWord : syserror -> SysWord.word
```

### <a name="val-fromword"></a>`fromWord`

```sml
val fromWord : SysWord.word -> syserror
```

### <a name="val-errormsg"></a>`errorMsg`

```sml
val errorMsg : syserror -> string
```

### <a name="val-errorname"></a>`errorName`

```sml
val errorName : syserror -> string
```

### <a name="val-syserror"></a>`syserror`

```sml
val syserror : string -> syserror option
```

### <a name="val-acces"></a>`acces`

```sml
val acces : syserror
```

### <a name="val-again"></a>`again`

```sml
val again : syserror
```

### <a name="val-badf"></a>`badf`

```sml
val badf : syserror
```

### <a name="val-badmsg"></a>`badmsg`

```sml
val badmsg : syserror
```

### <a name="val-busy"></a>`busy`

```sml
val busy : syserror
```

### <a name="val-canceled"></a>`canceled`

```sml
val canceled : syserror
```

### <a name="val-child"></a>`child`

```sml
val child : syserror
```

### <a name="val-deadlk"></a>`deadlk`

```sml
val deadlk : syserror
```

### <a name="val-dom"></a>`dom`

```sml
val dom : syserror
```

### <a name="val-exist"></a>`exist`

```sml
val exist : syserror
```

### <a name="val-fault"></a>`fault`

```sml
val fault : syserror
```

### <a name="val-fbig"></a>`fbig`

```sml
val fbig : syserror
```

### <a name="val-inprogress"></a>`inprogress`

```sml
val inprogress : syserror
```

### <a name="val-intr"></a>`intr`

```sml
val intr : syserror
```

### <a name="val-inval"></a>`inval`

```sml
val inval : syserror
```

### <a name="val-io"></a>`io`

```sml
val io : syserror
```

### <a name="val-isdir"></a>`isdir`

```sml
val isdir : syserror
```

### <a name="val-loop"></a>`loop`

```sml
val loop : syserror
```

### <a name="val-mfile"></a>`mfile`

```sml
val mfile : syserror
```

### <a name="val-mlink"></a>`mlink`

```sml
val mlink : syserror
```

### <a name="val-msgsize"></a>`msgsize`

```sml
val msgsize : syserror
```

### <a name="val-nametoolong"></a>`nametoolong`

```sml
val nametoolong : syserror
```

### <a name="val-nfile"></a>`nfile`

```sml
val nfile : syserror
```

### <a name="val-nodev"></a>`nodev`

```sml
val nodev : syserror
```

### <a name="val-noent"></a>`noent`

```sml
val noent : syserror
```

### <a name="val-noexec"></a>`noexec`

```sml
val noexec : syserror
```

### <a name="val-nolck"></a>`nolck`

```sml
val nolck : syserror
```

### <a name="val-nomem"></a>`nomem`

```sml
val nomem : syserror
```

### <a name="val-nospc"></a>`nospc`

```sml
val nospc : syserror
```

### <a name="val-nosys"></a>`nosys`

```sml
val nosys : syserror
```

### <a name="val-notdir"></a>`notdir`

```sml
val notdir : syserror
```

### <a name="val-notempty"></a>`notempty`

```sml
val notempty : syserror
```

### <a name="val-notsup"></a>`notsup`

```sml
val notsup : syserror
```

### <a name="val-notty"></a>`notty`

```sml
val notty : syserror
```

### <a name="val-nxio"></a>`nxio`

```sml
val nxio : syserror
```

### <a name="val-perm"></a>`perm`

```sml
val perm : syserror
```

### <a name="val-pipe"></a>`pipe`

```sml
val pipe : syserror
```

### <a name="val-range"></a>`range`

```sml
val range : syserror
```

### <a name="val-rofs"></a>`rofs`

```sml
val rofs : syserror
```

### <a name="val-spipe"></a>`spipe`

```sml
val spipe : syserror
```

### <a name="val-srch"></a>`srch`

```sml
val srch : syserror
```

### <a name="val-toobig"></a>`toobig`

```sml
val toobig : syserror
```

### <a name="val-xdev"></a>`xdev`

```sml
val xdev : syserror
```

---

<sub>Generated by runedoc from lib/basis/sig\_posix\_error.sml; do not edit.</sub>
