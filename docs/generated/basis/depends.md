# What depends on what

[The Standard ML Basis Library](README.md)

A node is one file of the library, named by the modules it declares; a family of structures that
one file declares, such as the five of `Int8`, is one node. An arrow from one node to another
means that the first needs the second to compile, as the library's MANIFEST records it. An arrow
that a path of other arrows already implies is left out, so that what is left is the shape of the
library and not a wall of lines: the 595 requirements between the 153 files become 258 arrows.
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
  a1["Text and characters<br>(16)"]
  a2["Lists and options<br>(6)"]
  a3["Numbers<br>(26)"]
  a4["Sequences<br>(38)"]
  a5["The operating system<br>(41)"]
  a6["Input and output<br>(14)"]
  a7["The runtime<br>(8)"]
  a6 -- 3 --> a2
  a6 -- 5 --> a3
  a6 -- 4 --> a4
  a6 -- 2 --> a1
  a6 -- 3 --> a5
  a3 -- 1 --> a2
  a3 -- 3 --> a4
  a3 -- 4 --> a1
  a4 -- 2 --> a2
  a4 -- 10 --> a3
  a4 -- 4 --> a1
  a1 -- 1 --> a3
  a1 -- 5 --> a4
  a0 -- 1 --> a6
  a5 -- 12 --> a6
  a5 -- 2 --> a2
  a5 -- 7 --> a3
  a5 -- 2 --> a4
  a5 -- 4 --> a1
  a7 -- 2 --> a6
  a7 -- 2 --> a3
  a7 -- 3 --> a4
  a7 -- 1 --> a1
  a7 -- 3 --> a0
  a7 -- 2 --> a5
```

## The language

```mermaid
flowchart TD
  n0["General"]
  n84(["SML90"])
  n102(["GENERAL"])
  n124(["SML90"])
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
  n97(["BOOL"])
  n98(["BYTE"])
  n99(["CHAR"])
  n125(["STRING"])
  n126(["STRING_CVT"])
  n127(["SUBSTRING"])
  n137(["TEXT"])
  n150["WideString<br>WideSubstring"]
  n151["WideText"]
  n2 --> n1
  n20 --> n19
  n29 --> n20
  n97 --> n1
  n99 --> n20
  n125 --> n20
  n137 --> n99
  n137 --> n125
  n137 --> n127
  n150 --> n125
  n150 --> n127
  n151 --> n150
```

It also needs Numbers (1), Sequences (5).

## Lists and options

```mermaid
flowchart TD
  n3["Option"]
  n4["List"]
  n5["ListPair"]
  n108(["LIST"])
  n109(["LIST_PAIR"])
  n114(["OPTION"])
```

## Numbers

```mermaid
flowchart TD
  n6["IntInf<br>LargeInt"]
  n7["Int"]
  n8["Word<br>SysWord"]
  n9["Word64<br>LargeWord"]
  n10(["WORD"])
  n11(["INTEGER"])
  n12["Int8"]
  n13["Int16"]
  n14["Int32"]
  n15["Int64<br>FixedInt"]
  n16["Word8"]
  n17["Word16"]
  n18["Word32"]
  n21["IEEEReal"]
  n22["Real<br>Math<br>LargeReal<br>Real64"]
  n34["PackWord* (6)"]
  n35["PackReal* (4)"]
  n59["Position"]
  n104(["IEEE_REAL"])
  n106(["INT_INF"])
  n110(["MATH"])
  n119(["PACK_REAL"])
  n120(["PACK_WORD"])
  n135(["REAL"])
  n146["Real32"]
  n147["PackReal32Big<br>PackReal32Little"]
  n7 --> n6
  n8 --> n7
  n9 --> n8
  n10 --> n9
  n11 --> n7
  n12 --> n11
  n13 --> n11
  n14 --> n11
  n15 --> n7
  n16 --> n10
  n17 --> n10
  n18 --> n10
  n22 --> n21
  n22 --> n7
  n35 --> n22
  n35 --> n34
  n59 --> n7
  n106 --> n11
  n106 --> n8
  n135 --> n22
  n135 --> n110
  n146 --> n135
  n146 --> n8
  n147 --> n146
  n147 --> n34
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
  n54["Word64* (5)"]
  n55["LargeWord* (5)"]
  n56["LargeReal* (5)"]
  n57["Real64* (5)"]
  n93(["ARRAY"])
  n94(["ARRAY_SLICE"])
  n131(["VECTOR"])
  n132(["VECTOR_SLICE"])
  n148["Real32* (5)"]
  n149["WideChar* (6)"]
  n24 --> n23
  n25 --> n23
  n26 --> n24
  n26 --> n25
  n28 --> n27
  n30 --> n28
  n31 --> n27
  n32 --> n31
  n33 --> n32
  n36 --> n28
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
  n54 --> n27
  n54 --> n40
  n55 --> n54
  n56 --> n52
  n57 --> n52
  n93 --> n23
  n94 --> n24
  n94 --> n25
  n132 --> n23
  n148 --> n27
  n148 --> n40
  n149 --> n27
  n149 --> n40
