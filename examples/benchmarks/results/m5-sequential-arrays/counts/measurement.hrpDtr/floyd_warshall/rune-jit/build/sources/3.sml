(* Sequential Sandmark array kernels, preserving loop order and representations. *)
structure BenchOCamlArrayKernels =
struct
  fun for first last function =
    let fun loop i = if i>last then () else (function i;loop(i+1))
    in loop first end
  fun swap array i j =
    let val temporary=Array.sub(array,i)
    in Array.update(array,i,Array.sub(array,j));Array.update(array,j,temporary)end
  fun partition array low high =
    let val pivot=Array.sub(array,high)
        val i=ref(low-1)
        val _=if high-low>0 then for low (high-1)(fn j =>
          if Array.sub(array,j)<=pivot then(i:= !i+1;swap array (!i) j)else())else()
        val _=swap array (!i+1) high
    in !i+1 end
  fun quicksortOriginal array low high = if high-low<=0 then()else
    let val q=partition array low high
    in quicksortOriginal array low(q-1);quicksortOriginal array(q+1)high end
  fun quicksort array low high = if high-low<=0 then()else
    let val q=partition array low high
    in quicksortOriginal array low(q-1);quicksortOriginal array(q+1)high end
  fun bubble array start limit = for start(limit-2)(fn i => for(i+1)(limit-1)(fn j =>
    if Array.sub(array,j)<Array.sub(array,i)then swap array i j else()))
  fun blit source from target to count = for 0(count-1)(fn i =>
    Array.update(target,to+i,Array.sub(source,from+i)))
  fun merge source target start split limit =
    let fun loop destination i j =
          if i=split then blit source j target destination(limit-j)
          else if j=limit then blit source i target destination(split-i)
          else if Array.sub(source,i)<=Array.sub(source,j)then
            (Array.update(target,destination,Array.sub(source,i));loop(destination+1)(i+1)j)
          else(Array.update(target,destination,Array.sub(source,j));loop(destination+1)i(j+1))
    in loop start start split end
  fun mergeSort move a b start limit = if move orelse limit-start>32 then
    let val split=(start+limit)div 2
        val _=mergeSort(not move)a b start split
        val _=mergeSort(not move)a b split limit
    in if move then merge a b start split limit else merge b a start split limit end
    else bubble a start limit
  fun mergesort a = let val b=Array.tabulate(Array.length a,fn i => Array.sub(a,i))
    in mergeSort false a b 0(Array.length a)end
  type matrix = int array array
  fun multiply (result:matrix) (x:matrix) (y:matrix) =
    for 0(Array.length x-1)(fn i => for 0(Array.length(Array.sub(y,0))-1)(fn j =>
      let val w=ref 0
          val _=for 0(Array.length y-1)(fn k => w:= !w+
            Array.sub(Array.sub(x,i),k)*Array.sub(Array.sub(y,k),j))
      in Array.update(Array.sub(result,i),j,!w)end))
  datatype edge = Infinity | Value of int
  fun floyd (adjacency:edge array array) =
    let val n=Array.length adjacency
        fun get i j = Array.sub(Array.sub(adjacency,i),j)
        fun set i j v = Array.update(Array.sub(adjacency,i),j,v)
    in for 0(n-1)(fn k => for 0(n-1)(fn i => case get i k of Infinity => ()
      | Value aik => for 0(n-1)(fn j => case(get i j,get k j)of
          (Infinity,Value akj) => set i j(Value(aik+akj))
        | (Value aij,Value akj) => if aik+akj<aij then set i j(Value(aik+akj))else()
        | _ => ())))end
end
