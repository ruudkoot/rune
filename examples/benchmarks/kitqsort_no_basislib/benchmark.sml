(* The algorithm is retained; the old primitive-based mini-Basis is replaced
   by SML97's equivalent map/real/floor/list/equality operations. *)
structure SortKernel =
struct
  fun print (_ : string) = ()

fun map f nil = nil
  | map f (x :: L) = f x :: map f L
fun rev l =
  let fun rev_rec(p as ([], acc)) = p
        | rev_rec(x::xs, acc) = rev_rec(xs, x::acc)
  in #2 (rev_rec(l,nil))
  end
fun length [] = 0
  | length (x::xs) = 1 + length xs
fun app f [] = ()
  | app f (x::xs) = (f x; app f xs)


(* Quicksort -- Paulson p. 98 and answer to exercise 3.29 *)
(* Optimised for the Kit with Regions *)

(* NOTE:
 * This is the most space efficient version of quicksort with the current
 * storage mode analysis (implemented in 25q); copyList() will be called "sat"
 * inside partition() and the `innermost' recursive call to quickSort'() will
 * be "atbot" for the regions holding right'. Unfortunately, calling
 * copyList() after (the `innermost' recursive call to) quickSort'() means
 * that we  keep the regions holding the `original list' live during the
 * call to quickSort'(). This should not be necessary, since a::bs will be
 * copied (i.e. partitioned) into to left and right parts, but rules 28 and 26
 * in the region analysis are a bit too conservative in this case...
 *)

  fun say(s) = print s

  type elem = int

  fun copyList [] = []
    | copyList (x::xr) = x::(copyList xr)

  fun quickSort' (arg as ([], sorted)) = arg
    | quickSort' ([a], sorted) = ([], a::sorted)
    | quickSort' (a::bs, sorted) =  (* "a" is the pivot *)
        let
          fun partition (arg as (_, _, []: elem list)) = arg
	    | partition (left, right, x::xr) =
	        if x<=a then partition(x::left, right, xr)
	                else partition(left, x::right, xr)
	  val arg' =
	    let val (left', right) =
                 let val (left, right, _) = partition([], [], bs)
                 in  (*forceResetting bs;*)
                     (copyList left, right)
                 end
                val sorted' = #2 (quickSort'(right, sorted))
	    in
	      (left', a::sorted')
	    end
	in
	  quickSort' arg'
	end
  fun quickSort l = #2 (quickSort'(l, []))


(* Generating random numbers.  Paulson, page 96 *)

  val min   = 1
  val max   = 100000
  val a     = 16807.0
  val m     = 2147483647.0
  val w     = real(max - min)/m
  fun seed0() = 117.0

  fun nextRand seed =
    let val t = a*seed
    in
      t - m*real(floor(t/m))
    end

  fun randomList' (arg as (0, _, res)) = arg
    | randomList' (i, seed, res) =
      let val res' = min+floor(seed*w) :: res
          (* NOTE: It is significant to use seed for
	   * calculating res' before calling nextRand()...
           *)
      in
	randomList'(i-1, nextRand seed, res')
      end
  fun randomList n = #3 (randomList'(n, seed0(), []))


(* Building input list, sorting it and testing the result *)

  fun isSorted [] = true
    | isSorted [x: elem] = true
    | isSorted (x::(xr as (y::yr))) = (x <= y) andalso (isSorted xr)

end
structure Benchmark =
struct
  val name = "kitqsort_no_basislib"
  fun run [size] =
    let val n = BenchInput.between (1,1000000) (BenchInput.integer size)
        val _ = if Real.radix = 2 andalso Real.precision = 53 then ()
                else raise Fail "generator requires binary64 Real"
        val sorted = SortKernel.quickSort (SortKernel.randomList n)
        val _ = if SortKernel.isSorted sorted then () else raise Fail "unordered quicksort result"
        fun scan ([],count,sum,hash) =
              if count = n then Int.toString count ^ " " ^ IntInf.toString sum ^ " " ^ Word32.toString hash
              else raise Fail "quicksort lost elements"
          | scan (x::xs,count,sum,hash) =
              scan (xs,count+1,IntInf.+ (sum,IntInf.fromInt x),
                    Word32.+ (Word32.* (hash,0w16777619),Word32.fromInt x))
    in scan (sorted,0,0,0w0) end
    | run _ = raise Fail "kitqsort_no_basislib expects list size"
end
