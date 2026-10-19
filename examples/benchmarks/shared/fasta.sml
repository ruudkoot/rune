(* Bryan O'Sullivan's shootout generator, with explicit binary32 table arithmetic. *)
structure BenchFasta =
struct
  val modulus = 139968
  (* Only zero and positive normal finite values occur in this table builder.
     Quantize each operation to 24 significand bits, ties to even. *)
  fun single r = if Real.== (r,0.0) then r else
    if r<0.0 orelse not(Real.isFinite r) then raise Domain else
    let val {man,exp} = Real.toManExp r
        val significand = Real.toInt IEEEReal.TO_NEAREST (man*16777216.0)
    in Real.fromManExp {man=Real.fromInt significand,exp=exp-24} end
  val alu = "GGCCGGGCGCGGTGGCTCACGCCTGTAATCCCAGCACTTTGGGAGGCCGAGGCGGGCGGATCACCTGAGG" ^
    "TCAGGAGTTCGAGACCAGCCTGGCCAACATGGTGAAACCCCGTCTCTACTAAAAATACAAAAATTAGCCGGG" ^
    "CGTGGTGGCGCGCGCCTGTAATCCCAGCTACTCGGGAGGCTGAGGCAGGAGAATCGCTTGAACCCGGGAGGC" ^
    "GGAGGTTGCAGTGAGCCGAGATCGCGCCACTGCACTCCAGCCTGGGCGACAGAGCGAGACTCCGTCTCAAAAA"
  val iub = [(#"a",0.27),(#"c",0.12),(#"g",0.12),(#"t",0.27),(#"B",0.02),
    (#"D",0.02),(#"H",0.02),(#"K",0.02),(#"M",0.02),(#"N",0.02),
    (#"R",0.02),(#"S",0.02),(#"V",0.02),(#"W",0.02),(#"Y",0.02)]
  val homo = [(#"a",0.3029549426680),(#"c",0.1979883004921),
    (#"g",0.1975473066391),(#"t",0.3015094502008)]
  fun cumulative [] = []
    | cumulative ((c,p)::rest) =
        let val first = single p
            fun more [] _ = []
              | more ((c,q)::xs) previous =
                  let val next = single(previous+single q)
                  in (c,next)::more xs next end
        in (c,first)::more rest first end
  fun cutoffs table = List.map (fn (c,p) =>
    (c,Int.min(modulus,Real.floor(single(single(Real.fromInt modulus*p)+1.0)))))
    (cumulative table)
  fun lookup table =
    let fun fill [] _ = []
          | fill ((c,k)::rest) j = String.implode(List.tabulate(k-j,fn _ => c))::fill rest k
        val result = String.concat(fill(cutoffs table)0)
    in if String.size result=modulus then result else raise Fail "incomplete fasta table" end
  fun writeAlu n =
    let fun chunks i =
          let val count = Int.min(60,n-i)
              val line = String.implode(List.tabulate(count,fn j => String.sub(alu,(i+j) mod String.size alu)))
          in (line^"\n")::(if i+count=n then [] else chunks(i+count)) end
    in String.concat(chunks 0) end
  fun make n table seed =
    let val lut = lookup table
        val line = CharArray.array(60,#"\000")
        fun puts count = String.implode(List.tabulate(count,fn i => CharArray.sub(line,i)))^"\n"
        fun generate 0 i seed chunks =
              (String.concat(List.rev(if i>0 then puts i::chunks else chunks)),seed)
          | generate left i seed chunks =
              let val next = (seed*3877+29573) mod modulus
                  val _ = CharArray.update(line,i,String.sub(lut,next))
              in if i+1>=60 then generate(left-1)0 next(puts 60::chunks)
                 else generate(left-1)(i+1)next chunks end
    in generate n 0 seed [] end
  fun output n =
    let val first = writeAlu(n*2)
        val (second,seed) = make(n*3)iub 42
        val (third,_) = make(n*5)homo seed
    in ">ONE Homo sapiens alu\n"^first^
       ">TWO IUB ambiguity codes\n"^second^
       ">THREE Homo sapiens frequency\n"^third end
end
