(* Source-order topology with GNU tsort's stable tie rules: lexical initial
   queue, then FIFO newly ready nodes and reverse insertion of successors. *)
structure GenerateTopo =
struct
  open MeasureCommon
  fun order edges =
    let val names=Vector.fromList (sort (GenerateText.distinct (List.concat (List.map (fn (a,b) => [a,b]) edges))))
        val n=Vector.length names
        fun index name=let fun loop lo hi=if lo>=hi then raise Failed "missing topology node" else
                   let val mid=(lo+hi) div 2 val key=Vector.sub (names,mid) in if name=key then mid else if name<key then loop lo mid else loop (mid+1) hi end
                 in loop 0 n end
        val successors=Array.array (n,[]) : int list array val incoming=Array.array (n,0)
        fun edge (a,b)=if a=b then () else
             let val a=index a val b=index b val old=Array.sub (successors,a)
             in if List.exists (fn i => i=b) old then () else (Array.update (successors,a,b::old);Array.update (incoming,b,Array.sub (incoming,b)+1)) end
        val ()=List.app edge edges
        val front=ref (List.filter (fn i => Array.sub (incoming,i)=0) (List.tabulate (n,fn i => i))) val back=ref [] : int list ref
        fun push i=back:=i:: !back
        fun take ()=case !front of i::rest => (front:=rest;SOME i) | [] => if null (!back) then NONE else (front:=List.rev (!back);back:=[];take ())
        fun loop acc=case take () of NONE => (need (length acc=n,"cyclic generated signature dependencies");List.rev acc)
          | SOME i => (List.app (fn j => let val count=Array.sub (incoming,j)-1 in Array.update (incoming,j,count);if count=0 then push j else () end) (Array.sub (successors,i));loop (Vector.sub (names,i)::acc))
    in loop [] end
end
