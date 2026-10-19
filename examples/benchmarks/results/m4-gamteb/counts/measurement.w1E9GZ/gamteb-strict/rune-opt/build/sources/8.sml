(*

      Patricia Fasel
      Los Alamos National Laboratory
      1990 August

 Copyright, 1990, The Regents of the University of California.
 This software was produced under a U.S. Government contract (W-7405-ENG-36)
 by the Los Alamos National Laboratory, which is operated by the University
 of California for the U.S. Department of Energy.  The U.S. Government is
 licensed to use, reproduce, and distribute this software.  Permission is
 granted to the public to copy and use this software without charge, provided
 that this notice and any statement of authorship are reproduced on all
 copies.  Neither the Government nor the University makes any warranty,
 express or implied, or assumes any liability for the use of this software.

*)
functor BenchGamtebDriverFn(K:sig
  type outcome
  type result
  type stat
  val run:int->outcome
  val first:outcome->result BenchStream.stream
  val second:outcome->stat BenchStream.stream
  val resultValue:result->int*int*real
  val statValue:stat->int*real
  val tableHeads:unit->real list
end) =
struct
  structure L=BenchLazy
  structure S=BenchStream
  structure W=Word64
  type reference={particles:int,tables:real list,results:(int*int*real)list,
    stats:real list,cells:real list}
  fun read path=let val f=TextIO.openIn path val text=TextIO.inputAll f
    val _=TextIO.closeIn f in text end
  fun real text=case Real.fromString text of SOME value=>
      if Real.isFinite value then value else raise Fail "nonfinite GAMTEB reference"
    |NONE=>raise Fail "invalid GAMTEB reference number"
  fun reference text:reference=
    let val rows=List.map(String.tokens Char.isSpace)(String.tokens(fn c=>c= #"\n")text)
        fun result[k,i,w]=(BenchInput.between(1,3)(BenchInput.integer k),
          BenchInput.between(1,35)(BenchInput.integer i),real w)
          |result _=raise Fail "invalid GAMTEB result reference"
    in case rows of ["particles",n]::("tables"::tableValues)::["results",count]::rest=>
         let val size=BenchInput.between(0,100000)(BenchInput.integer count)
             val _=if List.length rest>=size then()else raise Fail "short GAMTEB reference"
             val results=List.map result(List.take(rest,size))
         in case List.drop(rest,size)of
            [("stats"::stats),("cells"::cells)]=>
              if List.length tableValues=4 andalso List.length stats=12 andalso List.length cells=105
              then{particles=BenchInput.integer n,tables=List.map real tableValues,results=results,
                stats=List.map real stats,cells=List.map real cells}
              else raise Fail "incorrect GAMTEB reference dimensions"
           |_=>raise Fail "incorrect GAMTEB reference suffix"end
       |_=>raise Fail "incorrect GAMTEB reference header"
    end
  fun close(a,b)=BenchInput.closeReal(a,b,1.0E~11,1.0E~10)
  fun accumulatedClose(a,b)=if Real.==(b,0.0)then Real.==(a,0.0)else close(a,b)
  fun number value=
    let val _=if Real.isFinite value then()else raise Fail "incorrect result: nonfinite GAMTEB value"
        val text=String.translate(fn #"~"=>"-"|c=>String.str c)(Real.fmt(StringCvt.GEN(SOME 17))value)
        val _=case Real.fromString text of SOME parsed=>
            if Real.==(parsed,value)andalso
              (not(Real.==(value,0.0))orelse Real.signBit parsed=Real.signBit value)then()
            else raise Fail "incorrect result: GAMTEB numeric rendering"
          |NONE=>raise Fail "incorrect result: GAMTEB numeric rendering"
    in text end
  fun hash text=
    let fun loop i value=if i=String.size text then value else
          loop(i+1)(W.+(W.fromInt(Char.ord(String.sub(text,i))),W.*(value,0w31)))
    in loop 0 0w0 end
  fun reverseHash text=
    let fun loop i power sum=if i<0 then sum else
          loop(i-1)(W.*(power,0w31))(W.+(sum,W.*(power,W.fromInt(Char.ord(String.sub(text,i))))))
    in loop(String.size text-1)0w1 0w0 end
  val headings=["Number of escapes: ","Number of transits: ","Number of scatters: ",
    "Number of energy kills: ","Number of weight kills: ","Number of roulettes: ",
    "Number of splits: ","Number of collisions: ","Number of noncollisions: ",
    "Number of roulettes kills: ","Weight of roulette kills: ","Weight of roulette gains: "]
  val tableValues=L.delay K.tableHeads
  val tableText=L.delay(fn()=>case L.force tableValues of [energy,compton,pair,photo]=>
      "\nEnergy table:\n"^number energy^"\nCompton table:\n"^number compton^
      "\nPair table:\n"^number pair^"\nPhoto table:\n"^number photo^"\n"
    |_=>raise Fail "incorrect GAMTEB table prefix dimensions")
  fun checked particles(wanted:reference)=
    let val _=if #particles wanted=particles andalso ListPair.allEq close(L.force tableValues,#tables wanted)then()
          else raise Fail "incorrect result: GAMTEB particle count or constant tables"
        val task=K.run particles
        fun raw values expected pieces count=case(L.force values,expected)of
            (S.Nil,[])=>(pieces,count)
          |(S.Cons(head,tail),(kind,index,weight)::rest)=>
            let val(k,i,w)=K.resultValue(L.force head)
                val _=if k=kind andalso i=index andalso close(w,weight)then()
                  else raise Fail "incorrect result: GAMTEB particle result"
                val text="Result: index "^Int.toString k^"  type "^Int.toString i^"  weight "^number w^"\n"
            in raw tail rest(text::pieces)(count+1)end
          |_=>raise Fail "incorrect result: GAMTEB result count"
        val(parts,count)=raw(K.first task)(#results wanted)
          ["Number of particles "^Int.toString particles^"\n"^L.force tableText]0
        val stats=Array.array(12,0.0)
        val _=S.foldl(fn(entry,())=>
          let val(i,value)=K.statValue entry
              val _=if i>=1 andalso i<=12 then()else raise Fail "incorrect result: GAMTEB statistic index"
          in Array.update(stats,i-1,Array.sub(stats,i-1)+value)end)()(K.second task)
        val statValues=List.tabulate(12,fn i=>Array.sub(stats,i))
        val _=if ListPair.allEq(fn((i,a),b)=>if i<10 then Real.==(a,b)else accumulatedClose(a,b))
          (ListPair.zip(List.tabulate(12,fn i=>i),statValues),#stats wanted)then()
          else raise Fail "incorrect result: GAMTEB accumulated statistics"
        val statText=String.concat(ListPair.mapEq(fn(title,value)=>title^number value^"\n")(headings,statValues))
        val cells=Array.array(105,0.0)
        val _=S.foldl(fn(entry,())=>
          let val(kind,index,value)=K.resultValue entry
              val _=if kind>=1 andalso kind<=3 andalso index>=1 andalso index<=35 then()
                else raise Fail "incorrect result: GAMTEB result-array index"
              val i=(kind-1)*35+index-1
          in Array.update(cells,i,Array.sub(cells,i)+value)end)()(K.first task)
        val cellValues=List.tabulate(105,fn i=>Array.sub(cells,i))
        val _=if ListPair.allEq accumulatedClose(cellValues,#cells wanted)then()
          else raise Fail "incorrect result: GAMTEB accumulated result weights"
        val items=List.tabulate(105,fn i=>
          "(("^Int.toString(i div 35+1)^","^Int.toString(i mod 35+1)^"),"^number(Array.sub(cells,i))^")")
        val arrayText="\nScatter, Escape, Transit tables:\narray ((1,1),(3,35)) ["^String.concatWith "," items^"]"
        val text=String.concat(List.rev((statText^arrayText)::parts))
        val _=if hash text=reverseHash text then()else raise Fail "incorrect result: GAMTEB output hash"
    in count end
  fun run[repeatText,sizeText,path]=
    let val repeats=BenchInput.between(0,1000)(BenchInput.integer repeatText)
        val particles=BenchInput.between(1,5000)(BenchInput.integer sizeText)
        val wanted=reference(read path)
        fun loop 0 checkedResults=Int.toString repeats^":"^Int.toString checkedResults
          |loop n total=loop(n-1)(total+checked particles wanted)
    in loop repeats 0 end
    |run _=raise Fail "GAMTEB expects repetitions, particle count and a numerical reference"
end
