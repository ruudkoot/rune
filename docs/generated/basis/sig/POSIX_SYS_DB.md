# signature POSIX_SYS_DB

[The Standard ML Basis Library](../README.md) &rsaquo; The operating system &rsaquo; **POSIX_SYS_DB**

|  |  |
| --- | --- |
| Status | required |
| Implementations | 1 |
| Documentation | 18 of 18 entries documented |
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

The password and group databases: turning a user or group name into a
number, and back.

These read what the system keeps about its users and groups -- on a
classic Unix the files `/etc/passwd` and `/etc/group`, and in general
whatever the system's name service offers. They do not change anything.

> **Erratum** `POSIX_SYS_DB/flexible-types`. The types [`uid`](#type-uid) and [`gid`](#type-gid) are left
> flexible here, as on the page, which says only that they are "identical to
> [`Posix.ProcEnv.uid`](../sig/POSIX_PROC_ENV.md#type-uid)"; [`POSIX`](../sig/POSIX.md) fixes them.

> **Implementation** `Posix.SysDB/what-a-check-can-assume`. The suite assumes
> that the user and the group numbered 0 exist and are called `root`, which
> holds on Linux and the BSDs, and compares the other fields with what
> `getent` prints.

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

The type of the number that names a user, the one of [`Posix.ProcEnv`](../sig/POSIX.md#str-procenv).

### <a name="type-gid"></a>`gid`

```sml
eqtype gid
```

The type of the number that names a group.

### <a name="str-passwd"></a>`Passwd`

What the system knows about a user.

#### <a name="type-passwd.passwd"></a>`passwd`

```sml
type passwd
```

The type of an entry of the password database.

#### <a name="val-passwd.name"></a>`name`

```sml
val name : passwd -> string
```

`name pw` is the login name of `pw`.

<details><summary>Tests (1)</summary>

For `Posix.SysDB`, in [tests/basis/posix\_sysdb.sml](../../../../tests/basis/posix_sysdb.sml): `root`

</details>

#### <a name="val-passwd.uid"></a>`uid`

```sml
val uid : passwd -> uid
```

`uid pw` is the number of the user `pw`.

<details><summary>Tests (2)</summary>

For `Posix.SysDB`, in [tests/basis/posix\_sysdb.sml](../../../../tests/basis/posix_sysdb.sml): `root` &middot; `current-user`

</details>

#### <a name="val-passwd.gid"></a>`gid`

```sml
val gid : passwd -> gid
```

`gid pw` is the number of that user's own group.

<details><summary>Tests (2)</summary>

For `Posix.SysDB`, in [tests/basis/posix\_sysdb.sml](../../../../tests/basis/posix_sysdb.sml): `root` &middot; `current-user`

</details>

#### <a name="val-passwd.home"></a>`home`

```sml
val home : passwd -> string
```

`home pw` is the path of that user's home directory.

<details><summary>Tests (2)</summary>

For `Posix.SysDB`, in [tests/basis/posix\_sysdb.sml](../../../../tests/basis/posix_sysdb.sml): `root` &middot; `current-user`

</details>

#### <a name="val-passwd.shell"></a>`shell`

```sml
val shell : passwd -> string
```

`shell pw` is the path of the program that user gets at login.

<details><summary>Tests (2)</summary>

For `Posix.SysDB`, in [tests/basis/posix\_sysdb.sml](../../../../tests/basis/posix_sysdb.sml): `root` &middot; `current-user`

</details>

### <a name="str-group"></a>`Group`

What the system knows about a group.

#### <a name="type-group.group"></a>`group`

```sml
type group
```

The type of an entry of the group database.

#### <a name="val-group.name"></a>`name`

```sml
val name : group -> string
```

`name gr` is the name of `gr`.

<details><summary>Tests (2)</summary>

For `Posix.SysDB`, in [tests/basis/posix\_sysdb.sml](../../../../tests/basis/posix_sysdb.sml): `root` &middot; `current-group`

</details>

#### <a name="val-group.gid"></a>`gid`

```sml
val gid : group -> gid
```

`gid gr` is the number of the group `gr`.

<details><summary>Tests (2)</summary>

For `Posix.SysDB`, in [tests/basis/posix\_sysdb.sml](../../../../tests/basis/posix_sysdb.sml): `root` &middot; `current-group`

</details>

#### <a name="val-group.members"></a>`members`

```sml
val members : group -> string list
```

`members gr` is the login names of the users that belong to `gr` besides those whose own group it is.

<details><summary>Tests (3)</summary>

For `Posix.SysDB`, in [tests/basis/posix\_sysdb.sml](../../../../tests/basis/posix_sysdb.sml): `root` &middot; `current-group` &middot; `with-members`

</details>

### <a name="val-getgrgid"></a>`getgrgid`

```sml
val getgrgid : gid -> Group.group
```

`getgrgid g` is what the system knows about the group numbered `g`.

**Raises** [`OS.SysErr`](../sig/OS.md#exn-syserr) if there is no such group.

<details><summary>Tests (3)</summary>

For `Posix.SysDB`, in [tests/basis/posix\_sysdb.sml](../../../../tests/basis/posix_sysdb.sml): `root` &middot; `current-group` &middot; `unknown` (raises)

</details>

### <a name="val-getgrnam"></a>`getgrnam`

```sml
val getgrnam : string -> Group.group
```

`getgrnam name` is what the system knows about the group called `name`.

**Raises** [`OS.SysErr`](../sig/OS.md#exn-syserr) if there is no such group, and at once for an empty
name.

<details><summary>Tests (3)</summary>

For `Posix.SysDB`, in [tests/basis/posix\_sysdb.sml](../../../../tests/basis/posix_sysdb.sml): `root` &middot; `current-group` &middot; `unknown` (raises)

</details>

### <a name="val-getpwuid"></a>`getpwuid`

```sml
val getpwuid : uid -> Passwd.passwd
```

`getpwuid u` is what the system knows about the user numbered `u`.

**Raises** [`OS.SysErr`](../sig/OS.md#exn-syserr) if there is no such user.

> **Reading** `Posix.SysDB/missing-raises-SysErr`. The C library reports a
> name it does not find without setting an `errno`; this raises
> [`OS.SysErr`](../sig/OS.md#exn-syserr) for it all the same, since the alternative would be to
> return something that names nobody.

<details><summary>Tests (3)</summary>

For `Posix.SysDB`, in [tests/basis/posix\_sysdb.sml](../../../../tests/basis/posix_sysdb.sml): `root` &middot; `current-user` &middot; `unknown` (raises)

</details>

### <a name="val-getpwnam"></a>`getpwnam`

```sml
val getpwnam : string -> Passwd.passwd
```

`getpwnam name` is what the system knows about the user called `name`.

**Raises** [`OS.SysErr`](../sig/OS.md#exn-syserr) if there is no such user, and at once for an empty
name, which the primitive would otherwise take for a lookup by
number.

<details><summary>Tests (4)</summary>

For `Posix.SysDB`, in [tests/basis/posix\_sysdb.sml](../../../../tests/basis/posix_sysdb.sml): `root` &middot; `current-user` &middot; `unknown` (raises) &middot; `empty` (raises)

</details>

## See also

[`POSIX_PROC_ENV`](../sig/POSIX_PROC_ENV.md), [`POSIX`](../sig/POSIX.md), [`POSIX_FILE_SYS`](../sig/POSIX_FILE_SYS.md)

---

<sub>Generated by runedoc from lib/basis/sig\_posix\_sys\_db.sml; do not edit.</sub>
