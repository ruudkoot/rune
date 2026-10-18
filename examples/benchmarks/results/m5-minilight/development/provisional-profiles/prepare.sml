structure MiniLightPrepare=
struct
 fun read path=
   let val stream=TextIO.openIn path val text=TextIO.inputAll stream val _=TextIO.closeIn stream in text end
 val text=read"tests/out/benchmarks/minilight-originals/source/roomfront.ml.txt"
 val cursor=ref 0
 fun token()=
   let fun skip()=if !cursor<String.size text andalso Char.isSpace(String.sub(text,!cursor))
                  then(cursor:= !cursor+1;skip())else()
       val _=skip()val start= !cursor
       fun finish()=if !cursor<String.size text andalso not(Char.isSpace(String.sub(text,!cursor)))
                  then(cursor:= !cursor+1;finish())else()
       val _=finish()
   in String.substring(text,start,!cursor-start)end
 val _=if token()="#MiniLight"andalso token()="100"andalso token()="324"andalso token()="200"then()
       else raise Fail"unexpected original MiniLight model header"
 val suffix=String.extract(text,!cursor,NONE)
 fun write(profile,frames,width,height)=
   let val stream=TextIO.openOut("tests/out/benchmarks/minilight-originals/"^profile^".model")
       val _=TextIO.output(stream,"#MiniLight\n\n"^Int.toString frames^"\n\n"^Int.toString width^" "^Int.toString height^"\n"^suffix)
   in TextIO.closeOut stream end
 val _=List.app write[("smoke",1,8,6),("normal",4,32,24),("large",16,128,96)]
end
