(* Sandmark FASTA variants and exact-output support; retain each workload
   source, dataset origins and Revised BSD notice in its benchmark directory. *)
(* Two sequential Sandmark FASTA implementations. Keep distinct float lookup
   operations, output chunking and line-buffer versus whole-buffer allocation. *)
structure BenchSandmarkFasta =
struct
  type output={text:string*int*int->unit,buffer:CharArray.array*int*int->unit,character:char->unit}
  val modulus=139968
  val width=60
  val modulusReal=Real.fromInt modulus
  val inverse=1.0/modulusReal
  val last=ref 42
  val alu="GGCCGGGCGCGGTGGCTCACGCCTGTAATCCCAGCACTTTGGGAGGCCGAGGCGGGCGGATCACCTGAGG"^
    "TCAGGAGTTCGAGACCAGCCTGGCCAACATGGTGAAACCCCGTCTCTACTAAAAATACAAAAATTAGCCGGG"^
    "CGTGGTGGCGCGCGCCTGTAATCCCAGCTACTCGGGAGGCTGAGGCAGGAGAATCGCTTGAACCCGGGAGGC"^
    "GGAGGTTGCAGTGAGCCGAGATCGCGCCACTGCACTCCAGCCTGGGCGACAGAGCGAGACTCCGTCTCAAAAA"
  val iub=Array.fromList[(#"a",0.27),(#"c",0.12),(#"g",0.12),(#"t",0.27),(#"B",0.02),
    (#"D",0.02),(#"H",0.02),(#"K",0.02),(#"M",0.02),(#"N",0.02),(#"R",0.02),
    (#"S",0.02),(#"V",0.02),(#"W",0.02),(#"Y",0.02)]
  val homo=Array.fromList[(#"a",0.3029549426680),(#"c",0.1979883004921),
    (#"g",0.1975473066391),(#"t",0.3015094502008)]
  fun for lo hi f=let fun loop i=if i>hi then ()else(f i;loop(i+1))in loop lo end
  fun step seed=(seed*3877+29573)mod modulus
  fun text(out:output)s=(#text out)(s,0,String.size s)
  fun newline(out:output)=(#character out) #"\n"
  fun writeCircular emit length start count=
    let val remaining=length-start
    in if count<=remaining then(emit(start,count);start+count)
       else(emit(start,remaining);writeCircular emit length 0(count-remaining))end
  fun repeat out emit length count=
    let val position=ref 0
        fun line amount=(position:=writeCircular emit length(!position)amount;newline out)
        val _=for 1(count div width)(fn _=>line width)
        val tail=count mod width
    in if tail>0 then line tail else()end
  fun make3(table:(char*real)Array.array)=
    let val cumulative=ref 0.0
        val chars=Array.tabulate(Array.length table,fn i=> #1(Array.sub(table,i)))
        val probs=Array.tabulate(Array.length table,fn i=>
          let val probability= #2(Array.sub(table,i))
          in cumulative:= !cumulative+probability;!cumulative end)
    in(probs,chars)end
  fun random3 maximum=
    let val n=step(!last)val _=last:=n
    in maximum*Real.fromInt n/modulusReal end
  fun char3(probs,chars)=
    let val p=random3 1.0 val i=ref 0
        fun search()=if p>=Array.sub(probs,!i)then(i:= !i+1;search())else()
        val _=search()
    in Array.sub(chars,!i)end
  fun randomBlock3(out:output)id description distribution count=
    let val _=text out(">"^id^" "^description^"\n")
        val table=make3 distribution
        val line=CharArray.array(width+1,#"\n")
        val _=for 1(count div width)(fn _=>
          (for 0(width-1)(fn j=>CharArray.update(line,j,char3 table));(#buffer out)(line,0,width+1)))
        val tail=count mod width
    in if tail>0 then(for 1 tail(fn _=>(#character out)(char3 table));newline out)else()end
  fun run3 n(out:output)=
    let val _=last:=42
        val _=text out ">ONE Homo sapiens alu\n"
        val _=repeat out(fn(start,count)=>(#text out)(alu,start,count))(String.size alu)(n*2)
        val _=randomBlock3 out "TWO" "IUB ambiguity codes" iub(n*3)
    in randomBlock3 out "THREE" "Homo sapiens frequency" homo(n*5)end
  fun make6 table=
    let val count=Array.length table val probs=Array.array(count,0.0)
        val chars=Array.array(count,#"\000") val cumulative=ref 0.0
        val _=for 0(count-1)(fn i=>let val(c,p)=Array.sub(table,i)
          in Array.update(chars,i,c);cumulative:= !cumulative+p;Array.update(probs,i,!cumulative)end)
    in(probs,chars)end
  fun char6 seed probs line j chars=
    let val n=step seed val p=Real.fromInt n*inverse
        val count=Array.length probs val middle=count div 2
        val i=ref(if p>=Array.sub(probs,middle)then middle+1 else 0)
        fun search()=if p>=Array.sub(probs,!i)then(i:= !i+1;search())else()
        val _=search()val _=CharArray.update(line,j,Array.sub(chars,!i))
    in n end
  fun randomBlock6(out:output)seed id description distribution count=
    let val _=(#character out) #">"val _=text out id val _=(#character out) #" "
        val _=text out description val _=newline out
        val(probs,chars)=make6 distribution
        val lines=(count+width-1)div width val size=count+lines
        (* SML97 arrays require a defined initial value; every position is overwritten. *)
        val line=CharArray.array(size,#"\000")val seed=ref seed val position=ref 0
        val _=for 1(lines-1)(fn _=>
          let val start= !position val finish=start+width-1
              val _=for start finish(fn j=>seed:=char6(!seed)probs line j chars)
          in position:=finish+2;CharArray.update(line,finish+1,#"\n")end)
        val _=for(!position)(size-2)(fn j=>seed:=char6(!seed)probs line j chars)
        val _=CharArray.update(line,size-1,#"\n")val _=(#buffer out)(line,0,size)
    in !seed end
  fun run6 n(out:output)=
    let val _=(#character out) #">"val _=text out "ONE"val _=(#character out) #" "
        val _=text out "Homo sapiens alu"val _=newline out
        val source=CharArray.tabulate(String.size alu,fn i=>String.sub(alu,i))
        val _=repeat out(fn(start,count)=>(#buffer out)(source,start,count))(CharArray.length source)(n*2)
        val seed=randomBlock6 out 42 "TWO" "IUB ambiguity codes" iub(n*3)
        val _=randomBlock6 out seed "THREE" "Homo sapiens frequency" homo(n*5)
    in()end
end
