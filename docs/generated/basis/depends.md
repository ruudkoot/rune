# What depends on what

[The Standard ML Basis Library](README.md)

A node is one file of the library, named by the modules it declares; a family of structures that
one file declares, such as the five of `Int8`, is one node. An arrow from one node to another
means that the first needs the second to compile, as the library's MANIFEST records it. An arrow
that a path of other arrows already implies is left out, so that what is left is the shape of the
library and not a wall of lines: the 580 requirements between the 147 files become 249 arrows.
The order in which the MANIFEST loads the files makes the graph acyclic: every arrow points at a
file that is compiled earlier.

A rounded node declares signatures, a square one structures. The library writes its structures
first and the signatures of the specification after them, so an arrow from a signature to a
structure means that the signature's text names that structure's types, as `STREAM_IO` names
those of `TextPrimIO`; the structure is bound to the signature later still, in a seal file, which
is no part of this graph.

## The areas

How the areas of the library rest on each other; the number on an arrow is how many files of the
one need a file of the other.

```mermaid
flowchart LR
  a0["The language<br>(4)"]
  a1["Text and characters<br>(17)"]
  a2["Lists and options<br>(6)"]
  a3["Numbers<br>(26)"]
  a4["Sequences<br>(37)"]
  a5["The operating system<br>(41)"]
  a6["Input and output<br>(14)"]
  a7["The runtime<br>(2)"]
  a6 -- 1 --> a2
  a6 -- 5 --> a3
  a6 -- 4 --> a4
  a6 -- 2 --> a1
  a6 -- 3 --> a5
  a3 -- 1 --> a2
  a3 -- 3 --> a4
  a3 -- 4 --> a1
  a4 -- 2 --> a2
  a4 -- 10 --> a3
  a4 -- 3 --> a1
  a1 -- 1 --> a3
  a1 -- 6 --> a4
  a0 -- 1 --> a6
  a5 -- 14 --> a6
  a5 -- 1 --> a2
  a5 -- 7 --> a3
  a5 -- 2 --> a4
  a5 -- 4 --> a1
  a7 -- 2 --> a6
```

## The language

```mermaid
flowchart TD
  n0["General"]
  n84(["SML90"])
  n96(["GENERAL"])
  n118(["SML90"])
```

It also needs Input and output (1).

## Text and characters

```mermaid
flowchart TD
  n1["StringCvt"]
  n2["Bool"]
  n19["Char"]
  n20["String"]
  n29["Substring"]
  n58["Text"]
  n74["Byte"]
  n91(["BOOL"])
  n92(["BYTE"])
  n93(["CHAR"])
  n119(["STRING"])
  n120(["STRING_CVT"])
  n121(["SUBSTRING"])
  n131(["TEXT"])
  n143["WideChar* (5)"]
  n144["WideString<br>WideSubstring"]
  n145["WideText"]
  n2 --> n1
  n20 --> n19
  n29 --> n20
  n91 --> n1
  n93 --> n20
  n119 --> n29
  n121 --> n29
  n131 --> n93
  n131 --> n119
  n131 --> n121
  n143 --> n93
  n144 --> n143
  n144 --> n119
  n144 --> n121
  n145 --> n144
```

It also needs Numbers (1), Sequences (6).

## Lists and options

```mermaid
flowchart TD
  n3["Option"]
  n4["List"]
  n5["ListPair"]
  n102(["LIST"])
  n103(["LIST_PAIR"])
  n108(["OPTION"])
  n108 --> n3
```

## Numbers

