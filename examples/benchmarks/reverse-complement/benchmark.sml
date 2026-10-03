(* Louis Wasserman's 82-byte reader, growing buffer and in-place swap loop. *)
structure Benchmark =
struct
  val name = "reverse-complement"
  datatype buffer = Buf of int * int * char Array.array
  val from = "AaCcGgTtUuMmRrYyKkVvHhDdBb"
  val to = "TTGGCCAAAAKKYYRRMMBBDDHHVV"
  fun newSize len size = if len<=size then size else newSize len (2*size)
  fun putBuf input start count (Buf(len,size,data)) =
    let val total = len+count
        val capacity = newSize total size
        val result = if capacity=size then data else
          let val larger = Array.array(capacity,#"\000")
              fun copy i = if i=len then () else
                (Array.update(larger,i,Array.sub(data,i));copy(i+1))
              val _ = copy 0
          in larger end
        fun copy i = if i=count then () else
          (Array.update(result,len+i,String.sub(input,start+i));copy(i+1))
        val _ = copy 0
    in Buf(total,capacity,result) end
  fun find data start count c =
    let fun scan i = if i=count then NONE else
          if data(start+i)=c then SOME i else scan(i+1)
    in scan 0 end
  fun clear (Buf(_,size,data)) = Buf(0,size,data)
  fun output input =
    let val complements = Array.tabulate(200,Char.chr)
        val _ = List.app (fn i => Array.update(complements,Char.ord(String.sub(from,i)),String.sub(to,i)))
          (List.tabulate(String.size from,fn i => i))
        fun comp c = Array.sub(complements,Char.ord c)
        fun revcomp (Buf(0,_,_)) = ""
          | revcomp (Buf(len,_,data)) =
              let val begin = case find (fn i => Array.sub(data,i)) 0 len #"\n" of
                      SOME n => n+1 | NONE => raise Fail "FASTA header lacks newline"
                  fun rc i j = if i<j then
                        let val xi = Array.sub(data,i)
                        in if xi= #"\n" then rc1 j (i+1) (Array.sub(data,i+1))
                           else rc1 j i xi end
                      else if i=j then Array.update(data,i,comp(Array.sub(data,i))) else ()
                  and rc1 j i xi =
                    let val xj = Array.sub(data,j)
                    in if xj= #"\n" then rc2 i xi (j-1) (Array.sub(data,j-1))
                       else rc2 i xi j xj end
                  and rc2 i xi j xj =
                    (Array.update(data,j,comp xi);Array.update(data,i,comp xj);rc(i+1)(j-1))
                  val _ = rc begin (len-1)
              in String.implode(List.tabulate(len,fn i => Array.sub(data,i))) end
        fun read start buf chunks =
          let val count = Int.min(82,String.size input-start)
          in if count=0 then String.concat(List.rev(revcomp buf::chunks)) else
            case find (fn i => String.sub(input,i)) start count #">" of
              NONE => read(start+count)(putBuf input start count buf)chunks
            | SOME index =>
                let val output = revcomp(putBuf input start index buf)
                    val next = putBuf input (start+index) (count-index) (clear buf)
                in read(start+count)next(output::chunks) end
          end
    in read 0 (Buf(0,1024,Array.array(1024,#"\000"))) [] end
  fun file path =
    let val stream = TextIO.openIn path
        val text = TextIO.inputAll stream
        val _ = TextIO.closeIn stream
    in text end
  fun run [input,reference] =
    let val actual = output(file input)
        val expected = file reference
        val _ = if actual=expected then () else raise Fail "reverse-complement complete output differs"
    in Int.toString(String.size actual) end
    | run _ = raise Fail "reverse-complement expects input reference"
end
