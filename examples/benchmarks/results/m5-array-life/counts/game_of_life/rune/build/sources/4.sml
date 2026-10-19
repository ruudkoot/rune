structure Benchmark =
struct
 val name="game_of_life"
 fun check board path hash=
   let val n=Array.length board
       val input=TextIO.openIn path
       fun row i total hash=if i=n then
             (case TextIO.inputLine input of NONE=>(total,hash) | _=>raise Fail "extra Life fixture rows")
         else case TextIO.inputLine input of NONE=>raise Fail "missing Life fixture rows"
           | SOME line=>if String.size line<>n+1 orelse String.sub(line,n)<> #"\n" then raise Fail "Life fixture width differs"
             else let fun column j total(hash:Word32.word)=if j=n then row(i+1)total hash else
                        let val value=Array.sub(Array.sub(board,i),j)
                            val expected=case String.sub(line,j)of #"."=>0 | #"o"=>1 | _=>raise Fail "invalid Life fixture cell"
                        in if value=expected then column(j+1)(total+value)
                             (Word32.+(Word32.*(hash,0w131),Word32.fromInt value))
                           else raise Fail "Life board differs"end
                  in column 0 total hash end
       val result=row 0 0 hash handle error=>(TextIO.closeIn input;raise error)
       val _=TextIO.closeIn input
   in result end
 fun run [count,size,path,previous]=
   let val generations=BenchInput.between(0,256)(BenchInput.integer count)
       val n=BenchInput.between(1,1024)(BenchInput.integer size)
       val(current,spare)=BenchArrayLife.runBuffers generations(BenchArrayLife.initial n)
       val(live,hash)=check current path 0w0
       val(oldLive,hash)=check spare previous hash
   in Int.toString generations^":"^Int.toString n^":"^Int.toString live^":"^Int.toString oldLive^":"^Word32.toString hash end
   | run _=raise Fail "Life expects generations side final-board spare-board"
end
