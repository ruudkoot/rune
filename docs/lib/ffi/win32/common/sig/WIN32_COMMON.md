# signature WIN32_COMMON

[Shared Win32 GUI contracts](../README.md) &rsaquo; Foreign interfaces &rsaquo; **WIN32_COMMON**

|  |  |
| --- | --- |
| Status | required |
| Implementations | 1 |
| Documentation | 18 of 18 entries documented |
| Tests | not listed |
| Source | [lib/ffi/win32/common/common\_sig.sml](../../../../../../lib/ffi/win32/common/common_sig.sml) |

## Synopsis

```sml
signature WIN32_COMMON
structure Win32Common :> WIN32_COMMON
```

| Implementation |  | Source |
| --- | --- | --- |
| [`Win32Common`](../str/Win32Common.md) |  | [lib/ffi/win32/common/common.sml](../../../../../../lib/ffi/win32/common/common.sml) |

Provider support for the shared Win32 type identities.

## Interface

<pre>
signature WIN32_COMMON =
sig
  structure <a href="#str-types">Types</a> : WIN32_TYPES
  val <a href="#val-freshwindow">freshWindow</a> : unit -&gt; Types.window
  val <a href="#val-freshmodule">freshModule</a> : unit -&gt; Types.module
  val <a href="#val-freshatom">freshAtom</a> : unit -&gt; Types.atom
  val <a href="#val-freshpaint">freshPaint</a> : unit -&gt; Types.paint
  val <a href="#val-freshobject">freshObject</a> : unit -&gt; Types.object
  val <a href="#val-freshpen">freshPen</a> : unit -&gt; Types.pen
  val <a href="#val-freshbrush">freshBrush</a> : unit -&gt; Types.brush
  val <a href="#val-freshqueued">freshQueued</a> : unit -&gt; Types.queued
  val <a href="#val-penobject">penObject</a> : Types.pen -&gt; Types.object
  val <a href="#val-brushobject">brushObject</a> : Types.brush -&gt; Types.object
  val <a href="#val-objectbrush">objectBrush</a> : Types.object -&gt; Types.brush
  val <a href="#val-windowkey">windowKey</a> : Types.window -&gt; IntInf.int
  val <a href="#val-modulekey">moduleKey</a> : Types.module -&gt; IntInf.int
  val <a href="#val-atomkey">atomKey</a> : Types.atom -&gt; IntInf.int
  val <a href="#val-paintkey">paintKey</a> : Types.paint -&gt; IntInf.int
  val <a href="#val-objectkey">objectKey</a> : Types.object -&gt; IntInf.int
  val <a href="#val-queuedkey">queuedKey</a> : Types.queued -&gt; IntInf.int
end
</pre>

### <a name="str-types"></a>`Types`

```sml
structure Types : WIN32_TYPES
```

A substructure: its members are described on the page of [`WIN32_TYPES`](../sig/WIN32_TYPES.md).

One public type module reused by native, SDL and mock providers.

### <a name="val-freshwindow"></a>`freshWindow`

```sml
val freshWindow : unit -> Types.window
```

`freshWindow ()` creates an unregistered window token.

A token alone grants no capability; every provider validates its registry.

### <a name="val-freshmodule"></a>`freshModule`

```sml
val freshModule : unit -> Types.module
```

`freshModule ()` creates an unregistered module token.

### <a name="val-freshatom"></a>`freshAtom`

```sml
val freshAtom : unit -> Types.atom
```

`freshAtom ()` creates an unregistered class token.

### <a name="val-freshpaint"></a>`freshPaint`

```sml
val freshPaint : unit -> Types.paint
```

`freshPaint ()` creates an unregistered paint token.

### <a name="val-freshobject"></a>`freshObject`

```sml
val freshObject : unit -> Types.object
```

`freshObject ()` creates an unregistered object token.

### <a name="val-freshpen"></a>`freshPen`

```sml
val freshPen : unit -> Types.pen
```

`freshPen ()` creates a pen and its associated object identity.

### <a name="val-freshbrush"></a>`freshBrush`

```sml
val freshBrush : unit -> Types.brush
```

`freshBrush ()` creates a brush and its associated object identity.

### <a name="val-freshqueued"></a>`freshQueued`

```sml
val freshQueued : unit -> Types.queued
```

`freshQueued ()` creates an unregistered copied-message token.

### <a name="val-penobject"></a>`penObject`

```sml
val penObject : Types.pen -> Types.object
```

`penObject pen` returns the pen's shared object identity.

### <a name="val-brushobject"></a>`brushObject`

```sml
val brushObject : Types.brush -> Types.object
```

`brushObject brush` returns the brush's shared object identity.

### <a name="val-objectbrush"></a>`objectBrush`

```sml
val objectBrush : Types.object -> Types.brush
```

`objectBrush object` reinterprets the token without granting ownership.

The provider must verify that the associated object is a brush.

### <a name="val-windowkey"></a>`windowKey`

```sml
val windowKey : Types.window -> IntInf.int
```

`windowKey window` returns its process-local diagnostic identity.

### <a name="val-modulekey"></a>`moduleKey`

```sml
val moduleKey : Types.module -> IntInf.int
```

`moduleKey module` returns its process-local diagnostic identity.

### <a name="val-atomkey"></a>`atomKey`

```sml
val atomKey : Types.atom -> IntInf.int
```

`atomKey atom` returns its process-local diagnostic identity.

### <a name="val-paintkey"></a>`paintKey`

```sml
val paintKey : Types.paint -> IntInf.int
```

`paintKey paint` returns its process-local diagnostic identity.

### <a name="val-objectkey"></a>`objectKey`

```sml
val objectKey : Types.object -> IntInf.int
```

`objectKey object` returns its process-local diagnostic identity.

### <a name="val-queuedkey"></a>`queuedKey`

```sml
val queuedKey : Types.queued -> IntInf.int
```

`queuedKey queued` returns its process-local diagnostic identity.

---

<sub>Generated by runedoc from lib/ffi/win32/common/common\_sig.sml; do not edit.</sub>
