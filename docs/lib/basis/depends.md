# What depends on what

[The Standard ML Basis Library](README.md)

A node is one file of the library, named by the modules it declares; a family of structures that
one file declares, such as the five of `Int8`, is one node. An arrow from one node to another
means that the first needs the second to compile, as the library's MANIFEST records it. An arrow
that a path of other arrows already implies is left out, so that what is left is the shape of the
library and not a wall of lines: the 606 requirements between the 160 files become 267 arrows.
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
  a3["Numbers<br>(27)"]
  a4["Sequences<br>(37)"]
  a5["The operating system<br>(41)"]
  a6["Input and output<br>(14)"]
  a7["The runtime<br>(14)"]
  a6 -- 3 --> a2
  a6 -- 5 --> a3
  a6 -- 3 --> a4
  a6 -- 2 --> a1
  a6 -- 3 --> a5
  a3 -- 2 --> a2
  a3 -- 3 --> a4
  a3 -- 4 --> a1
  a4 -- 2 --> a2
  a4 -- 10 --> a3
  a4 -- 3 --> a1
  a1 -- 1 --> a2
  a1 -- 1 --> a3
  a1 -- 6 --> a4
  a0 -- 1 --> a6
  a5 -- 12 --> a6
  a5 -- 2 --> a2
  a5 -- 10 --> a3
  a5 -- 2 --> a4
  a5 -- 4 --> a1
  a7 -- 2 --> a6
  a7 -- 2 --> a3
  a7 -- 3 --> a4
  a7 -- 2 --> a1
  a7 -- 3 --> a0
  a7 -- 4 --> a5
```

## The language

```mermaid
flowchart TD
  n0["General"]
  n85(["SML90"])
  n109(["GENERAL"])
  n131(["SML90"])
```

It also needs Input and output (1).

## Text and characters

```mermaid
flowchart TD
  n1["StringCvt"]
  n2["Bool"]
  n20["Char"]
  n21["String"]
  n30["Substring"]
  n59["Text"]
  n75["Byte"]
  n104(["BOOL"])
  n105(["BYTE"])
  n106(["CHAR"])
  n132(["STRING"])
  n133(["STRING_CVT"])
  n134(["SUBSTRING"])
  n144(["TEXT"])
  n156["Wide* (8)"]
  n157["WideStringCvt"]
  n158["WideText"]
  n2 --> n1
  n21 --> n20
  n30 --> n21
  n104 --> n1
  n106 --> n21
  n132 --> n21
  n144 --> n106
  n144 --> n132
  n144 --> n134
  n156 --> n106
  n156 --> n132
  n156 --> n134
  n157 --> n133
  n157 --> n156
  n158 --> n156
```

It also needs Numbers (1), Lists and options (1), Sequences (6).

## Lists and options

```mermaid
flowchart TD
  n3["Option"]
  n4["List"]
  n5["ListPair"]
  n115(["LIST"])
  n116(["LIST_PAIR"])
  n121(["OPTION"])
```

## Numbers

```mermaid
flowchart TD
  n6["IntInf<br>LargeInt"]
  n7["Int"]
  n8["Word"]
  n9["Word64<br>LargeWord"]
  n10(["WORD"])
  n11["SysWord"]
  n12(["INTEGER"])
  n13["Int8"]
  n14["Int16"]
  n15["Int32"]
  n16["Int64<br>FixedInt"]
  n17["Word8"]
  n18["Word16"]
  n19["Word32"]
  n22["IEEEReal"]
  n23["Real<br>Math<br>LargeReal<br>Real64"]
  n35["PackWord* (6)"]
  n36["PackReal* (4)"]
  n60["Position"]
  n111(["IEEE_REAL"])
  n113(["INT_INF"])
  n117(["MATH"])
  n126(["PACK_REAL"])
  n127(["PACK_WORD"])
  n142(["REAL"])
  n153["Real32"]
  n154["PackReal32Big<br>PackReal32Little"]
  n7 --> n6
  n8 --> n7
  n9 --> n8
  n10 --> n9
  n11 --> n10
  n12 --> n7
  n13 --> n12
  n14 --> n12
  n15 --> n12
  n16 --> n7
  n17 --> n10
  n18 --> n10
  n19 --> n10
  n23 --> n22
  n23 --> n7
  n36 --> n23
  n36 --> n35
  n60 --> n12
  n60 --> n16
  n113 --> n12
  n113 --> n8
  n142 --> n23
  n142 --> n117
  n153 --> n142
  n153 --> n8
  n154 --> n153
  n154 --> n35
