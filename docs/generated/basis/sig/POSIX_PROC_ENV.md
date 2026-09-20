# signature POSIX_PROC_ENV

[The Standard ML Basis Library](../README.md) &rsaquo; **POSIX_PROC_ENV**

|  |  |
| --- | --- |
| Status | required |
| Documentation | 0 of 30 entries documented |
| Source | [lib/basis/sig\_posix\_proc\_env.sml](../../../../lib/basis/sig_posix_proc_env.sml) |

## Synopsis

```sml
signature POSIX_PROC_ENV
```

signature POSIX\_PROC\_ENV, transcribed from
<https://smlfamily.github.io/Basis/posix-proc-env.html>

The types pid and file\_desc are left flexible, as on the page; POSIX fixes
pid to Process.pid (spec-sigs/POSIX.sml).

## Interface

<pre>
signature POSIX_PROC_ENV =
sig
  eqtype <a href="#type-pid">pid</a>
  eqtype <a href="#type-uid">uid</a>
  eqtype <a href="#type-gid">gid</a>
  eqtype <a href="#type-file_desc">file_desc</a>

  val <a href="#val-uidtoword">uidToWord</a> : uid -&gt; SysWord.word
  val <a href="#val-wordtouid">wordToUid</a> : SysWord.word -&gt; uid
  val <a href="#val-gidtoword">gidToWord</a> : gid -&gt; SysWord.word
  val <a href="#val-wordtogid">wordToGid</a> : SysWord.word -&gt; gid

  val <a href="#val-getpid">getpid</a> : unit -&gt; pid
  val <a href="#val-getppid">getppid</a> : unit -&gt; pid
  val <a href="#val-getuid">getuid</a> : unit -&gt; uid
  val <a href="#val-geteuid">geteuid</a> : unit -&gt; uid
  val <a href="#val-getgid">getgid</a> : unit -&gt; gid
  val <a href="#val-getegid">getegid</a> : unit -&gt; gid

  val <a href="#val-setuid">setuid</a> : uid -&gt; unit
  val <a href="#val-setgid">setgid</a> : gid -&gt; unit

  val <a href="#val-getgroups">getgroups</a> : unit -&gt; gid list
  val <a href="#val-getlogin">getlogin</a> : unit -&gt; string

  val <a href="#val-getpgrp">getpgrp</a> : unit -&gt; pid
  val <a href="#val-setsid">setsid</a> : unit -&gt; pid
  val <a href="#val-setpgid">setpgid</a> : {<a href="#fld-setpgid.pid">pid</a> : pid option, <a href="#fld-setpgid.pgid">pgid</a> : pid option} -&gt; unit

  val <a href="#val-uname">uname</a> : unit -&gt; (string * string) list

  val <a href="#val-time">time</a> : unit -&gt; Time.time
  val <a href="#val-times">times</a> : unit
              -&gt; {<a href="#fld-times.elapsed">elapsed</a> : Time.time,
                  <a href="#fld-times.utime">utime</a> : Time.time,
                  <a href="#fld-times.stime">stime</a> : Time.time,
                  <a href="#fld-times.cutime">cutime</a> : Time.time,
                  <a href="#fld-times.cstime">cstime</a> : Time.time}

  val <a href="#val-getenv">getenv</a> : string -&gt; string option
  val <a href="#val-environ">environ</a> : unit -&gt; string list

  val <a href="#val-ctermid">ctermid</a> : unit -&gt; string
  val <a href="#val-ttyname">ttyname</a> : file_desc -&gt; string
  val <a href="#val-isatty">isatty</a> : file_desc -&gt; bool

  val <a href="#val-sysconf">sysconf</a> : string -&gt; SysWord.word
end
</pre>

### <a name="type-pid"></a>`pid`

```sml
eqtype pid
```

### <a name="type-uid"></a>`uid`

```sml
eqtype uid
```

### <a name="type-gid"></a>`gid`

```sml
eqtype gid
```

### <a name="type-file_desc"></a>`file_desc`

```sml
eqtype file_desc
```

### <a name="val-uidtoword"></a>`uidToWord`

```sml
val uidToWord : uid -> SysWord.word
```

### <a name="val-wordtouid"></a>`wordToUid`

```sml
val wordToUid : SysWord.word -> uid
```

### <a name="val-gidtoword"></a>`gidToWord`

```sml
val gidToWord : gid -> SysWord.word
```

### <a name="val-wordtogid"></a>`wordToGid`

```sml
val wordToGid : SysWord.word -> gid
```

### <a name="val-getpid"></a>`getpid`

```sml
val getpid : unit -> pid
```

### <a name="val-getppid"></a>`getppid`

```sml
val getppid : unit -> pid
```

### <a name="val-getuid"></a>`getuid`

```sml
val getuid : unit -> uid
```

### <a name="val-geteuid"></a>`geteuid`

```sml
val geteuid : unit -> uid
```

### <a name="val-getgid"></a>`getgid`

```sml
val getgid : unit -> gid
```

### <a name="val-getegid"></a>`getegid`

```sml
val getegid : unit -> gid
```

### <a name="val-setuid"></a>`setuid`

```sml
val setuid : uid -> unit
```

### <a name="val-setgid"></a>`setgid`

```sml
val setgid : gid -> unit
```

### <a name="val-getgroups"></a>`getgroups`

```sml
val getgroups : unit -> gid list
```

### <a name="val-getlogin"></a>`getlogin`

```sml
val getlogin : unit -> string
```

### <a name="val-getpgrp"></a>`getpgrp`

```sml
val getpgrp : unit -> pid
```

### <a name="val-setsid"></a>`setsid`

```sml
val setsid : unit -> pid
```

### <a name="val-setpgid"></a>`setpgid`

```sml
val setpgid : {pid : pid option, pgid : pid option} -> unit
```

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-setpgid.pid"></a>`pid` | `pid option` |  |
| <a name="fld-setpgid.pgid"></a>`pgid` | `pid option` |  |

### <a name="val-uname"></a>`uname`

```sml
val uname : unit -> (string * string) list
```

### <a name="val-time"></a>`time`

```sml
val time : unit -> Time.time
```

### <a name="val-times"></a>`times`

```sml
val times : unit
            -> {elapsed : Time.time,
                utime : Time.time,
                stime : Time.time,
                cutime : Time.time,
                cstime : Time.time}
```

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-times.elapsed"></a>`elapsed` | `Time.time` |  |
| <a name="fld-times.utime"></a>`utime` | `Time.time` |  |
| <a name="fld-times.stime"></a>`stime` | `Time.time` |  |
| <a name="fld-times.cutime"></a>`cutime` | `Time.time` |  |
| <a name="fld-times.cstime"></a>`cstime` | `Time.time` |  |

### <a name="val-getenv"></a>`getenv`

```sml
val getenv : string -> string option
```

### <a name="val-environ"></a>`environ`

```sml
val environ : unit -> string list
```

### <a name="val-ctermid"></a>`ctermid`

```sml
val ctermid : unit -> string
```

### <a name="val-ttyname"></a>`ttyname`

```sml
val ttyname : file_desc -> string
```

### <a name="val-isatty"></a>`isatty`

```sml
val isatty : file_desc -> bool
```

### <a name="val-sysconf"></a>`sysconf`

```sml
val sysconf : string -> SysWord.word
```

---

<sub>Generated by runedoc from lib/basis/sig\_posix\_proc\_env.sml; do not edit.</sub>
