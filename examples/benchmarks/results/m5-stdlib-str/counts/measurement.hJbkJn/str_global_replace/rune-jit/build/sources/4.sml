structure BenchStdlibTextPrograms=
struct
 structure B=BenchStdlibText
 structure A=B.Bytes
 datatype value=Letter of char|Number of int|Truth of bool|Text of string|Bytes of A.t|Parts of string list
 val seed=0wx811C9DC5:Word32.word
 fun mix state value=Word32.*(Word32.xorb(state,value),0w16777619)
 fun hashString text=
   let fun loop i h=if i=String.size text then h
         else loop(i+1)(mix h(Word32.fromInt(Char.ord(String.sub(text,i)))))
   in loop 0 seed end
 fun hashBytes array=
   let fun loop i h=if i=A.length array then h
         else loop(i+1)(mix h(Word32.fromInt(Char.ord(A.get array i))))
   in loop 0 seed end
 fun hashValue(Letter c)=Word32.fromInt(Char.ord c)
   |hashValue(Number n)=Word32.fromInt n
   |hashValue(Truth b)=if b then 0w1 else 0w0
   |hashValue(Text text)=hashString text
   |hashValue(Bytes array)=hashBytes array
   |hashValue(Parts words)=
     let fun textHash text h=
           let fun loop i h=if i=String.size text then mix h 0w0
                 else loop(i+1)(mix h(Word32.fromInt(Char.ord(String.sub(text,i)))))
           in loop 0 h end
     in List.foldl(fn(text,h)=>textHash text h)seed words end
 val fish="I AM A FISH"
 val trimInput="We need a trim\n\n\n\n\n"
 fun noFinish()=NONE
 fun byteOperation input name=
   let val length=A.length input
   in case name of
       "bytes_get"=>(fn i=>Letter(A.get input(i mod length)),noFinish)
     |"bytes_set"=>
       let val copy=A.copy input
       in(fn i=>(A.set copy(i mod length) #" ";Number 0),fn()=>SOME(Bytes copy))end
     |"bytes_cat"=>let val prefix=A.ofString fish
       in(fn _=>Bytes(A.cat prefix input),noFinish)end
     |"bytes_sub"=>(fn i=>Bytes(A.sub input(i mod(length-2))2),noFinish)
     |"bytes_blit"=>(fn i=>let val dest=A.make 32 #" "
          val _=A.blit(input,i mod(length-32),dest,0,32)
        in Bytes dest end,noFinish)
     |"bytes_concat"=>let val parts=List.map A.ofString["I","AM","A","FISH"] val separator=A.ofString" "
        in(fn _=>Bytes(A.concat separator parts),noFinish)end
     |"bytes_iter"=>(fn _=>let val seen=ref 0 val _=A.app(fn _=>seen:= !seen+1)input
        in Number(!seen)end,noFinish)
     |"bytes_map"=>(fn _=>Bytes(A.map(fn _=> #"!")input),noFinish)
     |"bytes_trim"=>let val original=A.ofString trimInput in(fn _=>Bytes(A.trim original),noFinish)end
     |"bytes_index"=>(fn _=>Number(A.index input #"r"),noFinish)
     |"bytes_contains"=>(fn _=>Truth(A.contains input #"r"),noFinish)
     |"bytes_uppercase_ascii"=>(fn _=>Bytes(A.map B.uppercase input),noFinish)
     |_=>raise Fail"unknown bytes selector"end
 fun stringOperation name=
   let val text=B.text val length=String.size text
   in case name of
       "string_get"=>(fn i=>Letter(String.sub(text,i mod length)),noFinish)
     |"string_sub"=>(fn i=>Text(String.substring(text,i mod(length-2),2)),noFinish)
     |"string_blit"=>(fn i=>let val dest=A.make 32 #" " val start=i mod(length-32)
          val _=B.for 0 31(fn j=>A.set dest j(String.sub(text,start+j)))
        in Bytes dest end,noFinish)
     |"string_concat"=>(fn _=>Text(B.concatStrings" "["I","AM","A","FISH"]),noFinish)
     |"string_iter"=>(fn _=>let val seen=ref 0 val _=B.appString(fn _=>seen:= !seen+1)text
        in Number(!seen)end,noFinish)
     |"string_map"=>(fn _=>Text(String.map(fn _=> #"!")text),noFinish)
     |"string_trim"=>(fn _=>Text(B.trimString trimInput),noFinish)
     |"string_index"=>(fn _=>Number(B.indexString text #"r"),noFinish)
     |"string_contains"=>(fn _=>Truth((B.indexString text #"r";true)handle Fail _=>false),noFinish)
     |"string_uppercase_ascii"=>(fn _=>Text(String.map B.uppercase text),noFinish)
     |"string_split_on_char"=>(fn _=>Parts(B.splitOnChar #" "text),noFinish)
     |"string_compare"=>
        let val words=B.splitOnChar #" "text
            fun sumAll x=List.foldl(fn(y,acc)=>acc+B.compareStrings(x,y))0 words
        in(fn _=>Number(List.foldl(fn(x,acc)=>acc+sumAll x)0 words),noFinish)end
     |"string_equal"=>
        let val words=B.splitOnChar #" "text
            fun sumAll x=List.foldl(fn(y,acc)=>if x=y then acc+1 else acc)0 words
        in(fn _=>Number(List.foldl(fn(x,acc)=>acc+sumAll x)0 words),noFinish)end
     |_=>raise Fail"unknown string selector"end
 fun equalText array length get=
   A.length array=length andalso
   let fun loop i=i=length orelse(A.get array i=get i andalso loop(i+1))
   in loop 0 end
 fun equalString text length get=
   String.size text=length andalso
   let fun loop i=i=length orelse(String.sub(text,i)=get i andalso loop(i+1))
   in loop 0 end
 fun expectedArray name i=
   let val length=String.size B.text
   in case name of
       "bytes_cat"=>(String.size fish+length,fn j=>if j<String.size fish then String.sub(fish,j)else String.sub(B.text,j-String.size fish))
     |"bytes_sub"=>(2,fn j=>String.sub(B.text,i mod(length-2)+j))
     |"bytes_blit"=>(32,fn j=>String.sub(B.text,i mod(length-32)+j))
     |"string_blit"=>(32,fn j=>String.sub(B.text,i mod(length-32)+j))
     |"bytes_concat"=>(String.size fish,fn j=>String.sub(fish,j))
     |"bytes_map"=>(length,fn _=> #"!")
     |"bytes_trim"=>(14,fn j=>String.sub("We need a trim",j))
     |"bytes_uppercase_ascii"=>(length,fn j=>B.uppercase(String.sub(B.text,j)))
     |_=>raise Fail"incorrect result: unexpected byte result"end
 fun expectedText name i=
   let val length=String.size B.text
   in case name of
       "string_sub"=>(2,fn j=>String.sub(B.text,i mod(length-2)+j))
     |"string_concat"=>(String.size fish,fn j=>String.sub(fish,j))
     |"string_map"=>(length,fn _=> #"!")
     |"string_trim"=>(14,fn j=>String.sub("We need a trim",j))
     |"string_uppercase_ascii"=>(length,fn j=>B.uppercase(String.sub(B.text,j)))
     |_=>raise Fail"incorrect result: unexpected string result"end
 fun check name i value=
   let val size=String.size B.text
       val valid=case value of
         Letter c=>(name="bytes_get"orelse name="string_get")andalso c=String.sub(B.text,i mod size)
       |Number n=>
          if name="bytes_set"then n=0
          else if name="bytes_iter"orelse name="string_iter"then n=size
          else if name="bytes_index"orelse name="string_index"then n=7
          else if name="string_compare"then n=0
          else if name="string_equal"then
            n=BenchStdlibTextInput.equalPairs
          else false
       |Truth b=>(name="bytes_contains"orelse name="string_contains")andalso b
       |Bytes array=>let val(n,get)=expectedArray name i in equalText array n get end
       |Text text=>let val(n,get)=expectedText name i in equalString text n get end
       |Parts words=>name="string_split_on_char"andalso words=BenchStdlibTextInput.words
   in if valid then()else raise Fail"incorrect result: stdlib text value"end
 fun finishCheck name count value=
   case(name,value)of("bytes_set",Bytes array)=>
      let val n=String.size B.text
      in if equalText array n(fn j=>if count>=n orelse(j>=1 andalso j<=count)then #" "else String.sub(B.text,j))
         then()else raise Fail"incorrect result: bytes_set final array"end
   |_=>raise Fail"incorrect result: unexpected final text result"
 fun execute name count(step,finish)=
   let fun loop i hash=if i>count then hash else
         let val value=step i val _=check name i value
         in loop(i+1)(mix hash(hashValue value))end
       val hash=loop 1 seed
       val result=case finish()of NONE=>hash|SOME value=>(finishCheck name count value;mix hash(hashValue value))
   in Int.toString count^":"^Word32.toString result end
 fun runString name count=execute name count(stringOperation name)
 fun runBytes input name count=execute name count(byteOperation input name)
end
