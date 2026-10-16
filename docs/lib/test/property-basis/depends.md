# What depends on what

[Property testing: the Basis Library's arbitraries](README.md)

A node is one file of the library, named by the modules it declares; a family of structures that
one file declares, such as the five of `Int8`, is one node. An arrow from one node to another
means that the first needs the second to compile, as the library's MANIFEST records it. An arrow
that a path of other arrows already implies is left out, so that what is left is the shape of the
library and not a wall of lines: the 198 requirements between the 114 files become 111 arrows.
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
  a0["Property testing<br>(113)"]
  a1["Not in an area<br>(1)"]
  a1 -- 1 --> a0
```

## Property testing

```mermaid
flowchart TD
  n0(["ARB_OF"])
  n1["IntegerArbFn<br>WordArbFn<br>RealArbFn<br>CharArbFn<br>StringArbFn<br>PropertyDimensions<br>SubstringArbFn<br>MonoVectorArbFn<br>MonoArrayArbFn<br>MonoVectorSliceArbFn<br>MonoArraySliceArbFn<br>MonoArray2ArbFn"]
  n2(["DATE_ARB<br>IEEE_REAL_ARB<br>BASIS_DATA_ARB"])
  n3["PropertyAround<br>TimeArb<br>DateArb<br>IEEERealArb<br>BasisDataArb<br>RandomArb"]
  n4["IntArb<br>IntInfArb<br>LargeIntArb<br>PositionArb<br>WordArb<br>Word8Arb<br>LargeWordArb<br>SysWordArb<br>RealArb<br>LargeRealArb"]
  n5["Int8Arb"]
  n6["Int16Arb"]
  n7["Int32Arb"]
  n8["Int64Arb"]
  n9["FixedIntArb"]
  n10["Word16Arb"]
  n11["Word32Arb"]
  n12["Word64Arb"]
  n13["Real32Arb"]
  n14["Real64Arb"]
  n15["CharArb<br>StringArb<br>SubstringArb<br>CharVectorArb<br>CharArrayArb<br>CharVectorSliceArb<br>CharArraySliceArb"]
  n16["WideCharArb"]
  n17["WideStringArb"]
  n18["WideSubstringArb"]
  n20["Word8* (4)"]
  n21["IntArray2Arb"]
  n22["CharArray2Arb"]
  n23["Word8Array2Arb"]
  n24(["SYSTEM_ARB"])
  n25["PropertyScratch<br>SystemArb"]
  n26(["INET6_SOCK_ARB"])
  n27["INet6SockArb"]
  n28(["SML90_ARB"])
  n29["SML90Arb"]
  n30["BoolVectorArb"]
  n31["BoolArrayArb"]
  n32["BoolVectorSliceArb"]
  n33["BoolArraySliceArb"]
  n34["BoolArray2Arb"]
  n35["IntVectorArb"]
  n36["IntArrayArb"]
  n37["IntVectorSliceArb"]
  n38["IntArraySliceArb"]
  n39["Int8VectorArb"]
  n40["Int8ArrayArb"]
  n41["Int8VectorSliceArb"]
  n42["Int8ArraySliceArb"]
  n43["Int8Array2Arb"]
  n44["Int16VectorArb"]
  n45["Int16ArrayArb"]
  n46["Int16VectorSliceArb"]
  n47["Int16ArraySliceArb"]
  n48["Int16Array2Arb"]
  n49["Int32VectorArb"]
  n50["Int32ArrayArb"]
  n51["Int32VectorSliceArb"]
  n52["Int32ArraySliceArb"]
  n53["Int32Array2Arb"]
  n54["Int64VectorArb"]
  n55["Int64ArrayArb"]
  n56["Int64VectorSliceArb"]
  n57["Int64ArraySliceArb"]
  n58["Int64Array2Arb"]
  n59["LargeIntVectorArb"]
  n60["LargeIntArrayArb"]
  n61["LargeIntVectorSliceArb"]
  n62["LargeIntArraySliceArb"]
  n63["LargeIntArray2Arb"]
  n64["RealVectorArb"]
  n65["RealArrayArb"]
  n66["RealVectorSliceArb"]
  n67["RealArraySliceArb"]
  n68["RealArray2Arb"]
  n69["Real32VectorArb"]
  n70["Real32ArrayArb"]
  n71["Real32VectorSliceArb"]
  n72["Real32ArraySliceArb"]
  n73["Real32Array2Arb"]
  n74["Real64VectorArb"]
  n75["Real64ArrayArb"]
  n76["Real64VectorSliceArb"]
  n77["Real64ArraySliceArb"]
  n78["Real64Array2Arb"]
  n79["LargeRealVectorArb"]
  n80["LargeRealArrayArb"]
  n81["LargeRealVectorSliceArb"]
  n82["LargeRealArraySliceArb"]
  n83["LargeRealArray2Arb"]
  n84["WordVectorArb"]
  n85["WordArrayArb"]
  n86["WordVectorSliceArb"]
  n87["WordArraySliceArb"]
  n88["WordArray2Arb"]
  n89["Word16VectorArb"]
  n90["Word16ArrayArb"]
  n91["Word16VectorSliceArb"]
  n92["Word16ArraySliceArb"]
  n93["Word16Array2Arb"]
  n94["Word32VectorArb"]
  n95["Word32ArrayArb"]
  n96["Word32VectorSliceArb"]
  n97["Word32ArraySliceArb"]
  n98["Word32Array2Arb"]
  n99["Word64VectorArb"]
  n100["Word64ArrayArb"]
  n101["Word64VectorSliceArb"]
  n102["Word64ArraySliceArb"]
  n103["Word64Array2Arb"]
  n104["LargeWordVectorArb"]
  n105["LargeWordArrayArb"]
  n106["LargeWordVectorSliceArb"]
  n107["LargeWordArraySliceArb"]
  n108["LargeWordArray2Arb"]
  n109["WideCharVectorArb"]
  n110["WideCharArrayArb"]
  n111["WideCharVectorSliceArb"]
  n112["WideCharArraySliceArb"]
  n113["WideCharArray2Arb"]
  n1 --> n0
  n3 --> n0
  n3 --> n2
  n4 --> n1
  n5 --> n1
  n6 --> n1
  n7 --> n1
  n8 --> n1
  n9 --> n1
  n10 --> n1
  n11 --> n1
  n12 --> n1
  n13 --> n1
  n14 --> n1
  n15 --> n1
  n16 --> n1
  n17 --> n16
  n18 --> n17
  n20 --> n4
  n21 --> n4
  n22 --> n15
  n23 --> n4
  n25 --> n24
  n27 --> n26
  n29 --> n25
  n29 --> n28
  n30 --> n1
  n31 --> n1
  n32 --> n30
  n33 --> n31
  n34 --> n1
  n35 --> n4
  n36 --> n4
  n37 --> n35
  n38 --> n36
  n39 --> n5
  n40 --> n5
  n41 --> n39
  n42 --> n40
  n43 --> n5
  n44 --> n6
  n45 --> n6
  n46 --> n44
  n47 --> n45
  n48 --> n6
  n49 --> n7
  n50 --> n7
  n51 --> n49
  n52 --> n50
  n53 --> n7
  n54 --> n8
  n55 --> n8
  n56 --> n54
  n57 --> n55
  n58 --> n8
  n59 --> n4
  n60 --> n4
  n61 --> n59
  n62 --> n60
  n63 --> n4
  n64 --> n4
  n65 --> n4
  n66 --> n64
  n67 --> n65
  n68 --> n4
  n69 --> n13
  n70 --> n13
  n71 --> n69
  n72 --> n70
  n73 --> n13
  n74 --> n14
  n75 --> n14
  n76 --> n74
  n77 --> n75
  n78 --> n14
  n79 --> n4
  n80 --> n4
  n81 --> n79
  n82 --> n80
  n83 --> n4
  n84 --> n4
  n85 --> n4
  n86 --> n84
  n87 --> n85
  n88 --> n4
  n89 --> n10
  n90 --> n10
  n91 --> n89
  n92 --> n90
  n93 --> n10
  n94 --> n11
  n95 --> n11
  n96 --> n94
  n97 --> n95
  n98 --> n11
  n99 --> n12
  n100 --> n12
  n101 --> n99
  n102 --> n100
  n103 --> n12
  n104 --> n4
  n105 --> n4
  n106 --> n104
  n107 --> n105
  n108 --> n4
  n109 --> n16
  n110 --> n16
  n111 --> n109
  n112 --> n110
  n113 --> n16
```

## Not in an area

```mermaid
flowchart TD
  n19["WideTextArb"]
```

It also needs Property testing (1).

---

<sub>Generated by runedoc from the MANIFEST; do not edit.</sub>