```mermaid
flowchart TD
  n6["IntInf<br>LargeInt"]
  n7["Int"]
  n8["Word<br>LargeWord<br>SysWord"]
  n9(["WORD"])
  n10(["INTEGER"])
  n11["Int8"]
  n12["Int16"]
  n13["Int32"]
  n14["FixedInt<br>Int64"]
  n15["Word8"]
  n16["Word16"]
  n17["Word32"]
  n18["Word64"]
  n21["IEEEReal"]
  n22["Real<br>Math<br>LargeReal<br>Real64"]
  n34["PackWord* (6)"]
  n35["PackReal* (4)"]
  n59["Position"]
  n98(["IEEE_REAL"])
  n100(["INT_INF"])
  n104(["MATH"])
  n113(["PACK_REAL"])
  n114(["PACK_WORD"])
  n129(["REAL"])
  n140["Real32"]
  n141["PackReal32Big<br>PackReal32Little"]
  n7 --> n6
  n8 --> n7
  n9 --> n8
  n10 --> n7
  n11 --> n10
  n12 --> n10
  n13 --> n10
  n14 --> n10
  n15 --> n9
  n16 --> n9
  n17 --> n9
  n18 --> n9
  n22 --> n21
  n22 --> n7
  n35 --> n22
  n35 --> n34
  n59 --> n7
  n100 --> n10
  n100 --> n8
  n129 --> n22
  n129 --> n104
  n140 --> n129
  n140 --> n8
  n141 --> n140
  n141 --> n34
```

It also needs Lists and options (1), Text and characters (4), Sequences (3).

## Sequences

```mermaid
flowchart TD
  n23["Vector"]
  n24["Array"]
  n25["VectorSlice"]
  n26["ArraySlice"]
  n27(["MONO_* (5)"])
  n28["CharVector"]
  n30["CharVectorSlice"]
  n31["Word8Vector<br>Word8VectorSlice"]
  n32["Word8Array"]
  n33["Word8ArraySlice"]
  n36["CharArray"]
  n37["CharArraySlice"]
  n38(["ARRAY2"])
  n39["Array2"]
  n40(["MONO_ARRAY2"])
  n41["CharArray2"]
  n42["Word8Array2"]
  n43["Bool* (5)"]
  n44["Int* (5)"]
  n45["Int8* (5)"]
  n46["Int16* (5)"]
  n47["Int32* (5)"]
  n48["LargeInt* (5)"]
  n49["Word* (5)"]
  n50["Word16* (5)"]
  n51["Word32* (5)"]
  n52["Real* (5)"]
  n53["Int64* (5)"]
  n54["LargeWord* (5)"]
  n55["Word64* (5)"]
  n56["LargeReal* (5)"]
  n57["Real64* (5)"]
  n87(["ARRAY"])
  n88(["ARRAY_SLICE"])
  n125(["VECTOR"])
  n126(["VECTOR_SLICE"])
  n142["Real32* (5)"]
  n24 --> n23
  n25 --> n23
  n26 --> n24
  n26 --> n25
  n28 --> n27
  n30 --> n28
  n31 --> n27
  n32 --> n24
  n32 --> n31
  n33 --> n32
  n36 --> n28
  n36 --> n24
  n37 --> n36
  n37 --> n30
  n38 --> n23
  n39 --> n38
  n39 --> n24
  n40 --> n39
  n41 --> n28
  n41 --> n40
  n42 --> n40
  n42 --> n31
  n43 --> n27
  n43 --> n40
  n44 --> n27
  n44 --> n40
  n45 --> n27
  n45 --> n40
  n46 --> n27
  n46 --> n40
  n47 --> n27
  n47 --> n40
  n48 --> n27
  n48 --> n40
  n49 --> n27
  n49 --> n40
  n50 --> n27
  n50 --> n40
  n51 --> n27
  n51 --> n40
  n52 --> n27
  n52 --> n40
  n53 --> n27
  n53 --> n40
  n54 --> n49
  n55 --> n27
  n55 --> n40
  n56 --> n52
  n57 --> n52
  n87 --> n23
  n88 --> n24
  n88 --> n25
  n126 --> n23
  n142 --> n27
  n142 --> n40
```

It also needs Lists and options (2), Text and characters (3), Numbers (10).

## The operating system

