# signature WINDOWS

[The Standard ML Basis Library](../README.md) &rsaquo; The operating system &rsaquo; **WINDOWS**

|  |  |
| --- | --- |
| Status | optional |
| Implementations | 1 |
| Documentation | 88 of 88 entries documented |
| Tests | 84 checks of 78 entries |
| Source | [lib/basis/sig\_windows.sml](../../../../lib/basis/sig_windows.sml) |

## Synopsis

```sml
signature WINDOWS
structure Windows : WINDOWS  (* optional *)
```

| Implementation |  | Source |
| --- | --- | --- |
| `Windows` | Windows: the registry, the configuration of the machine, DDE, programs started with pipes to them, and the codes a process ends with, over the primitives win\_\* of vm/prims.def. On a system other than Windows every call of the system raises OS.SysErr with ENOSYS; the constants (the flags of Key, the codes of Status) are there everywhere. | [lib/basis/windows.sml](../../../../lib/basis/windows.sml) |

The operating system Windows: the registry, the configuration of the
machine, dynamic data exchange, programs started with a pipe each way, and
the codes a process ends with.

The structure is there on every system, so a program that names it
compiles anywhere. What asks Windows raises [`OS.SysErr`](../sig/OS.md#exn-syserr) on a system that
is not Windows, with the error `ENOSYS`: all of [`Reg`](#str-reg), the values
[`Config`](#str-config) reads from the machine, [`DDE`](#str-dde), [`execute`](#val-execute) and the group around
it, [`getVolumeInformation`](#val-getvolumeinformation), [`findExecutable`](#val-findexecutable), [`launchApplication`](#val-launchapplication) and
[`openDocument`](#val-opendocument). What asks nothing of Windows works everywhere: the flags
of [`Key`](#str-key), the platforms of [`Config`](#str-config), the codes of [`Status`](#str-status), [`fromStatus`](#val-fromstatus)
and [`exit`](#val-exit) (below).

> **Implementation** `WINDOWS/code-page`. Names, strings of the registry and
> paths go to Windows through its code page (the `A` functions of Win32),
> byte for byte; a path given as `/C:/...`, as [`OS.FileSys`](../sig/OS.md#str-filesys) writes the paths
> of a drive on Windows, is taken as `C:/...`.

## Contents

[The registry](#the-registry) &middot;
[The machine](#the-machine) &middot;
[Dynamic data exchange](#dynamic-data-exchange) &middot;
[Files and programs](#files-and-programs) &middot;
[How a process ends](#how-a-process-ends)

## Interface

<pre>
signature WINDOWS =
sig

  structure <a href="#str-key">Key</a> : sig
    include BIT_FLAGS

    val <a href="#val-key.allaccess">allAccess</a> : flags

    val <a href="#val-key.createlink">createLink</a> : flags

    val <a href="#val-key.createsubkey">createSubKey</a> : flags

    val <a href="#val-key.enumeratesubkeys">enumerateSubKeys</a> : flags

    val <a href="#val-key.execute">execute</a> : flags

    val <a href="#val-key.notify">notify</a> : flags

    val <a href="#val-key.queryvalue">queryValue</a> : flags

    val <a href="#val-key.read">read</a> : flags

    val <a href="#val-key.setvalue">setValue</a> : flags

    val <a href="#val-key.write">write</a> : flags
  end

  structure <a href="#str-reg">Reg</a> : sig
    eqtype <a href="#type-reg.hkey">hkey</a>

    val <a href="#val-reg.classesroot">classesRoot</a> : hkey

    val <a href="#val-reg.currentuser">currentUser</a> : hkey

    val <a href="#val-reg.localmachine">localMachine</a> : hkey

    val <a href="#val-reg.users">users</a> : hkey

    val <a href="#val-reg.performancedata">performanceData</a> : hkey

    val <a href="#val-reg.currentconfig">currentConfig</a> : hkey

    val <a href="#val-reg.dyndata">dynData</a> : hkey

    datatype <a href="#type-reg.create_result">create_result</a>
      = <a href="#con-reg.created_new_key">CREATED_NEW_KEY</a> of hkey
      | <a href="#con-reg.opened_existing_key">OPENED_EXISTING_KEY</a> of hkey

    val <a href="#val-reg.createkeyex">createKeyEx</a> : hkey * string * Key.flags -&gt; create_result

    val <a href="#val-reg.openkeyex">openKeyEx</a> : hkey * string * Key.flags -&gt; hkey

    val <a href="#val-reg.closekey">closeKey</a> : hkey -&gt; unit

    val <a href="#val-reg.deletekey">deleteKey</a> : hkey * string -&gt; unit

    val <a href="#val-reg.deletevalue">deleteValue</a> : hkey * string -&gt; unit

    val <a href="#val-reg.enumkeyex">enumKeyEx</a> : hkey * int -&gt; string option

    val <a href="#val-reg.enumvalueex">enumValueEx</a> : hkey * int -&gt; string option

    datatype <a href="#type-reg.value">value</a>
      = <a href="#con-reg.sz">SZ</a> of string
      | <a href="#con-reg.dword">DWORD</a> of SysWord.word
      | <a href="#con-reg.binary">BINARY</a> of Word8Vector.vector
      | <a href="#con-reg.multi_sz">MULTI_SZ</a> of string list
      | <a href="#con-reg.expand_sz">EXPAND_SZ</a> of string

    val <a href="#val-reg.queryvalueex">queryValueEx</a> : hkey * string -&gt; value option

    val <a href="#val-reg.setvalueex">setValueEx</a> : hkey * string * value -&gt; unit
  end

  structure <a href="#str-config">Config</a> : sig
    val <a href="#val-config.platformwin32s">platformWin32s</a> : SysWord.word

    val <a href="#val-config.platformwin32windows">platformWin32Windows</a> : SysWord.word

    val <a href="#val-config.platformwin32nt">platformWin32NT</a> : SysWord.word

    val <a href="#val-config.platformwin32ce">platformWin32CE</a> : SysWord.word

    val <a href="#val-config.getversionex">getVersionEx</a> : unit -&gt; {<a href="#fld-config.getversionex.majorversion">majorVersion</a> : SysWord.word, <a href="#fld-config.getversionex.minorversion">minorVersion</a> : SysWord.word,
                                <a href="#fld-config.getversionex.buildnumber">buildNumber</a> : SysWord.word, <a href="#fld-config.getversionex.platformid">platformId</a> : SysWord.word, <a href="#fld-config.getversionex.csdversion">csdVersion</a> : string}

    val <a href="#val-config.getwindowsdirectory">getWindowsDirectory</a> : unit -&gt; string

    val <a href="#val-config.getsystemdirectory">getSystemDirectory</a> : unit -&gt; string

    val <a href="#val-config.getcomputername">getComputerName</a> : unit -&gt; string

    val <a href="#val-config.getusername">getUserName</a> : unit -&gt; string
  end

  structure <a href="#str-dde">DDE</a> : sig
    type <a href="#type-dde.info">info</a>

    val <a href="#val-dde.startdialog">startDialog</a> : string * string -&gt; info

    val <a href="#val-dde.executestring">executeString</a> : info * string * int * Time.time -&gt; unit

    val <a href="#val-dde.stopdialog">stopDialog</a> : info -&gt; unit
  end

  val <a href="#val-getvolumeinformation">getVolumeInformation</a> : string -&gt; {<a href="#fld-getvolumeinformation.volumename">volumeName</a> : string, <a href="#fld-getvolumeinformation.systemname">systemName</a> : string,
                                        <a href="#fld-getvolumeinformation.serialnumber">serialNumber</a> : SysWord.word, <a href="#fld-getvolumeinformation.maximumcomponentlength">maximumComponentLength</a> : int}

  val <a href="#val-findexecutable">findExecutable</a> : string -&gt; string option

  val <a href="#val-launchapplication">launchApplication</a> : string * string -&gt; unit

  val <a href="#val-opendocument">openDocument</a> : string -&gt; unit

  val <a href="#val-simpleexecute">simpleExecute</a> : string * string -&gt; OS.Process.status

  type ('a, 'b) <a href="#type-proc">proc</a>

  val <a href="#val-execute">execute</a> : string * string -&gt; ('a, 'b) proc

  val <a href="#val-textinstreamof">textInstreamOf</a> : (TextIO.instream, 'a) proc -&gt; TextIO.instream

  val <a href="#val-bininstreamof">binInstreamOf</a> : (BinIO.instream, 'a) proc -&gt; BinIO.instream

  val <a href="#val-textoutstreamof">textOutstreamOf</a> : ('a, TextIO.outstream) proc -&gt; TextIO.outstream

  val <a href="#val-binoutstreamof">binOutstreamOf</a> : ('a, BinIO.outstream) proc -&gt; BinIO.outstream

  val <a href="#val-reap">reap</a> : ('a, 'b) proc -&gt; OS.Process.status

  structure <a href="#str-status">Status</a> : sig
    type <a href="#type-status.status">status</a> = SysWord.word

    val <a href="#val-status.accessviolation">accessViolation</a> : status

    val <a href="#val-status.arrayboundsexceeded">arrayBoundsExceeded</a> : status

    val <a href="#val-status.breakpoint">breakpoint</a> : status

    val <a href="#val-status.controlcexit">controlCExit</a> : status

    val <a href="#val-status.datatypemisalignment">datatypeMisalignment</a> : status

    val <a href="#val-status.floatdenormaloperand">floatDenormalOperand</a> : status

    val <a href="#val-status.floatdividebyzero">floatDivideByZero</a> : status

    val <a href="#val-status.floatinexactresult">floatInexactResult</a> : status

    val <a href="#val-status.floatinvalidoperation">floatInvalidOperation</a> : status

    val <a href="#val-status.floatoverflow">floatOverflow</a> : status

    val <a href="#val-status.floatstackcheck">floatStackCheck</a> : status

    val <a href="#val-status.floatunderflow">floatUnderflow</a> : status

    val <a href="#val-status.guardpageviolation">guardPageViolation</a> : status

    val <a href="#val-status.integerdividebyzero">integerDivideByZero</a> : status

    val <a href="#val-status.integeroverflow">integerOverflow</a> : status

    val <a href="#val-status.illegalinstruction">illegalInstruction</a> : status

    val <a href="#val-status.invaliddisposition">invalidDisposition</a> : status

    val <a href="#val-status.invalidhandle">invalidHandle</a> : status

    val <a href="#val-status.inpageerror">inPageError</a> : status

    val <a href="#val-status.noncontinuableexception">noncontinuableException</a> : status

    val <a href="#val-status.pending">pending</a> : status

    val <a href="#val-status.privilegedinstruction">privilegedInstruction</a> : status

    val <a href="#val-status.singlestep">singleStep</a> : status

    val <a href="#val-status.stackoverflow">stackOverflow</a> : status

    val <a href="#val-status.timeout">timeout</a> : status

    val <a href="#val-status.userapc">userAPC</a> : status
  end

  val <a href="#val-fromstatus">fromStatus</a> : OS.Process.status -&gt; Status.status

  val <a href="#val-exit">exit</a> : Status.status -&gt; 'a
end
</pre>

## The registry

### <a name="str-key"></a>`Key`

The rights to ask for when a key of the registry is opened or created,
as a set of flags.

**Included from [`BIT_FLAGS`](../sig/BIT_FLAGS.md)**: `include BIT_FLAGS`

| Member |  |  |
| --- | --- | --- |
| [`flags`](../sig/BIT_FLAGS.md#type-flags) | eqtype | The type of a set of flags. |
| [`toWord`](../sig/BIT_FLAGS.md#val-toword) | val | `toWord fl` is the word whose bits are the flags of `fl`. |
| [`fromWord`](../sig/BIT_FLAGS.md#val-fromword) | val | `fromWord w` is the set of the flags that the bits of `w` name. |
| [`all`](../sig/BIT_FLAGS.md#val-all) | val | Every flag the system uses here. |
| [`flags`](../sig/BIT_FLAGS.md#val-flags) | val | `flags l` is the union of the sets of `l`: a flag is in it when it is in one of them. |
| [`intersect`](../sig/BIT_FLAGS.md#val-intersect) | val | `intersect l` is the intersection of the sets of `l`: a flag is in it when it is in all of them. |
| [`clear`](../sig/BIT_FLAGS.md#val-clear) | val | `clear (fl, gl)` is `gl` without the flags of `fl`. |
| [`allSet`](../sig/BIT_FLAGS.md#val-allset) | val | `allSet (fl, gl)` is `true` when every flag of `fl` is in `gl`. |
| [`anySet`](../sig/BIT_FLAGS.md#val-anyset) | val | `anySet (fl, gl)` is `true` when some flag of `fl` is in `gl`. |

#### <a name="val-key.allaccess"></a>`allAccess`

```sml
val allAccess : flags
```

All the rights below: [`queryValue`](#val-key.queryvalue), [`enumerateSubKeys`](#val-key.enumeratesubkeys), [`notify`](#val-key.notify),
[`createSubKey`](#val-key.createsubkey), [`createLink`](#val-key.createlink) and [`setValue`](#val-key.setvalue) together.

> **Implementation** `Windows.Key/the-unions-of-the-page`. [`allAccess`](#val-key.allaccess),
> [`read`](#val-key.read) and [`write`](#val-key.write) are the unions the page gives, without the
> standard rights that `KEY_ALL_ACCESS`, `KEY_READ` and `KEY_WRITE` of
> Windows add; the others are the `KEY_*` values of Windows.

<details><summary>Tests (1)</summary>

For `Windows`, in [tests/basis/windows.sml](../../../../tests/basis/windows.sml): `union`

</details>

#### <a name="val-key.createlink"></a>`createLink`

```sml
val createLink : flags
```

The right to make a symbolic link; the rest of the structure makes none.

<details><summary>Tests (1)</summary>

For `Windows`, in [tests/basis/windows.sml](../../../../tests/basis/windows.sml): `one-flag`

</details>

#### <a name="val-key.createsubkey"></a>`createSubKey`

```sml
val createSubKey : flags
```

The right to make subkeys.

<details><summary>Tests (1)</summary>

For `Windows`, in [tests/basis/windows.sml](../../../../tests/basis/windows.sml): `one-flag`

</details>

#### <a name="val-key.enumeratesubkeys"></a>`enumerateSubKeys`

```sml
val enumerateSubKeys : flags
```

The right to enumerate subkeys.

<details><summary>Tests (1)</summary>

For `Windows`, in [tests/basis/windows.sml](../../../../tests/basis/windows.sml): `one-flag`

</details>

#### <a name="val-key.execute"></a>`execute`

```sml
val execute : flags
```

The right to read, the same as [`read`](#val-key.read).

<details><summary>Tests (1)</summary>

For `Windows`, in [tests/basis/windows.sml](../../../../tests/basis/windows.sml): `is-read`

</details>

#### <a name="val-key.notify"></a>`notify`

```sml
val notify : flags
```

The right to be told of changes.

<details><summary>Tests (1)</summary>

For `Windows`, in [tests/basis/windows.sml](../../../../tests/basis/windows.sml): `one-flag`

</details>

#### <a name="val-key.queryvalue"></a>`queryValue`

```sml
val queryValue : flags
```

The right to read values.

<details><summary>Tests (1)</summary>

For `Windows`, in [tests/basis/windows.sml](../../../../tests/basis/windows.sml): `one-flag`

</details>

#### <a name="val-key.read"></a>`read`

```sml
val read : flags
```

The rights to read: [`queryValue`](#val-key.queryvalue), [`enumerateSubKeys`](#val-key.enumeratesubkeys) and [`notify`](#val-key.notify) together.

<details><summary>Tests (1)</summary>

For `Windows`, in [tests/basis/windows.sml](../../../../tests/basis/windows.sml): `union`

</details>

#### <a name="val-key.setvalue"></a>`setValue`

```sml
val setValue : flags
```

The right to set values.

<details><summary>Tests (1)</summary>

For `Windows`, in [tests/basis/windows.sml](../../../../tests/basis/windows.sml): `one-flag`

</details>

#### <a name="val-key.write"></a>`write`

```sml
val write : flags
```

The rights to write: [`setValue`](#val-key.setvalue) and [`createSubKey`](#val-key.createsubkey) together.

<details><summary>Tests (1)</summary>

For `Windows`, in [tests/basis/windows.sml](../../../../tests/basis/windows.sml): `union`

</details>

### <a name="str-reg"></a>`Reg`

Keys of the registry: opening, making, deleting, enumerating, and the
values they hold.

#### <a name="type-reg.hkey"></a>`hkey`

```sml
eqtype hkey
```

The type of an open key of the registry.

<details><summary>Tests (1)</summary>

For `Windows`, in [tests/basis/windows.sml](../../../../tests/basis/windows.sml): `roots-differ`

</details>

#### <a name="val-reg.classesroot"></a>`classesRoot`

```sml
val classesRoot : hkey
```

The root `HKEY_CLASSES_ROOT`: the kinds of files and the programs that open them.

<details><summary>Tests (1)</summary>

For `Windows`, in [tests/basis/windows.sml](../../../../tests/basis/windows.sml): `its-own`

</details>

#### <a name="val-reg.currentuser"></a>`currentUser`

```sml
val currentUser : hkey
```

The root `HKEY_CURRENT_USER`: the settings of the user of this process.

<details><summary>Tests (1)</summary>

For `Windows`, in [tests/basis/windows.sml](../../../../tests/basis/windows.sml): `its-own`

</details>

#### <a name="val-reg.localmachine"></a>`localMachine`

```sml
val localMachine : hkey
```

The root `HKEY_LOCAL_MACHINE`: the settings of the machine.

<details><summary>Tests (1)</summary>

For `Windows`, in [tests/basis/windows.sml](../../../../tests/basis/windows.sml): `its-own`

</details>

#### <a name="val-reg.users"></a>`users`

```sml
val users : hkey
```

The root `HKEY_USERS`: the settings of every user of the machine.

<details><summary>Tests (1)</summary>

For `Windows`, in [tests/basis/windows.sml](../../../../tests/basis/windows.sml): `its-own`

</details>

#### <a name="val-reg.performancedata"></a>`performanceData`

```sml
val performanceData : hkey
```

The root `HKEY_PERFORMANCE_DATA`: counters of performance, read and never kept.

<details><summary>Tests (1)</summary>

For `Windows`, in [tests/basis/windows.sml](../../../../tests/basis/windows.sml): `its-own`

</details>

#### <a name="val-reg.currentconfig"></a>`currentConfig`

```sml
val currentConfig : hkey
```

The root `HKEY_CURRENT_CONFIG`: the profile of the hardware the machine runs with.

<details><summary>Tests (1)</summary>

For `Windows`, in [tests/basis/windows.sml](../../../../tests/basis/windows.sml): `its-own`

</details>

#### <a name="val-reg.dyndata"></a>`dynData`

```sml
val dynData : hkey
```

The root `HKEY_DYN_DATA` of Windows 95 and 98, which no Windows of today opens.

<details><summary>Tests (1)</summary>

For `Windows`, in [tests/basis/windows.sml](../../../../tests/basis/windows.sml): `its-own`

</details>

#### <a name="type-reg.create_result"></a>`create_result`

```sml
datatype create_result
  = CREATED_NEW_KEY of hkey
  | OPENED_EXISTING_KEY of hkey
```

What [`createKeyEx`](#val-reg.createkeyex) did.

| Constructor | Argument | Description |
| --- | --- | --- |
| <a name="con-reg.created_new_key"></a>`CREATED_NEW_KEY` | `hkey` | it made the key, which is open |
| <a name="con-reg.opened_existing_key"></a>`OPENED_EXISTING_KEY` | `hkey` | the key was there, and it opened it |

#### <a name="val-reg.createkeyex"></a>`createKeyEx`

```sml
val createKeyEx : hkey * string * Key.flags -> create_result
```

`createKeyEx (hkey, skey, regsam)` opens the subkey `skey` of `hkey` with the rights `regsam`, making it when it is not there.

The key is not volatile, and has no class and the default security,
as the page asks.

**Raises** [`OS.SysErr`](../sig/OS.md#exn-syserr) if the key cannot be made or opened, as without
the right to.

<details><summary>Tests (1)</summary>

For `Windows`, in [tests/basis/windows.sml](../../../../tests/basis/windows.sml): `new-then-existing`

</details>

#### <a name="val-reg.openkeyex"></a>`openKeyEx`

```sml
val openKeyEx : hkey * string * Key.flags -> hkey
```

`openKeyEx (hkey, skey, regsam)` opens the subkey `skey` of `hkey` with the rights `regsam`.

**Raises** [`OS.SysErr`](../sig/OS.md#exn-syserr) if there is no such key, or it may not be opened so.

<details><summary>Tests (2)</summary>

For `Windows`, in [tests/basis/windows.sml](../../../../tests/basis/windows.sml): `missing-raises` &middot; `closeKey`

</details>

#### <a name="val-reg.closekey"></a>`closeKey`

```sml
val closeKey : hkey -> unit
```

`closeKey hkey` closes the key `hkey`; a key at a root is left open.

**Raises** [`OS.SysErr`](../sig/OS.md#exn-syserr) if `hkey` is not open.

<details><summary>Tests (1)</summary>

For `Windows`, in [tests/basis/windows.sml](../../../../tests/basis/windows.sml): `twice-raises`

</details>

#### <a name="val-reg.deletekey"></a>`deleteKey`

```sml
val deleteKey : hkey * string -> unit
```

`deleteKey (hkey, skey)` deletes the subkey `skey` of `hkey`, which may have no subkeys itself.

**Raises** [`OS.SysErr`](../sig/OS.md#exn-syserr) if there is no such key, it has subkeys, or it may not be deleted.

<details><summary>Tests (1)</summary>

For `Windows`, in [tests/basis/windows.sml](../../../../tests/basis/windows.sml): `gone`

</details>

#### <a name="val-reg.deletevalue"></a>`deleteValue`

```sml
val deleteValue : hkey * string -> unit
```

`deleteValue (hkey, valname)` deletes the value `valname` of `hkey`.

**Raises** [`OS.SysErr`](../sig/OS.md#exn-syserr) if there is no such value, or it may not be deleted.

<details><summary>Tests (1)</summary>

For `Windows`, in [tests/basis/windows.sml](../../../../tests/basis/windows.sml): `gone`

</details>

#### <a name="val-reg.enumkeyex"></a>`enumKeyEx`

```sml
val enumKeyEx : hkey * int -> string option
```

`enumKeyEx (hkey, ind)` is the name of the subkey number `ind` of `hkey`, counted from zero, or `NONE` past the last.

**Raises** [`Subscript`](../sig/GENERAL.md#exn-subscript) if `ind` is negative.

**Raises** [`OS.SysErr`](../sig/OS.md#exn-syserr) if the key cannot be read.

<details><summary>Tests (2)</summary>

For `Windows`, in [tests/basis/windows.sml](../../../../tests/basis/windows.sml): `all-then-NONE` &middot; `negative-is-Subscript` (raises Subscript)

</details>

#### <a name="val-reg.enumvalueex"></a>`enumValueEx`

```sml
val enumValueEx : hkey * int -> string option
```

`enumValueEx (hkey, ind)` is the name of the value number `ind` of `hkey`, counted from zero, or `NONE` past the last.

**Raises** [`Subscript`](../sig/GENERAL.md#exn-subscript) if `ind` is negative.

**Raises** [`OS.SysErr`](../sig/OS.md#exn-syserr) if the key cannot be read.

<details><summary>Tests (2)</summary>

For `Windows`, in [tests/basis/windows.sml](../../../../tests/basis/windows.sml): `all-then-NONE` &middot; `negative-is-Subscript` (raises Subscript)

</details>

#### <a name="type-reg.value"></a>`value`

```sml
datatype value
  = SZ of string
  | DWORD of SysWord.word
  | BINARY of Word8Vector.vector
  | MULTI_SZ of string list
  | EXPAND_SZ of string
```

A value of the registry, by its kind.

| Constructor | Argument | Description |
| --- | --- | --- |
| <a name="con-reg.sz"></a>`SZ` | `string` | a string, `REG_SZ` |
| <a name="con-reg.dword"></a>`DWORD` | `SysWord.word` | a number of 32 bits, `REG_DWORD` |
| <a name="con-reg.binary"></a>`BINARY` | `Word8Vector.vector` | bytes, `REG_BINARY`, and every kind not otherwise named |
| <a name="con-reg.multi_sz"></a>`MULTI_SZ` | `string list` | strings, `REG_MULTI_SZ` |
| <a name="con-reg.expand_sz"></a>`EXPAND_SZ` | `string` | a string with variables of the environment in it, `REG_EXPAND_SZ` |

#### <a name="val-reg.queryvalueex"></a>`queryValueEx`

```sml
val queryValueEx : hkey * string -> value option
```

`queryValueEx (hkey, name)` is the value `name` of `hkey`, or `NONE` when it has none of that name.

**Raises** [`OS.SysErr`](../sig/OS.md#exn-syserr) for any other failure, as for want of the right to read.

<details><summary>Tests (1)</summary>

For `Windows`, in [tests/basis/windows.sml](../../../../tests/basis/windows.sml): `missing-is-NONE`

</details>

#### <a name="val-reg.setvalueex"></a>`setValueEx`

```sml
val setValueEx : hkey * string * value -> unit
```

`setValueEx (hkey, name, v)` sets the value `name` of `hkey` to `v`.

**Raises** [`OS.SysErr`](../sig/OS.md#exn-syserr) if it may not.

<details><summary>Tests (1)</summary>

For `Windows`, in [tests/basis/windows.sml](../../../../tests/basis/windows.sml): `SZ`

</details>

## The machine

### <a name="str-config"></a>`Config`

What the system is, where it is kept, and who uses it.

#### <a name="val-config.platformwin32s"></a>`platformWin32s`

```sml
val platformWin32s : SysWord.word
```

The platform Win32s, 32 bits on Windows 3.1, as [`getVersionEx`](#val-config.getversionex) names it.

<details><summary>Tests (1)</summary>

For `Windows`, in [tests/basis/windows.sml](../../../../tests/basis/windows.sml): `values`

</details>

#### <a name="val-config.platformwin32windows"></a>`platformWin32Windows`

```sml
val platformWin32Windows : SysWord.word
```

The platform of Windows 95, 98 and Me.

<details><summary>Tests (1)</summary>

For `Windows`, in [tests/basis/windows.sml](../../../../tests/basis/windows.sml): `distinct`

</details>

#### <a name="val-config.platformwin32nt"></a>`platformWin32NT`

```sml
val platformWin32NT : SysWord.word
```

The platform of Windows NT and of every Windows since, which is what [`getVersionEx`](#val-config.getversionex) says today.

<details><summary>Tests (1)</summary>

For `Windows`, in [tests/basis/windows.sml](../../../../tests/basis/windows.sml): `distinct`

</details>

#### <a name="val-config.platformwin32ce"></a>`platformWin32CE`

```sml
val platformWin32CE : SysWord.word
```

The platform of Windows CE.

<details><summary>Tests (1)</summary>

For `Windows`, in [tests/basis/windows.sml](../../../../tests/basis/windows.sml): `distinct`

</details>

#### <a name="val-config.getversionex"></a>`getVersionEx`

```sml
val getVersionEx : unit -> {majorVersion : SysWord.word, minorVersion : SysWord.word,
                            buildNumber : SysWord.word, platformId : SysWord.word, csdVersion : string}
```

`getVersionEx ()` is the version of Windows: major, minor and build, the platform, and the service pack.

> **Implementation** `Windows.Config.getVersionEx/the-real-version`. The
> version is the one Windows is, as `RtlGetVersion` gives it, and not
> the one a program's manifest would make `GetVersionEx` answer: 10.0
> and its build on Windows 11 too.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-config.getversionex.majorversion"></a>`majorVersion` | `SysWord.word` |  |
| <a name="fld-config.getversionex.minorversion"></a>`minorVersion` | `SysWord.word` |  |
| <a name="fld-config.getversionex.buildnumber"></a>`buildNumber` | `SysWord.word` |  |
| <a name="fld-config.getversionex.platformid"></a>`platformId` | `SysWord.word` |  |
| <a name="fld-config.getversionex.csdversion"></a>`csdVersion` | `string` |  |

<details><summary>Tests (1)</summary>

For `Windows`, in [tests/basis/windows.sml](../../../../tests/basis/windows.sml): `is-NT`

</details>

#### <a name="val-config.getwindowsdirectory"></a>`getWindowsDirectory`

```sml
val getWindowsDirectory : unit -> string
```

`getWindowsDirectory ()` is the directory of Windows, as Windows writes it: `C:\Windows`.

<details><summary>Tests (1)</summary>

For `Windows`, in [tests/basis/windows.sml](../../../../tests/basis/windows.sml): `holds-the-system-directory`

</details>

#### <a name="val-config.getsystemdirectory"></a>`getSystemDirectory`

```sml
val getSystemDirectory : unit -> string
```

`getSystemDirectory ()` is the system directory of Windows, as Windows writes it: `C:\Windows\system32`.

<details><summary>Tests (1)</summary>

For `Windows`, in [tests/basis/windows.sml](../../../../tests/basis/windows.sml): `is-a-directory`

</details>

#### <a name="val-config.getcomputername"></a>`getComputerName`

```sml
val getComputerName : unit -> string
```

`getComputerName ()` is the name of the computer.

<details><summary>Tests (1)</summary>

For `Windows`, in [tests/basis/windows.sml](../../../../tests/basis/windows.sml): `the-node`

</details>

#### <a name="val-config.getusername"></a>`getUserName`

```sml
val getUserName : unit -> string
```

`getUserName ()` is the name of the user of this process.

<details><summary>Tests (1)</summary>

For `Windows`, in [tests/basis/windows.sml](../../../../tests/basis/windows.sml): `the-login`

</details>

## Dynamic data exchange

### <a name="str-dde"></a>`DDE`

A client of DDE: a conversation with a service, on a topic, in which
commands are executed, each transaction waiting for its answer.

#### <a name="type-dde.info"></a>`info`

```sml
type info
```

The type of a conversation.

#### <a name="val-dde.startdialog"></a>`startDialog`

```sml
val startDialog : string * string -> info
```

`startDialog (service, topic)` starts a conversation with `service` on `topic`.

**Raises** [`OS.SysErr`](../sig/OS.md#exn-syserr) if no service of that name answers on that topic.

<details><summary>Tests (1)</summary>

For `Windows`, in [tests/basis/windows.sml](../../../../tests/basis/windows.sml): `no-such-service-raises` (raises)

</details>

#### <a name="val-dde.executestring"></a>`executeString`

```sml
val executeString : info * string * int * Time.time -> unit
```

`executeString (info, cmd, retry, delay)` has the service of `info` execute `cmd`, trying again `retry` times, `delay` apart, while it is busy.

Each try waits for the service's answer for as long as `delay`, and
the tries are `delay` apart.

**Raises** [`OS.SysErr`](../sig/OS.md#exn-syserr) if the command fails, or the service stays busy.

<details><summary>Tests (1)</summary>

For `Windows`, in [tests/basis/windows.sml](../../../../tests/basis/windows.sml): `no-dialog-raises`

</details>

#### <a name="val-dde.stopdialog"></a>`stopDialog`

```sml
val stopDialog : info -> unit
```

`stopDialog info` ends the conversation `info`.

**Raises** [`OS.SysErr`](../sig/OS.md#exn-syserr) if it has ended already.

<details><summary>Tests (1)</summary>

For `Windows`, in [tests/basis/windows.sml](../../../../tests/basis/windows.sml): `no-dialog-raises`

</details>

## Files and programs

### <a name="val-getvolumeinformation"></a>`getVolumeInformation`

```sml
val getVolumeInformation : string -> {volumeName : string, systemName : string,
                                      serialNumber : SysWord.word, maximumComponentLength : int}
```

`getVolumeInformation root` is what Windows says of the volume whose root is `root`.

The name of the volume, the name of its file system (`NTFS`), its
serial number, and the longest name a file on it may have.

**Raises** [`OS.SysErr`](../sig/OS.md#exn-syserr) if `root` is not the root of a volume.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-getvolumeinformation.volumename"></a>`volumeName` | `string` |  |
| <a name="fld-getvolumeinformation.systemname"></a>`systemName` | `string` |  |
| <a name="fld-getvolumeinformation.serialnumber"></a>`serialNumber` | `SysWord.word` |  |
| <a name="fld-getvolumeinformation.maximumcomponentlength"></a>`maximumComponentLength` | `int` |  |

<details><summary>Tests (2)</summary>

For `Windows`, in [tests/basis/windows.sml](../../../../tests/basis/windows.sml): `system-drive` &middot; `root-as-OS.FileSys-writes-it`

</details>

### <a name="val-findexecutable"></a>`findExecutable`

```sml
val findExecutable : string -> string option
```

`findExecutable name` is the program Windows opens the file `name` with, or `NONE` when there is none.

<details><summary>Tests (2)</summary>

For `Windows`, in [tests/basis/windows.sml](../../../../tests/basis/windows.sml): `a-program-is-its-own` &middot; `missing-is-NONE`

</details>

### <a name="val-launchapplication"></a>`launchApplication`

```sml
val launchApplication : string * string -> unit
```

`launchApplication (file, arg)` starts the program `file` with the argument `arg`, and does not wait for it.

**Raises** [`OS.SysErr`](../sig/OS.md#exn-syserr) if `file` is not a program, or cannot be started.

<details><summary>Tests (1)</summary>

For `Windows`, in [tests/basis/windows.sml](../../../../tests/basis/windows.sml): `missing-raises` (raises)

</details>

### <a name="val-opendocument"></a>`openDocument`

```sml
val openDocument : string -> unit
```

`openDocument file` opens `file` with the program Windows opens it with.

**Raises** [`OS.SysErr`](../sig/OS.md#exn-syserr) if there is no such file or no such program.

<details><summary>Tests (1)</summary>

For `Windows`, in [tests/basis/windows.sml](../../../../tests/basis/windows.sml): `missing-raises` (raises)

</details>

### <a name="val-simpleexecute"></a>`simpleExecute`

```sml
val simpleExecute : string * string -> OS.Process.status
```

`simpleExecute (cmd, arg)` runs the program `cmd` with the arguments `arg`, and is its status when it ends.

It reads from the null device and writes to it; its standard error is
this process's.

**Raises** [`OS.SysErr`](../sig/OS.md#exn-syserr) if the program cannot be started.

<details><summary>Tests (1)</summary>

For `Windows`, in [tests/basis/windows.sml](../../../../tests/basis/windows.sml): `status`

</details>

### <a name="type-proc"></a>`proc`

```sml
type ('a, 'b) proc
```

The type of a program started by [`execute`](#val-execute), with the streams that talk to it.

The first type variable is the stream its output is read through, the
second the stream its input is written through.

### <a name="val-execute"></a>`execute`

```sml
val execute : string * string -> ('a, 'b) proc
```

`execute (cmd, arg)` starts the program `cmd` with the arguments `arg`, with a pipe each way.

Its standard error is this process's; this process's ends of the pipes
are not handed to programs started later.

**Raises** [`OS.SysErr`](../sig/OS.md#exn-syserr) if the program cannot be started.

<details><summary>Tests (1)</summary>

For `Windows`, in [tests/basis/windows.sml](../../../../tests/basis/windows.sml): `missing-program-raises` (raises)

</details>

### <a name="val-textinstreamof"></a>`textInstreamOf`

```sml
val textInstreamOf : (TextIO.instream, 'a) proc -> TextIO.instream
```

`textInstreamOf pr` is a text stream from which what `pr` writes is read.

<details><summary>Tests (1)</summary>

For `Windows`, in [tests/basis/windows.sml](../../../../tests/basis/windows.sml): `output-of-the-program`

</details>

### <a name="val-bininstreamof"></a>`binInstreamOf`

```sml
val binInstreamOf : (BinIO.instream, 'a) proc -> BinIO.instream
```

`binInstreamOf pr` is a binary stream from which what `pr` writes is read.

<details><summary>Tests (1)</summary>

For `Windows`, in [tests/basis/windows.sml](../../../../tests/basis/windows.sml): `bytes`

</details>

### <a name="val-textoutstreamof"></a>`textOutstreamOf`

```sml
val textOutstreamOf : ('a, TextIO.outstream) proc -> TextIO.outstream
```

`textOutstreamOf pr` is a text stream to which what `pr` reads is written.

<details><summary>Tests (1)</summary>

For `Windows`, in [tests/basis/windows.sml](../../../../tests/basis/windows.sml): `to-the-program`

</details>

### <a name="val-binoutstreamof"></a>`binOutstreamOf`

```sml
val binOutstreamOf : ('a, BinIO.outstream) proc -> BinIO.outstream
```

`binOutstreamOf pr` is a binary stream to which what `pr` reads is written.

<details><summary>Tests (1)</summary>

For `Windows`, in [tests/basis/windows.sml](../../../../tests/basis/windows.sml): `to-the-program`

</details>

### <a name="val-reap"></a>`reap`

```sml
val reap : ('a, 'b) proc -> OS.Process.status
```

`reap pr` closes the pipes of `pr`, waits for it to end, and is the code it ended with.

Reaping it again gives the same status at once, as the page asks.

**Raises** [`OS.SysErr`](../sig/OS.md#exn-syserr) if the wait fails.

<details><summary>Tests (1)</summary>

For `Windows`, in [tests/basis/windows.sml](../../../../tests/basis/windows.sml): `twice-same-status`

</details>

## How a process ends

### <a name="str-status"></a>`Status`

The codes with which Windows ends a process that an exception ends:
the `STATUS_*` codes of Windows.

#### <a name="type-status.status"></a>`status`

```sml
type status = SysWord.word
```

The type of the code a process ended with.

#### <a name="val-status.accessviolation"></a>`accessViolation`

```sml
val accessViolation : status
```

A read or write of memory the process may not touch, `STATUS_ACCESS_VIOLATION`.

<details><summary>Tests (1)</summary>

For `Windows`, in [tests/basis/windows.sml](../../../../tests/basis/windows.sml): `value`

</details>

#### <a name="val-status.arrayboundsexceeded"></a>`arrayBoundsExceeded`

```sml
val arrayBoundsExceeded : status
```

An index beyond the bounds of an array, found by the processor, `STATUS_ARRAY_BOUNDS_EXCEEDED`.

<details><summary>Tests (1)</summary>

For `Windows`, in [tests/basis/windows.sml](../../../../tests/basis/windows.sml): `value`

</details>

#### <a name="val-status.breakpoint"></a>`breakpoint`

```sml
val breakpoint : status
```

A breakpoint reached with no debugger to take it, `STATUS_BREAKPOINT`.

<details><summary>Tests (1)</summary>

For `Windows`, in [tests/basis/windows.sml](../../../../tests/basis/windows.sml): `value`

</details>

#### <a name="val-status.controlcexit"></a>`controlCExit`

```sml
val controlCExit : status
```

The end of a program at ^C or at the close of its console, `STATUS_CONTROL_C_EXIT`.

<details><summary>Tests (1)</summary>

For `Windows`, in [tests/basis/windows.sml](../../../../tests/basis/windows.sml): `value`

</details>

#### <a name="val-status.datatypemisalignment"></a>`datatypeMisalignment`

```sml
val datatypeMisalignment : status
```

Data read or written at an address it may not be at, `STATUS_DATATYPE_MISALIGNMENT`.

<details><summary>Tests (1)</summary>

For `Windows`, in [tests/basis/windows.sml](../../../../tests/basis/windows.sml): `value`

</details>

#### <a name="val-status.floatdenormaloperand"></a>`floatDenormalOperand`

```sml
val floatDenormalOperand : status
```

A denormal operand of floating point, `STATUS_FLOAT_DENORMAL_OPERAND`.

<details><summary>Tests (1)</summary>

For `Windows`, in [tests/basis/windows.sml](../../../../tests/basis/windows.sml): `value`

</details>

#### <a name="val-status.floatdividebyzero"></a>`floatDivideByZero`

```sml
val floatDivideByZero : status
```

A division of floating point by zero, `STATUS_FLOAT_DIVIDE_BY_ZERO`.

<details><summary>Tests (1)</summary>

For `Windows`, in [tests/basis/windows.sml](../../../../tests/basis/windows.sml): `value`

</details>

#### <a name="val-status.floatinexactresult"></a>`floatInexactResult`

```sml
val floatInexactResult : status
```

A result of floating point that is not exact, `STATUS_FLOAT_INEXACT_RESULT`.

<details><summary>Tests (1)</summary>

For `Windows`, in [tests/basis/windows.sml](../../../../tests/basis/windows.sml): `value`

</details>

#### <a name="val-status.floatinvalidoperation"></a>`floatInvalidOperation`

```sml
val floatInvalidOperation : status
```

An invalid operation of floating point, `STATUS_FLOAT_INVALID_OPERATION`.

<details><summary>Tests (1)</summary>

For `Windows`, in [tests/basis/windows.sml](../../../../tests/basis/windows.sml): `value`

</details>

#### <a name="val-status.floatoverflow"></a>`floatOverflow`

```sml
val floatOverflow : status
```

An overflow of floating point, `STATUS_FLOAT_OVERFLOW`.

<details><summary>Tests (1)</summary>

For `Windows`, in [tests/basis/windows.sml](../../../../tests/basis/windows.sml): `value`

</details>

#### <a name="val-status.floatstackcheck"></a>`floatStackCheck`

```sml
val floatStackCheck : status
```

The stack of the floating-point unit over- or underflowed, `STATUS_FLOAT_STACK_CHECK`.

<details><summary>Tests (1)</summary>

For `Windows`, in [tests/basis/windows.sml](../../../../tests/basis/windows.sml): `value`

</details>

#### <a name="val-status.floatunderflow"></a>`floatUnderflow`

```sml
val floatUnderflow : status
```

An underflow of floating point, `STATUS_FLOAT_UNDERFLOW`.

<details><summary>Tests (1)</summary>

For `Windows`, in [tests/basis/windows.sml](../../../../tests/basis/windows.sml): `value`

</details>

#### <a name="val-status.guardpageviolation"></a>`guardPageViolation`

```sml
val guardPageViolation : status
```

A guard page of memory touched, `STATUS_GUARD_PAGE_VIOLATION`.

<details><summary>Tests (1)</summary>

For `Windows`, in [tests/basis/windows.sml](../../../../tests/basis/windows.sml): `value`

</details>

#### <a name="val-status.integerdividebyzero"></a>`integerDivideByZero`

```sml
val integerDivideByZero : status
```

A division of integers by zero, `STATUS_INTEGER_DIVIDE_BY_ZERO`.

<details><summary>Tests (1)</summary>

For `Windows`, in [tests/basis/windows.sml](../../../../tests/basis/windows.sml): `value`

</details>

#### <a name="val-status.integeroverflow"></a>`integerOverflow`

```sml
val integerOverflow : status
```

An overflow of integers, `STATUS_INTEGER_OVERFLOW`.

<details><summary>Tests (1)</summary>

For `Windows`, in [tests/basis/windows.sml](../../../../tests/basis/windows.sml): `value`

</details>

#### <a name="val-status.illegalinstruction"></a>`illegalInstruction`

```sml
val illegalInstruction : status
```

An instruction the processor does not have, `STATUS_ILLEGAL_INSTRUCTION`.

<details><summary>Tests (1)</summary>

For `Windows`, in [tests/basis/windows.sml](../../../../tests/basis/windows.sml): `value`

</details>

#### <a name="val-status.invaliddisposition"></a>`invalidDisposition`

```sml
val invalidDisposition : status
```

A handler of exceptions that answered what it may not, `STATUS_INVALID_DISPOSITION`.

<details><summary>Tests (1)</summary>

For `Windows`, in [tests/basis/windows.sml](../../../../tests/basis/windows.sml): `value`

</details>

#### <a name="val-status.invalidhandle"></a>`invalidHandle`

```sml
val invalidHandle : status
```

A handle that is not open, `STATUS_INVALID_HANDLE`.

<details><summary>Tests (1)</summary>

For `Windows`, in [tests/basis/windows.sml](../../../../tests/basis/windows.sml): `value`

</details>

#### <a name="val-status.inpageerror"></a>`inPageError`

```sml
val inPageError : status
```

A page of memory that could not be read in, `STATUS_IN_PAGE_ERROR`.

<details><summary>Tests (1)</summary>

For `Windows`, in [tests/basis/windows.sml](../../../../tests/basis/windows.sml): `value`

</details>

#### <a name="val-status.noncontinuableexception"></a>`noncontinuableException`

```sml
val noncontinuableException : status
```

An exception continued that may not be, `STATUS_NONCONTINUABLE_EXCEPTION`.

<details><summary>Tests (1)</summary>

For `Windows`, in [tests/basis/windows.sml](../../../../tests/basis/windows.sml): `value`

</details>

#### <a name="val-status.pending"></a>`pending`

```sml
val pending : status
```

An operation that has not ended yet, `STATUS_PENDING`.

<details><summary>Tests (1)</summary>

For `Windows`, in [tests/basis/windows.sml](../../../../tests/basis/windows.sml): `value`

</details>

#### <a name="val-status.privilegedinstruction"></a>`privilegedInstruction`

```sml
val privilegedInstruction : status
```

An instruction only the system may execute, `STATUS_PRIVILEGED_INSTRUCTION`.

<details><summary>Tests (1)</summary>

For `Windows`, in [tests/basis/windows.sml](../../../../tests/basis/windows.sml): `value`

</details>

#### <a name="val-status.singlestep"></a>`singleStep`

```sml
val singleStep : status
```

A step of a program traced with no debugger to take it, `STATUS_SINGLE_STEP`.

<details><summary>Tests (1)</summary>

For `Windows`, in [tests/basis/windows.sml](../../../../tests/basis/windows.sml): `value`

</details>

#### <a name="val-status.stackoverflow"></a>`stackOverflow`

```sml
val stackOverflow : status
```

The stack of a thread overflowed, `STATUS_STACK_OVERFLOW`.

<details><summary>Tests (1)</summary>

For `Windows`, in [tests/basis/windows.sml](../../../../tests/basis/windows.sml): `value`

</details>

#### <a name="val-status.timeout"></a>`timeout`

```sml
val timeout : status
```

A wait that ran out of time, `STATUS_TIMEOUT`.

<details><summary>Tests (1)</summary>

For `Windows`, in [tests/basis/windows.sml](../../../../tests/basis/windows.sml): `value`

</details>

#### <a name="val-status.userapc"></a>`userAPC`

```sml
val userAPC : status
```

A wait ended by a call queued for the thread, `STATUS_USER_APC`.

<details><summary>Tests (1)</summary>

For `Windows`, in [tests/basis/windows.sml](../../../../tests/basis/windows.sml): `value`

</details>

### <a name="val-fromstatus"></a>`fromStatus`

```sml
val fromStatus : OS.Process.status -> Status.status
```

`fromStatus s` is the code of Windows that the status `s` stands for.

<details><summary>Tests (2)</summary>

For `Windows`, in [tests/basis/windows.sml](../../../../tests/basis/windows.sml): `success` &middot; `failure-is-not-success`

</details>

### <a name="val-exit"></a>`exit`

```sml
val exit : Status.status -> 'a
```

`exit st` runs the actions of [`OS.Process.atExit`](../sig/OS_PROCESS.md#val-atexit), flushes and closes the files, and ends this program with the code `st`.

> **Implementation** `Windows.exit/the-code-off-windows`. This is one of the
> values that need no Windows, and the program ends with `st` wherever it
> runs; but a system of POSIX gives a parent the low eight bits of a code
> alone, where Windows gives the whole of it, which is what [`reap`](#val-reap) reads
> back.

<details><summary>Tests (1)</summary>

For `Windows`, in [tests/basis/windows.sml](../../../../tests/basis/windows.sml): `code`

</details>

## See also

[`OS_PROCESS`](../sig/OS_PROCESS.md), [`UNIX`](../sig/UNIX.md), [`BIT_FLAGS`](../sig/BIT_FLAGS.md), [`TEXT_IO`](../sig/TEXT_IO.md), [`BIN_IO`](../sig/BIN_IO.md)

---

<sub>Generated by runedoc from lib/basis/sig\_windows.sml; do not edit.</sub>
