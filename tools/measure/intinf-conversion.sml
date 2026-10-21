structure MeasureIntInfConversion =
struct
  open MeasureIntInfCommon
  fun main args =
    let val opts=options args val ()=checkedOptions ["--samples","--out"] opts val samples=samples opts "7"
        val output=fromRoot (option opts "--out" "tests/out/intinf/conversion") val ()=mkdirs output val run=runner output
        val fixture=readJson (fromRoot "tools/measure/fixtures/conversion-v1.json") val report=base samples 1 val ()=current report
        val ()=List.app (fn (key,v) => set report key v) [("seed",field "seed" fixture),("iterations",number 50000),("results",obj []),
              ("description",str "GMP pow(1) includes import, copy, export and result allocation; storage roundtrip includes scratch allocation. Neither is isolated import latency.")]
        fun one row =
          let val bits=intText (MeasureMMU.exact (field "bits" row)) val bytes=List.map (Word8.fromInt o IntInf.toInt o MeasureMMU.exact) (array (field "bytes" row))
              val packed=Byte.bytesToString (Word8Vector.fromList bytes) val ()=write (output ^ "/" ^ bits ^ ".input",packed)
              val literal="\"" ^ String.translate (fn c => "\\" ^ StringCvt.padLeft #"0" 3 (Int.toString (Char.ord c))) packed ^ "\""
              val programs=List.map (fn (mode,expression) =>
                let val path=output ^ "/" ^ bits ^ "-" ^ mode ^ ".sml" val rbc=OS.Path.base path ^ ".rbc"
                    val source="val native = _prim \"intinf_power\" : bool * string * int -> bool * string\nval decode = _prim \"intinf_unpack\" : string * int -> int array\nval encode = _prim \"intinf_pack\" : int array * int * int -> string\nval packed = " ^ literal ^ "\nval answer = ref \"\"\nfun loop 0 = () | loop n = (answer := " ^ expression ^ "; loop(n-1))\nval start = Time.now()\nval () = loop 50000\nval elapsed = Time.-(Time.now(),start)\nval () = if !answer=packed then print(\"TIMING \" ^ Time.fmt 6 elapsed ^ \"\\n\") else raise Fail \"roundtrip\"\n"
                    val ()=write (path,source) val _=run root [fromRoot "bin/rune","--allow-prim","-o",rbc,path]
                in (mode,rbc) end) [("gmp","#2(native(false,packed,1))"),("storage","encode(decode(packed,30)," ^ Int.toString ((length bytes*8+29) div 30) ^ ",30)")]
              val gmp=ref [] val storage=ref []
              fun sample mode measured=
                let val program= #2 (valOf (List.find (fn (key,_) => key=mode) programs)) val stdout= #output (run root [fromRoot "bin/runevm","--intinf=gmp",program])
                    val n=kernel "" stdout val dest=if mode="gmp" then gmp else storage
                in if measured then dest:= !dest @ [n] else () end
              val ()=pairs samples 1 ["gmp","storage"] sample
              val stats=List.map (fn (mode,program) => (mode,str (#errors (run root [fromRoot "bin/runevm","--intinf=gmp","--count","--stats","--intinf-stats",program])))) programs
              val medians=obj [("gmp",real (median (!gmp))),("storage",real (median (!storage)))]
              val entry=obj [("runs",obj [("gmp",values (!gmp)),("storage",values (!storage))]),("median_seconds",medians),("input_sha256",str (hash (output ^ "/" ^ bits ^ ".input"))),("stats",obj stats)]
          in add report "results" bits entry;save output report;say (bits ^ " " ^ Json.encode medians ^ "\n") end
    in List.app one (array (field "inputs" fixture));0 end
end
