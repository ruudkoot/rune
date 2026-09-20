# signature POSIX_SYS_DB

[The Standard ML Basis Library](../README.md) &rsaquo; **POSIX_SYS_DB**

|  |  |
| --- | --- |
| Status | required |
| Implementations | 1 |
| Documentation | 0 of 18 entries documented |
| Tests | 29 checks of 12 entries |
| Source | [lib/basis/sig\_posix\_sys\_db.sml](../../../../lib/basis/sig_posix_sys_db.sml) |

## Synopsis

```sml
signature POSIX_SYS_DB
structure Posix.SysDB : POSIX_SYS_DB
```

| Implementation |  | Source |
| --- | --- | --- |
| `Posix.SysDB` |  | [lib/basis/posix.sml](../../../../lib/basis/posix.sml) |

signature POSIX\_SYS\_DB, transcribed from
<https://smlfamily.github.io/Basis/posix-sys-db.html>

The types uid and gid are left flexible, as on the page ("identical to
Posix.ProcEnv.uid"): POSIX fixes them (spec-sigs/POSIX.sml).

## Interface

<pre>
signature POSIX_SYS_DB =
sig
  eqtype <a href="#type-uid">uid</a>
  eqtype <a href="#type-gid">gid</a>

  structure <a href="#str-passwd">Passwd</a> :
  sig
    type <a href="#type-passwd.passwd">passwd</a>
    val <a href="#val-passwd.name">name</a> : passwd -&gt; string
    val <a href="#val-passwd.uid">uid</a> : passwd -&gt; uid
    val <a href="#val-passwd.gid">gid</a> : passwd -&gt; gid
    val <a href="#val-passwd.home">home</a> : passwd -&gt; string
    val <a href="#val-passwd.shell">shell</a> : passwd -&gt; string
  end

  structure <a href="#str-group">Group</a> :
  sig
    type <a href="#type-group.group">group</a>
    val <a href="#val-group.name">name</a> : group -&gt; string
    val <a href="#val-group.gid">gid</a> : group -&gt; gid
    val <a href="#val-group.members">members</a> : group -&gt; string list
  end

  val <a href="#val-getgrgid">getgrgid</a> : gid -&gt; Group.group
  val <a href="#val-getgrnam">getgrnam</a> : string -&gt; Group.group
  val <a href="#val-getpwuid">getpwuid</a> : uid -&gt; Passwd.passwd
  val <a href="#val-getpwnam">getpwnam</a> : string -&gt; Passwd.passwd
end
</pre>

### <a name="type-uid"></a>`uid`

```sml
eqtype uid
```

### <a name="type-gid"></a>`gid`

```sml
eqtype gid
```

### <a name="str-passwd"></a>`Passwd`

#### <a name="type-passwd.passwd"></a>`passwd`

```sml
type passwd
```

#### <a name="val-passwd.name"></a>`name`

```sml
val name : passwd -> string
```

<details><summary>Tests (1)</summary>

For `Posix.SysDB`, in [tests/basis/posix\_sysdb.sml](../../../../tests/basis/posix_sysdb.sml): `root`

</details>

#### <a name="val-passwd.uid"></a>`uid`

```sml
val uid : passwd -> uid
```

<details><summary>Tests (2)</summary>

For `Posix.SysDB`, in [tests/basis/posix\_sysdb.sml](../../../../tests/basis/posix_sysdb.sml): `root` &middot; `current-user`

</details>

#### <a name="val-passwd.gid"></a>`gid`

```sml
val gid : passwd -> gid
```

<details><summary>Tests (2)</summary>

For `Posix.SysDB`, in [tests/basis/posix\_sysdb.sml](../../../../tests/basis/posix_sysdb.sml): `root` &middot; `current-user`

</details>

#### <a name="val-passwd.home"></a>`home`

```sml
val home : passwd -> string
```

<details><summary>Tests (2)</summary>

For `Posix.SysDB`, in [tests/basis/posix\_sysdb.sml](../../../../tests/basis/posix_sysdb.sml): `root` &middot; `current-user`

</details>

#### <a name="val-passwd.shell"></a>`shell`

```sml
val shell : passwd -> string
```

<details><summary>Tests (2)</summary>

For `Posix.SysDB`, in [tests/basis/posix\_sysdb.sml](../../../../tests/basis/posix_sysdb.sml): `root` &middot; `current-user`

</details>

### <a name="str-group"></a>`Group`

#### <a name="type-group.group"></a>`group`

```sml
type group
```

#### <a name="val-group.name"></a>`name`

```sml
val name : group -> string
```

<details><summary>Tests (2)</summary>

For `Posix.SysDB`, in [tests/basis/posix\_sysdb.sml](../../../../tests/basis/posix_sysdb.sml): `root` &middot; `current-group`

</details>

#### <a name="val-group.gid"></a>`gid`

```sml
val gid : group -> gid
```

<details><summary>Tests (2)</summary>

For `Posix.SysDB`, in [tests/basis/posix\_sysdb.sml](../../../../tests/basis/posix_sysdb.sml): `root` &middot; `current-group`

</details>

#### <a name="val-group.members"></a>`members`

```sml
val members : group -> string list
```

<details><summary>Tests (3)</summary>

For `Posix.SysDB`, in [tests/basis/posix\_sysdb.sml](../../../../tests/basis/posix_sysdb.sml): `root` &middot; `current-group` &middot; `with-members`

</details>

### <a name="val-getgrgid"></a>`getgrgid`

```sml
val getgrgid : gid -> Group.group
```

<details><summary>Tests (3)</summary>

For `Posix.SysDB`, in [tests/basis/posix\_sysdb.sml](../../../../tests/basis/posix_sysdb.sml): `root` &middot; `current-group` &middot; `unknown` (raises)

</details>

### <a name="val-getgrnam"></a>`getgrnam`

```sml
val getgrnam : string -> Group.group
```

<details><summary>Tests (3)</summary>

For `Posix.SysDB`, in [tests/basis/posix\_sysdb.sml](../../../../tests/basis/posix_sysdb.sml): `root` &middot; `current-group` &middot; `unknown` (raises)

</details>

### <a name="val-getpwuid"></a>`getpwuid`

```sml
val getpwuid : uid -> Passwd.passwd
```

<details><summary>Tests (3)</summary>

For `Posix.SysDB`, in [tests/basis/posix\_sysdb.sml](../../../../tests/basis/posix_sysdb.sml): `root` &middot; `current-user` &middot; `unknown` (raises)

</details>

### <a name="val-getpwnam"></a>`getpwnam`

```sml
val getpwnam : string -> Passwd.passwd
```

<details><summary>Tests (4)</summary>

For `Posix.SysDB`, in [tests/basis/posix\_sysdb.sml](../../../../tests/basis/posix_sysdb.sml): `root` &middot; `current-user` &middot; `unknown` (raises) &middot; `empty` (raises)

</details>

---

<sub>Generated by runedoc from lib/basis/sig\_posix\_sys\_db.sml; do not edit.</sub>
