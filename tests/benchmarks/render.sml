structure RenderBenchTests =
struct
  fun write(path,bytes)=let val out=BinIO.openOut path in BinIO.output(out,bytes);BinIO.closeOut out end
  val prefix=Byte.stringToBytes "P6\n# test\n1 1\n255\n"
  fun image values=Word8Vector.concat[prefix,Word8Vector.fromList(List.map Word8.fromInt values)]
  val _=write("reference.ppm",image[10,20,30])
  val _=write("alternate.ppm",image[100,110,120])
  fun accepted values=(write("actual.ppm",image values);ChessImageCheck.same("actual.ppm","reference.ppm","alternate.ppm")="1")
  fun rejected values=(accepted values;false) handle Fail _=>true
  val _=T.check("benchmark.render/reference",fn()=>accepted[10,20,30])
  val _=T.check("benchmark.render/channel-bound",fn()=>accepted[12,18,31])
  val _=T.check("benchmark.render/alternate",fn()=>accepted[99,111,120])
  val _=T.check("benchmark.render/outside-bound",fn()=>rejected[13,20,30])
  val _=T.check("benchmark.render/no-mixed-channels",fn()=>rejected[10,110,30])
  val _=T.check("benchmark.render/header",fn()=>
    (write("actual.ppm",Byte.stringToBytes "P6\n# bad\n1 1\n255\nabcdefgh");
     ChessImageCheck.same("actual.ppm","reference.ppm","alternate.ppm");false) handle Fail _=>true)
end
