structure B=BenchStdlibText
val bytes=B.Bytes.ofString B.text
val _=print(Int.toString(B.Bytes.length bytes)^" "^Int.toString(B.Bytes.index bytes #"r")^"\n")
val _=if B.Bytes.toString bytes=B.text then()else raise Fail"roundtrip"
val _=print(B.Bytes.toString(B.Bytes.concat(B.Bytes.ofString" ")(List.map B.Bytes.ofString["I","AM","A","FISH"]))^"\n")
val _=print(B.trimString"We need a trim\n\n\n\n\n"^"\n")