```mermaid
flowchart TD
  n60(["TIME"])
  n61["Time"]
  n62["Timer"]
  n63["Date"]
  n64(["OS"])
  n70["Posix"]
  n76["Socket"]
  n77["NetHostDB<br>NetProtDB<br>NetServDB"]
  n78["GenericSock<br>INetSock<br>UnixSock"]
  n79(["INET6_SOCK"])
  n80["INet6Sock"]
  n81["Unix"]
  n82["Windows"]
  n83["CommandLine"]
  n90(["BIT_FLAGS"])
  n94(["COMMAND_LINE"])
  n95(["DATE"])
  n97(["GENERIC_SOCK"])
  n99(["INET_SOCK"])
  n105(["NET_HOST_DB"])
  n106(["NET_PROT_DB"])
  n107(["NET_SERV_DB"])
  n109(["OS_FILE_SYS"])
  n110(["OS_IO"])
  n111(["OS_PATH"])
  n112(["OS_PROCESS"])
  n115(["POSIX_PROC_ENV"])
  n116(["POSIX_SIGNAL"])
  n117(["POSIX_SYS_DB"])
  n123(["TIMER"])
  n124(["UNIX_SOCK"])
  n127(["POSIX_TTY"])
  n128(["POSIX_IO"])
  n130(["OS"])
  n133(["WINDOWS"])
  n134(["UNIX"])
  n135(["SOCKET"])
  n136(["POSIX_PROCESS"])
  n137(["POSIX_FILE_SYS"])
  n138(["POSIX_ERROR"])
  n139(["POSIX"])
  n61 --> n60
  n62 --> n61
  n63 --> n61
  n64 --> n61
  n76 --> n61
  n78 --> n77
  n78 --> n76
  n79 --> n76
  n80 --> n76
  n81 --> n130
  n81 --> n64
  n81 --> n70
  n82 --> n130
  n82 --> n64
  n82 --> n70
  n95 --> n63
  n97 --> n76
  n99 --> n77
  n99 --> n76
  n109 --> n61
  n110 --> n61
  n112 --> n61
  n115 --> n61
  n123 --> n61
  n124 --> n76
  n127 --> n90
  n128 --> n90
  n130 --> n109
  n130 --> n110
  n130 --> n111
  n130 --> n112
  n133 --> n90
  n133 --> n130
  n133 --> n64
  n134 --> n130
  n134 --> n64
  n135 --> n77
  n135 --> n130
  n135 --> n64
  n136 --> n90
  n136 --> n130
  n136 --> n64
  n137 --> n90
  n137 --> n130
  n137 --> n64
  n138 --> n130
  n138 --> n64
  n139 --> n138
  n139 --> n137
  n139 --> n128
  n139 --> n136
  n139 --> n115
  n139 --> n116
  n139 --> n117
  n139 --> n127
```

It also needs Numbers (7), Text and characters (4), Lists and options (1), Input and output (14), Sequences (2).

## Input and output

```mermaid
flowchart TD
  n65(["IO"])
  n66(["PRIM_IO"])
  n67(["STREAM_IO"])
  n68["TextPrimIO"]
  n69["BinPrimIO"]
  n71(["IMPERATIVE_IO"])
  n72["ImperativeIO<br>PrimIO<br>StreamIO"]
  n73["TextIO"]
  n75["BinIO"]
  n89(["BIN_IO"])
  n101(["IO"])
  n122(["TEXT_STREAM_IO"])
  n132(["TEXT_IO"])
  n146["WideTextIO<br>WideTextPrimIO"]
  n67 --> n101
  n67 --> n65
  n68 --> n101
  n68 --> n65
  n69 --> n101
  n69 --> n65
  n71 --> n67
  n72 --> n71
  n72 --> n66
  n73 --> n67
  n73 --> n66
  n73 --> n68
  n75 --> n69
  n75 --> n67
  n75 --> n66
  n89 --> n69
  n89 --> n72
  n122 --> n67
  n132 --> n72
  n132 --> n122
  n132 --> n68
  n146 --> n73
```

It also needs The operating system (3), Numbers (5), Sequences (4), Lists and options (1), Text and characters (2).

## The runtime

```mermaid
flowchart TD
  n85(["RUNTIME"])
  n86["Runtime"]
```

It also needs Input and output (2).

---

<sub>Generated by runedoc from the MANIFEST; do not edit.</sub>