```

It also needs Text and characters (4), Lists and options (2), Sequences (3).

## Sequences

```mermaid
flowchart TD
  n24["Vector"]
  n25["Array"]
  n26["VectorSlice"]
  n27["ArraySlice"]
  n28(["MONO_* (4)"])
  n29["CharVector"]
  n31["CharVectorSlice"]
  n32["Word8Vector<br>Word8VectorSlice"]
  n33["Word8Array"]
  n34["Word8ArraySlice"]
  n37["CharArray"]
  n38["CharArraySlice"]
  n39(["ARRAY2"])
  n40["Array2"]
  n41(["MONO_ARRAY2"])
  n42["CharArray2"]
  n43["Word8Array2"]
  n44["Bool* (5)"]
  n45["Int* (5)"]
  n46["Int8* (5)"]
  n47["Int16* (5)"]
  n48["Int32* (5)"]
  n49["LargeInt* (5)"]
  n50["Word* (5)"]
  n51["Word16* (5)"]
  n52["Word32* (5)"]
  n53["Real* (5)"]
  n54["Int64* (5)"]
  n55["Word64* (5)"]
  n56["LargeWord* (5)"]
  n57["LargeReal* (5)"]
  n58["Real64* (5)"]
  n100(["ARRAY"])
  n101(["ARRAY_SLICE"])
  n138(["VECTOR"])
  n139(["VECTOR_SLICE"])
  n155["Real32* (5)"]
  n25 --> n24
  n26 --> n24
  n27 --> n25
  n27 --> n26
  n29 --> n28
  n31 --> n29
  n32 --> n28
  n33 --> n32
  n34 --> n33
  n37 --> n29
  n38 --> n37
  n38 --> n31
  n39 --> n24
  n40 --> n39
  n40 --> n25
  n41 --> n40
  n42 --> n29
  n42 --> n41
  n43 --> n41
  n43 --> n32
  n44 --> n28
  n44 --> n41
  n45 --> n28
  n45 --> n41
  n46 --> n28
  n46 --> n41
  n47 --> n28
  n47 --> n41
  n48 --> n28
  n48 --> n41
  n49 --> n28
  n49 --> n41
  n50 --> n28
  n50 --> n41
  n51 --> n28
  n51 --> n41
  n52 --> n28
  n52 --> n41
  n53 --> n28
  n53 --> n41
  n54 --> n28
  n54 --> n41
  n55 --> n28
  n55 --> n41
  n56 --> n55
  n57 --> n53
  n58 --> n53
  n100 --> n24
  n101 --> n25
  n101 --> n26
  n139 --> n24
  n155 --> n28
  n155 --> n41
