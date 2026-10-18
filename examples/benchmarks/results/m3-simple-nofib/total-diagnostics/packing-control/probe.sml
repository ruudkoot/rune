fun hex v=String.concat(List.tabulate(Word8Vector.length v,fn i=>
 let val s=Word8.fmt StringCvt.HEX(Word8Vector.sub(v,i))in if size s=1 then"0"^s else s end))
val big=Word8Vector.fromList[0w63,0w240,0w0,0w0,0w0,0w0,0w0,0w0]
val _=print("BIG-FLAG\t"^Bool.toString PackReal64Big.isBigEndian^"\n")
val _=print("BIG-BYTES-ONE\t"^hex(PackReal64Big.toBytes 1.0)^"\n")
val _=print("LITTLE-BYTES-ONE\t"^hex(PackReal64Little.toBytes 1.0)^"\n")
val _=print("BIG-FROM-BIG-IS-ONE\t"^Bool.toString(Real.==(PackReal64Big.fromBytes big,1.0))^"\n")
val _=print("BIG-SUB-BIG-IS-ONE\t"^Bool.toString(Real.==(PackReal64Big.subVec(big,0),1.0))^"\n")
