structure Pilot =
struct
  structure K=BenchMultilayer
  structure F=BenchMultilayerFiles
  val directory=""
  val samples=F.data(directory^"samples.input")
  fun run epochs=
    let val random=BenchOCamlRandom.default()
        fun draw()=BenchOCamlRandom.real random 2.0-1.0
        val network=K.fit epochs samples draw
        val expected=F.reference(directory^"epochs-"^Int.toString epochs^".expected")
        val _=F.check expected network samples
    in print("PASS all parameters/predictions at epochs "^Int.toString epochs^"\n")end
  val _=List.app run [0,1,20]
  val _=print "SUMMARY 3 checks, 0 failed\n"
end
