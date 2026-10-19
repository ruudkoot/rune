functor BenchCichelliFn (Config : sig
  structure Eval : BENCH_SUSPEND
  val strictCandidates : bool
end) =
struct
  structure D = Config.Eval
  structure L = BenchLazy
  structure S = BenchStream
  datatype key = K of string * char * char * int
  datatype hashSet = H of int option * int option * int list
  type hashFun = (char * int) list
  datatype feedback = NotEver of int D.t | YesIts of int D.t * hashFun
  fun member x xs = List.exists (fn y => x=y) xs
  fun assoc key [] = NONE
    | assoc key ((name,value)::rest) = if key=name then SOME value else assoc key rest
  fun required key entries = case assoc key entries of SOME value => value | NONE => raise Fail "cichelli missing association"
  fun attribute words = List.map (fn word => K (word,String.sub (word,0),
    String.sub (word,String.size word-1),String.size word)) words
  fun ends (K (_,first,last,_)) = [first,last]
  fun histInsert x [] = [(x,1)]
    | histInsert x ((y,n)::rest) = if x=y then (y,n+1)::rest else (y,n)::histInsert x rest
  val attributed = attribute BenchCichelliData.keys
  val frequency = List.foldr (fn (x,xs) => histInsert x xs) [] (List.concat (List.map ends attributed))
  val maximum = List.length frequency
  val numberOfKeys = List.length BenchCichelliData.keys
  fun union xs ys = xs @ List.filter (fn y => not (member y xs)) ys
  fun partition predicate [] = ([],[])
    | partition predicate (x::xs) =
      let val (yes,no) = partition predicate xs
      in if predicate x then (x::yes,no) else (yes,x::no) end
  fun blocked keys =
    let fun loop _ [] = []
          | loop known (first::rest) =
              let val updated = union known (ends first)
                  val (determined,others) = partition (fn key => List.all (fn c => member c updated) (ends key)) rest
              in first :: (determined @ loop updated others) end
    in loop [] keys end
  fun insert value (H (lo,hi,used)) =
    if member value used then NONE else
    let val low = case lo of NONE => value | SOME old => Int.min (old,value)
        val high = case hi of NONE => value | SOME old => Int.max (old,value)
    in if 1+high-low > numberOfKeys then NONE else SOME (H (SOME low,SOME high,value::used)) end
  fun hash assignments (K (_,first,last,n)) = n + required first assignments + required last assignments
  fun first count answers = case L.force answers of S.Nil => NotEver count
    | S.Cons (answer,rest) => (case L.force answer of
        YesIts (leaves,assignments) => YesIts (D.delay (fn () => D.force count + D.force leaves),assignments)
      | NotEver leaves => first (D.delay (fn () => D.force count + D.force leaves)) rest)
  fun firstSuccess f arguments = first (D.delay (fn () => 0)) (S.map f arguments)
  fun choices count make =
    if Config.strictCandidates then
      S.fromList (List.tabulate (count,make))
    else let fun loop i = L.delay (fn () => if i=count then S.Nil
          else S.Cons (L.delay (fn () => make i),loop (i+1)))
         in loop 0 end
  fun find state assignments [] = YesIts (D.delay (fn () => 1),assignments)
    | find state assignments ((key as K (_,first,last,_))::rest) =
      let fun attempt additions =
            let val next = additions @ assignments
            in case insert (hash next key) state of NONE => NotEver (D.delay (fn () => 1))
             | SOME updated => find updated next rest end
          val width = maximum+1
      in case (assoc first assignments,assoc last assignments) of
           (NONE,NONE) => if first=last
             then firstSuccess attempt (choices width (fn n => [(first,n)]))
             else firstSuccess attempt (choices (width*width) (fn i => [(first,i div width),(last,i mod width)]))
         | (NONE,SOME _) => firstSuccess attempt (choices width (fn n => [(first,n)]))
         | (SOME _,NONE) => firstSuccess attempt (choices width (fn n => [(last,n)]))
         | (SOME _,SOME _) => attempt []
      end
  fun solve keys = find (H (NONE,NONE,[])) [] (blocked keys)
  fun cichelli n = solve (attribute (BenchCichelliData.keys @
    (if n mod 2=0 then [] else [hd BenchCichelliData.keys])))
  fun emitFeedback emit status =
    let fun pair (name,n) = "('" ^ String.str name ^ "'," ^ Int.toString n ^ ")"
        fun assignments [] = ()
          | assignments [x] = emit (pair x)
          | assignments (x::xs) = (emit (pair x ^ ","); assignments xs)
    in case status of NotEver leaves => (emit "NotEver "; emit (Int.toString (D.force leaves)))
     | YesIts (leaves,values) =>
         (emit "YesIts "; emit (Int.toString (D.force leaves)); emit " [";
          assignments values; emit "]")
    end
end
