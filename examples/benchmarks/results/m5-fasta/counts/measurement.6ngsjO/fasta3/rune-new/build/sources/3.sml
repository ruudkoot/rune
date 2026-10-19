(* Sandmark FASTA variants and exact-output support; retain each workload
   source, dataset origins and Revised BSD notice in its benchmark directory. *)
(* Exact output oracle: reviewed complete RNG-cycle bytes, no RNG/CDF evaluation. *)
structure BenchFastaCycleCheck =
struct
  fun read path=
    let val input=TextIO.openIn path
        val data=(TextIO.inputAll input handle e=>(TextIO.closeIn input;raise e))
    in TextIO.closeIn input;data end
  fun run kernel n alu iub homo=
    let
      val _=if String.size alu=287 andalso String.size iub=139968 andalso String.size homo=139968
            then()else raise Fail "invalid FASTA oracle lengths"
      val headers=Vector.fromList[">ONE Homo sapiens alu\n",">TWO IUB ambiguity codes\n",">THREE Homo sapiens frequency\n"]
      val section=ref 0 val headerPosition=ref 0 val inHeader=ref true
      val remaining=ref 0 val column=ref 0 val needNewline=ref false
      val aluPosition=ref 0 val draw=ref 0 val consumed=ref 0
      fun beginBody()=(inHeader:=false;column:=0;needNewline:=false;
        remaining:=n*(if !section=0 then 2 else if !section=1 then 3 else 5))
      fun nextSection()=(section:= !section+1;inHeader:=true;headerPosition:=0)
      fun expected()=
        if !section>=3 then raise Fail "FASTA output has extra bytes"
        else if !inHeader then
          let val header=Vector.sub(headers,!section)
              val c=String.sub(header,!headerPosition)
              val _=headerPosition:= !headerPosition+1
              val _=if !headerPosition=String.size header then beginBody()else()
          in c end
        else if !needNewline then
          (needNewline:=false;column:=0;if !remaining=0 then nextSection()else();#"\n")
        else
          let val c=if !section=0 then String.sub(alu,!aluPosition mod String.size alu)
                    else String.sub(if !section=1 then iub else homo,!draw mod 139968)
              val _=if !section=0 then aluPosition:= !aluPosition+1 else draw:= !draw+1
              val _=remaining:= !remaining-1 val _=column:= !column+1
              val _=if !column=60 orelse !remaining=0 then needNewline:=true else()
          in c end
      fun character c=
        let val wanted=expected()
        in if c=wanted then consumed:= !consumed+1
           else raise Fail("FASTA byte differs at "^Int.toString(!consumed))end
      fun text(data,start,count)=BenchSandmarkFasta.for start(start+count-1)(fn i=>character(String.sub(data,i)))
      fun buffer(data,start,count)=BenchSandmarkFasta.for start(start+count-1)(fn i=>character(CharArray.sub(data,i)))
      val _=kernel n {text=text,buffer=buffer,character=character}
    in if !section=3 then !consumed else raise Fail "FASTA output incomplete"end
end
