# What depends on what

[The Standard ML Basis Library](README.md)

A node is one file of the library, named by the modules it declares; a family of structures that
one file declares, such as the five of `Int8`, is one node. An arrow from one node to another
means that the first needs the second to compile, as the library's MANIFEST records it. An arrow
that a path of other arrows already implies is left out, so that what is left is the shape of the
library and not a wall of lines: the 591 requirements between the 151 files become 256 arrows.
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
  a7["The runtime<br>(6)"]
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
  a4 -- 3 --> a1
  a1 -- 1 --> a3
  a1 -- 6 --> a4
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
```

## The language

```mermaid
flowchart TD
  n0["General"]
  n84(["SML90"])
  n100(["GENERAL"])
  n122(["SML90"])
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
  n95(["BOOL"])
  n96(["BYTE"])
  n97(["CHAR"])
  n123(["STRING"])
  n124(["STRING_CVT"])
  n125(["SUBSTRING"])
  n135(["TEXT"])
  n147["WideChar* (6)"]
  n148["WideString<br>WideSubstring"]
  n149["WideText"]
  n2 --> n1
  n20 --> n19
  n29 --> n20
  n95 --> n1
  n97 --> n20
  n123 --> n20
  n135 --> n97
  n135 --> n123
  n135 --> n125
  n147 --> n97
  n148 --> n147
  n148 --> n123
  n148 --> n125
  n149 --> n148
```

It also needs Numbers (1), Sequences (6).

## Lists and options

```mermaid
flowchart TD
  n3["Option"]
  n4["List"]
  n5["ListPair"]
  n106(["LIST"])
  n107(["LIST_PAIR"])
  n112(["OPTION"])
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
  n15["FixedInt<br>Int64"]
  n16["Word8"]
  n17["Word16"]
  n18["Word32"]
  n21["IEEEReal"]
  n22["Real<br>Math<br>LargeReal<br>Real64"]
  n34["PackWord* (6)"]
  n35["PackReal* (4)"]
  n59["Position"]
  n102(["IEEE_REAL"])
  n104(["INT_INF"])
  n108(["MATH"])
  n117(["PACK_REAL"])
  n118(["PACK_WORD"])
  n133(["REAL"])
  n144["Real32"]
  n145["PackReal32Big<br>PackReal32Little"]
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
  n104 --> n11
  n104 --> n8
  n133 --> n22
  n133 --> n108
  n144 --> n133
  n144 --> n8
  n145 --> n144
  n145 --> n34
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
  n91(["ARRAY"])
  n92(["ARRAY_SLICE"])
  n129(["VECTOR"])
  n130(["VECTOR_SLICE"])
  n146["Real32* (5)"]
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
  n91 --> n23
  n92 --> n24
  n92 --> n25
  n130 --> n23
  n146 --> n27
  n146 --> n40
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
  n94(["BIT_FLAGS"])
  n98(["COMMAND_LINE"])
  n99(["DATE"])
  n101(["GENERIC_SOCK"])
  n103(["INET_SOCK"])
  n109(["NET_HOST_DB"])
  n110(["NET_PROT_DB"])
  n111(["NET_SERV_DB"])
  n113(["OS_FILE_SYS"])
  n114(["OS_IO"])
  n115(["OS_PATH"])
  n116(["OS_PROCESS"])
  n119(["POSIX_PROC_ENV"])
  n120(["POSIX_SIGNAL"])
  n121(["POSIX_SYS_DB"])
  n127(["TIMER"])
  n128(["UNIX_SOCK"])
  n131(["POSIX_TTY"])
  n132(["POSIX_IO"])
  n134(["OS"])
  n137(["WINDOWS"])
  n138(["UNIX"])
  n139(["SOCKET"])
  n140(["POSIX_PROCESS"])
  n141(["POSIX_FILE_SYS"])
  n142(["POSIX_ERROR"])
  n143(["POSIX"])
  n61 --> n60
  n62 --> n61
  n63 --> n61
  n64 --> n61
  n76 --> n61
  n78 --> n77
  n78 --> n76
  n79 --> n76
  n80 --> n76
  n81 --> n134
  n81 --> n64
  n81 --> n70
  n82 --> n134
  n82 --> n64
  n82 --> n70
  n99 --> n61
  n101 --> n76
  n103 --> n77
  n103 --> n76
  n113 --> n61
  n114 --> n61
  n116 --> n61
  n119 --> n61
  n127 --> n61
  n128 --> n76
  n131 --> n94
  n132 --> n94
  n134 --> n113
  n134 --> n114
  n134 --> n115
  n134 --> n116
  n137 --> n94
  n137 --> n134
  n137 --> n64
  n138 --> n134
  n138 --> n64
  n139 --> n77
  n139 --> n134
  n139 --> n64
  n140 --> n94
  n140 --> n134
  n140 --> n64
  n141 --> n94
  n141 --> n134
  n141 --> n64
  n142 --> n134
  n142 --> n64
  n143 --> n142
  n143 --> n141
  n143 --> n132
  n143 --> n140
  n143 --> n119
  n143 --> n120
  n143 --> n121
  n143 --> n131
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
  n72["ImperativeIO<br>PrimIO<br>StreamIO"]
  n73["TextIO"]
  n75["BinIO"]
  n93(["BIN_IO"])
  n105(["IO"])
  n126(["TEXT_STREAM_IO"])
  n136(["TEXT_IO"])
  n150["WideTextIO<br>WideTextPrimIO"]
  n67 --> n105
  n67 --> n65
  n68 --> n105
  n68 --> n65
  n69 --> n105
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
  n93 --> n69
  n93 --> n71
  n126 --> n67
  n136 --> n126
  n136 --> n68
  n150 --> n73
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
  n90["Compiler"]
  n88 --> n87
  n88 --> n86
```

It also needs Input and output (2), Sequences (3), Text and characters (1), The language (3), Numbers (2).

---

<sub>Generated by runedoc from the MANIFEST; do not edit.</sub>
