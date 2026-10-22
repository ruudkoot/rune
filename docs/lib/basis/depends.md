# What depends on what

[The Standard ML Basis Library](README.md)

A node is one file of the library, named by the modules it declares; a family of structures that
one file declares, such as the five of `Int8`, is one node. An arrow from one node to another
means that the first needs the second to compile, as the library's MANIFEST records it. An arrow
that a path of other arrows already implies is left out, so that what is left is the shape of the
library and not a wall of lines: the 610 requirements between the 162 files become 269 arrows.
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
  a7["The runtime<br>(16)"]
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
  a7 -- 5 --> a5
```

## The language

```mermaid
flowchart TD
  n0["General"]
  n85(["SML90"])
  n111(["GENERAL"])
  n133(["SML90"])
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
  n106(["BOOL"])
  n107(["BYTE"])
  n108(["CHAR"])
  n134(["STRING"])
  n135(["STRING_CVT"])
  n136(["SUBSTRING"])
  n146(["TEXT"])
  n158["Wide* (8)"]
  n159["WideStringCvt"]
  n160["WideText"]
  n2 --> n1
  n21 --> n20
  n30 --> n21
  n106 --> n1
  n108 --> n21
  n134 --> n21
  n146 --> n108
  n146 --> n134
  n146 --> n136
  n158 --> n108
  n158 --> n134
  n158 --> n136
  n159 --> n135
  n159 --> n158
  n160 --> n158
```

It also needs Numbers (1), Lists and options (1), Sequences (6).

## Lists and options

```mermaid
flowchart TD
  n3["Option"]
  n4["List"]
  n5["ListPair"]
  n117(["LIST"])
  n118(["LIST_PAIR"])
  n123(["OPTION"])
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
  n113(["IEEE_REAL"])
  n115(["INT_INF"])
  n119(["MATH"])
  n128(["PACK_REAL"])
  n129(["PACK_WORD"])
  n144(["REAL"])
  n155["Real32"]
  n156["PackReal32Big<br>PackReal32Little"]
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
  n115 --> n12
  n115 --> n8
  n144 --> n23
  n144 --> n119
  n155 --> n144
  n155 --> n8
  n156 --> n155
  n156 --> n35
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
  n102(["ARRAY"])
  n103(["ARRAY_SLICE"])
  n140(["VECTOR"])
  n141(["VECTOR_SLICE"])
  n157["Real32* (5)"]
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
  n102 --> n24
  n103 --> n25
  n103 --> n26
  n141 --> n24
  n157 --> n28
  n157 --> n41
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
  n105(["BIT_FLAGS"])
  n109(["COMMAND_LINE"])
  n110(["DATE"])
  n112(["GENERIC_SOCK"])
  n114(["INET_SOCK"])
  n120(["NET_HOST_DB"])
  n121(["NET_PROT_DB"])
  n122(["NET_SERV_DB"])
  n124(["OS_FILE_SYS"])
  n125(["OS_IO"])
  n126(["OS_PATH"])
  n127(["OS_PROCESS"])
  n130(["POSIX_PROC_ENV"])
  n131(["POSIX_SIGNAL"])
  n132(["POSIX_SYS_DB"])
  n138(["TIMER"])
  n139(["UNIX_SOCK"])
  n142(["POSIX_TTY"])
  n143(["POSIX_IO"])
  n145(["OS"])
  n148(["WINDOWS"])
  n149(["UNIX"])
  n150(["SOCKET"])
  n151(["POSIX_PROCESS"])
  n152(["POSIX_FILE_SYS"])
  n153(["POSIX_ERROR"])
  n154(["POSIX"])
  n62 --> n61
  n63 --> n62
  n64 --> n62
  n65 --> n62
  n77 --> n62
  n79 --> n78
  n79 --> n77
  n80 --> n77
  n81 --> n77
  n82 --> n145
  n82 --> n65
  n82 --> n71
  n83 --> n145
  n83 --> n65
  n83 --> n71
  n110 --> n62
  n112 --> n77
  n114 --> n78
  n114 --> n77
  n124 --> n62
  n125 --> n62
  n127 --> n62
  n130 --> n62
  n138 --> n62
  n139 --> n77
  n142 --> n105
  n143 --> n105
  n145 --> n124
  n145 --> n125
  n145 --> n126
  n145 --> n127
  n148 --> n105
  n148 --> n145
  n148 --> n65
  n149 --> n145
  n149 --> n65
  n150 --> n78
  n150 --> n145
  n150 --> n65
  n151 --> n105
  n151 --> n145
  n151 --> n65
  n152 --> n105
  n152 --> n145
  n152 --> n65
  n153 --> n145
  n153 --> n65
  n154 --> n153
  n154 --> n152
  n154 --> n143
  n154 --> n151
  n154 --> n130
  n154 --> n131
  n154 --> n132
  n154 --> n142
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
  n104(["BIN_IO"])
  n116(["IO"])
  n137(["TEXT_STREAM_IO"])
  n147(["TEXT_IO"])
  n161["WideTextPrimIO<br>WideTextIO"]
  n68 --> n116
  n68 --> n66
  n69 --> n116
  n69 --> n66
  n70 --> n116
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
  n104 --> n70
  n104 --> n72
  n137 --> n68
  n147 --> n137
  n161 --> n74
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
  n95(["PTY"])
  n96["Pty"]
  n97["Compiler"]
  n98(["REPL"])
  n99["Repl"]
  n100(["DISPLAY"])
  n101["Display"]
  n89 --> n88
  n89 --> n87
  n95 --> n94
```

It also needs Input and output (2), Sequences (3), Text and characters (2), The language (3), The operating system (5), Numbers (2).

---

<sub>Generated by runedoc from the MANIFEST; do not edit.</sub>
