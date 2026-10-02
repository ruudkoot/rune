structure PPMBenchTests =
struct
  fun write(path,bytes)=let val out=BinIO.openOut path in BinIO.output(out,bytes);BinIO.closeOut out end
  fun image header values=Word8Vector.concat[Byte.stringToBytes header,Word8Vector.fromList(List.map Word8.fromInt values)]
  val _=write("reference.ppm",image "P6\n# fixture\n1 1\n255\n" [10,20,30])
  fun accept values=(write("actual.ppm",image "P6\n1 1\n255\n" values);BenchPPM.same("actual.ppm","reference.ppm")="1")
  fun reject values=(accept values;false)handle Fail _=>true
  val _=T.check("benchmark.ppm/every-channel",fn()=>accept[10,20,30])
  val _=T.check("benchmark.ppm/quantization-bound",fn()=>accept[9,21,30])
  val _=T.check("benchmark.ppm/outside-bound",fn()=>reject[10,20,32])
  val _=T.check("benchmark.ppm/trailing-data",fn()=>reject[10,20,30,0])
  val _=T.check("benchmark.ppm/short-data",fn()=>reject[10,20])
  val _=T.check("benchmark.ppm/header",fn()=>
    (write("actual.ppm",image "P5\n1 1\n255\n" [10,20,30]);BenchPPM.same("actual.ppm","reference.ppm");false)handle Fail _=>true)
  val _=T.check("benchmark.ppm/dimensions",fn()=>
    (write("actual.ppm",image "P6\n2 1\n255\n" [10,20,30,10,20,30]);BenchPPM.same("actual.ppm","reference.ppm");false)handle Fail _=>true)
end