```

It also needs Lists and options (2), Text and characters (4), Numbers (10).

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
  n78["INetSock<br>UnixSock<br>GenericSock"]
  n79(["INET6_SOCK"])
  n80["INet6Sock"]
  n81["Unix"]
  n82["Windows"]
  n83["CommandLine"]
  n96(["BIT_FLAGS"])
  n100(["COMMAND_LINE"])
  n101(["DATE"])
  n103(["GENERIC_SOCK"])
  n105(["INET_SOCK"])
  n111(["NET_HOST_DB"])
  n112(["NET_PROT_DB"])
  n113(["NET_SERV_DB"])
  n115(["OS_FILE_SYS"])
  n116(["OS_IO"])
  n117(["OS_PATH"])
  n118(["OS_PROCESS"])
  n121(["POSIX_PROC_ENV"])
  n122(["POSIX_SIGNAL"])
  n123(["POSIX_SYS_DB"])
  n129(["TIMER"])
  n130(["UNIX_SOCK"])
  n133(["POSIX_TTY"])
  n134(["POSIX_IO"])
  n136(["OS"])
  n139(["WINDOWS"])
  n140(["UNIX"])
  n141(["SOCKET"])
  n142(["POSIX_PROCESS"])
  n143(["POSIX_FILE_SYS"])
  n144(["POSIX_ERROR"])
  n145(["POSIX"])
  n61 --> n60
  n62 --> n61
  n63 --> n61
  n64 --> n61
  n76 --> n61
  n78 --> n77
  n78 --> n76
  n79 --> n76
  n80 --> n76
  n81 --> n136
  n81 --> n64
  n81 --> n70
  n82 --> n136
  n82 --> n64
  n82 --> n70
  n101 --> n61
  n103 --> n76
  n105 --> n77
  n105 --> n76
  n115 --> n61
  n116 --> n61
  n118 --> n61
  n121 --> n61
  n129 --> n61
  n130 --> n76
  n133 --> n96
  n134 --> n96
  n136 --> n115
  n136 --> n116
  n136 --> n117
  n136 --> n118
  n139 --> n96
  n139 --> n136
  n139 --> n64
  n140 --> n136
  n140 --> n64
  n141 --> n77
  n141 --> n136
  n141 --> n64
  n142 --> n96
  n142 --> n136
  n142 --> n64
  n143 --> n96
  n143 --> n136
  n143 --> n64
  n144 --> n136
  n144 --> n64
  n145 --> n144
  n145 --> n143
  n145 --> n134
  n145 --> n142
  n145 --> n121
  n145 --> n122
  n145 --> n123
  n145 --> n133
```

It also needs Numbers (7), Text and characters (4), Lists and options (2), Input and output (12), Sequences (2).

## Input and output

```mermaid
flowchart TD
  n65(["IO"])
  n66(["PRIM_IO"])
  n67(["STREAM_IO"])
  n68["TextPrimIO"]
  n69["BinPrimIO"]
  n71(["IMPERATIVE_IO"])
  n72["PrimIO<br>StreamIO<br>ImperativeIO"]
  n73["TextIO"]
  n75["BinIO"]
  n95(["BIN_IO"])
  n107(["IO"])
  n128(["TEXT_STREAM_IO"])
  n138(["TEXT_IO"])
  n152["WideTextPrimIO<br>WideTextIO"]
  n67 --> n107
  n67 --> n65
  n68 --> n107
  n68 --> n65
  n69 --> n107
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
  n95 --> n69
  n95 --> n71
  n128 --> n67
  n138 --> n128
  n138 --> n68
  n152 --> n73
```

It also needs The operating system (3), Numbers (5), Sequences (4), Lists and options (3), Text and characters (2).

## The runtime

```mermaid
flowchart TD
  n85(["RUNTIME"])
  n86["Runtime"]
  n87(["DYNAMIC"])
  n88["Dynamic"]
  n89(["COMPILER"])
  n90(["TERMINAL"])
  n91["Terminal"]
  n92["Compiler"]
  n88 --> n87
  n88 --> n86
```

It also needs Input and output (2), Sequences (3), Text and characters (1), The language (3), The operating system (2), Numbers (2).

---

<sub>Generated by runedoc from the MANIFEST; do not edit.</sub>
