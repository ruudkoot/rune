# What depends on what

[The Standard ML Basis Library](README.md)

A node is one file of the library, named by the modules it declares; a family of structures that
one file declares, such as the five of `Int8`, is one node. An arrow from one node to another
means that the first needs the second to compile, as the library's MANIFEST records it. An arrow
that a path of other arrows already implies is left out, so that what is left is the shape of the
library and not a wall of lines: the 606 requirements between the 149 files become 259 arrows.
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
  a7["The runtime<br>(4)"]
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
  a5 -- 14 --> a6
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
  n98(["GENERAL"])
  n120(["SML90"])
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
  n93(["BOOL"])
  n94(["BYTE"])
  n95(["CHAR"])
  n121(["STRING"])
  n122(["STRING_CVT"])
  n123(["SUBSTRING"])
  n133(["TEXT"])
  n145["WideChar* (6)"]
  n146["WideString<br>WideSubstring"]
  n147["WideText"]
  n2 --> n1
  n20 --> n19
  n29 --> n20
  n93 --> n1
  n95 --> n20
  n121 --> n29
  n123 --> n29
  n133 --> n95
  n133 --> n121
  n133 --> n123
  n145 --> n95
  n146 --> n145
  n146 --> n121
  n146 --> n123
  n147 --> n146
```

It also needs Numbers (1), Sequences (6).

## Lists and options

```mermaid
flowchart TD
  n3["Option"]
  n4["List"]
  n5["ListPair"]
  n104(["LIST"])
  n105(["LIST_PAIR"])
  n110(["OPTION"])
  n110 --> n3
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
  n100(["IEEE_REAL"])
  n102(["INT_INF"])
  n106(["MATH"])
  n115(["PACK_REAL"])
  n116(["PACK_WORD"])
  n131(["REAL"])
  n142["Real32"]
  n143["PackReal32Big<br>PackReal32Little"]
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
  n102 --> n11
  n102 --> n8
  n131 --> n22
  n131 --> n106
  n142 --> n131
  n142 --> n8
  n143 --> n142
  n143 --> n34
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
  n89(["ARRAY"])
  n90(["ARRAY_SLICE"])
  n127(["VECTOR"])
  n128(["VECTOR_SLICE"])
  n144["Real32* (5)"]
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
  n89 --> n23
  n90 --> n24
  n90 --> n25
  n128 --> n23
  n144 --> n27
  n144 --> n40
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
  n92(["BIT_FLAGS"])
  n96(["COMMAND_LINE"])
  n97(["DATE"])
  n99(["GENERIC_SOCK"])
  n101(["INET_SOCK"])
  n107(["NET_HOST_DB"])
  n108(["NET_PROT_DB"])
  n109(["NET_SERV_DB"])
  n111(["OS_FILE_SYS"])
  n112(["OS_IO"])
  n113(["OS_PATH"])
  n114(["OS_PROCESS"])
  n117(["POSIX_PROC_ENV"])
  n118(["POSIX_SIGNAL"])
  n119(["POSIX_SYS_DB"])
  n125(["TIMER"])
  n126(["UNIX_SOCK"])
  n129(["POSIX_TTY"])
  n130(["POSIX_IO"])
  n132(["OS"])
  n135(["WINDOWS"])
  n136(["UNIX"])
  n137(["SOCKET"])
  n138(["POSIX_PROCESS"])
  n139(["POSIX_FILE_SYS"])
  n140(["POSIX_ERROR"])
  n141(["POSIX"])
  n61 --> n60
  n62 --> n61
  n63 --> n61
  n64 --> n61
  n76 --> n61
  n78 --> n77
  n78 --> n76
  n79 --> n76
  n80 --> n76
  n81 --> n132
  n81 --> n64
  n81 --> n70
  n82 --> n132
  n82 --> n64
  n82 --> n70
  n97 --> n63
  n99 --> n76
  n101 --> n77
  n101 --> n76
  n111 --> n61
  n112 --> n61
  n114 --> n61
  n117 --> n61
  n125 --> n61
  n126 --> n76
  n129 --> n92
  n130 --> n92
  n132 --> n111
  n132 --> n112
  n132 --> n113
  n132 --> n114
  n135 --> n92
  n135 --> n132
  n135 --> n64
  n136 --> n132
  n136 --> n64
  n137 --> n77
  n137 --> n132
  n137 --> n64
  n138 --> n92
  n138 --> n132
  n138 --> n64
  n139 --> n92
  n139 --> n132
  n139 --> n64
  n140 --> n132
  n140 --> n64
  n141 --> n140
  n141 --> n139
  n141 --> n130
  n141 --> n138
  n141 --> n117
  n141 --> n118
  n141 --> n119
  n141 --> n129
```

It also needs Numbers (7), Text and characters (4), Lists and options (2), Input and output (14), Sequences (2).

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
  n91(["BIN_IO"])
  n103(["IO"])
  n124(["TEXT_STREAM_IO"])
  n134(["TEXT_IO"])
  n148["WideTextIO<br>WideTextPrimIO"]
  n67 --> n103
  n67 --> n65
  n68 --> n103
  n68 --> n65
  n69 --> n103
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
  n91 --> n69
  n91 --> n72
  n124 --> n67
  n134 --> n72
  n134 --> n124
  n134 --> n68
  n148 --> n73
```

It also needs The operating system (3), Numbers (5), Sequences (4), Lists and options (3), Text and characters (2).

## The runtime

```mermaid
flowchart TD
  n85(["RUNTIME"])
  n86["Runtime"]
  n87(["COMPILER"])
  n88["Compiler"]
```

It also needs Input and output (2), Sequences (3), Text and characters (1), The language (3), Numbers (2).

---

<sub>Generated by runedoc from the MANIFEST; do not edit.</sub>