```

It also needs Lists and options (2), Text and characters (3), Numbers (10).

## The operating system

```mermaid
flowchart TD
  n61(["TIME"])
  n62["Time"]
  n63["Timer"]
  n64["Date"]
  n65(["OS"])
  n71["Posix"]
  n77["Socket"]
  n78["NetHostDB<br>NetProtDB<br>NetServDB"]
  n79["INetSock<br>UnixSock<br>GenericSock"]
  n80(["INET6_SOCK"])
  n81["INet6Sock"]
  n82["Unix"]
  n83["Windows"]
  n84["CommandLine"]
  n103(["BIT_FLAGS"])
  n107(["COMMAND_LINE"])
  n108(["DATE"])
  n110(["GENERIC_SOCK"])
  n112(["INET_SOCK"])
  n118(["NET_HOST_DB"])
  n119(["NET_PROT_DB"])
  n120(["NET_SERV_DB"])
  n122(["OS_FILE_SYS"])
  n123(["OS_IO"])
  n124(["OS_PATH"])
  n125(["OS_PROCESS"])
  n128(["POSIX_PROC_ENV"])
  n129(["POSIX_SIGNAL"])
  n130(["POSIX_SYS_DB"])
  n136(["TIMER"])
  n137(["UNIX_SOCK"])
  n140(["POSIX_TTY"])
  n141(["POSIX_IO"])
  n143(["OS"])
  n146(["WINDOWS"])
  n147(["UNIX"])
  n148(["SOCKET"])
  n149(["POSIX_PROCESS"])
  n150(["POSIX_FILE_SYS"])
  n151(["POSIX_ERROR"])
  n152(["POSIX"])
  n62 --> n61
  n63 --> n62
  n64 --> n62
  n65 --> n62
  n77 --> n62
  n79 --> n78
  n79 --> n77
  n80 --> n77
  n81 --> n77
  n82 --> n143
  n82 --> n65
  n82 --> n71
  n83 --> n143
  n83 --> n65
  n83 --> n71
  n108 --> n62
  n110 --> n77
  n112 --> n78
  n112 --> n77
  n122 --> n62
  n123 --> n62
  n125 --> n62
  n128 --> n62
  n136 --> n62
  n137 --> n77
  n140 --> n103
  n141 --> n103
  n143 --> n122
  n143 --> n123
  n143 --> n124
  n143 --> n125
  n146 --> n103
  n146 --> n143
  n146 --> n65
  n147 --> n143
  n147 --> n65
  n148 --> n78
  n148 --> n143
  n148 --> n65
  n149 --> n103
  n149 --> n143
  n149 --> n65
  n150 --> n103
  n150 --> n143
  n150 --> n65
  n151 --> n143
  n151 --> n65
  n152 --> n151
  n152 --> n150
  n152 --> n141
  n152 --> n149
  n152 --> n128
  n152 --> n129
  n152 --> n130
  n152 --> n140
```

It also needs Numbers (10), Text and characters (4), Lists and options (2), Input and output (12), Sequences (2).

## Input and output

```mermaid
flowchart TD
  n66(["IO"])
  n67(["PRIM_IO"])
  n68(["STREAM_IO"])
  n69["TextPrimIO"]
  n70["BinPrimIO"]
  n72(["IMPERATIVE_IO"])
  n73["PrimIO<br>StreamIO<br>ImperativeIO"]
  n74["TextIO"]
  n76["BinIO"]
  n102(["BIN_IO"])
  n114(["IO"])
  n135(["TEXT_STREAM_IO"])
  n145(["TEXT_IO"])
  n159["WideTextPrimIO<br>WideTextIO"]
  n68 --> n114
  n68 --> n66
  n69 --> n114
  n69 --> n66
  n70 --> n114
  n70 --> n66
  n72 --> n68
  n73 --> n72
  n73 --> n67
  n74 --> n68
  n74 --> n67
  n74 --> n69
  n76 --> n70
  n76 --> n68
  n76 --> n67
  n102 --> n70
  n102 --> n72
  n135 --> n68
  n145 --> n135
  n159 --> n74
```

It also needs The operating system (3), Numbers (5), Sequences (3), Lists and options (3), Text and characters (2).

## The runtime

```mermaid
flowchart TD
  n86(["RUNTIME"])
  n87["Runtime"]
  n88(["DYNAMIC"])
  n89["Dynamic"]
  n90(["COMPILER"])
  n91(["TERMINAL"])
  n92["Terminal"]
  n93(["SUBPROCESS"])
  n94["Subprocess"]
  n95["Compiler"]
  n96(["REPL"])
  n97["Repl"]
  n98(["DISPLAY"])
  n99["Display"]
  n89 --> n88
  n89 --> n87
```

It also needs Input and output (2), Sequences (3), Text and characters (2), The language (3), The operating system (4), Numbers (2).

---

<sub>Generated by runedoc from the MANIFEST; do not edit.</sub>
