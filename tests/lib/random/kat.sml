(* The known answers of lib/random, printed as tests/lib/random/reference.c
   prints them (tests/lib/run-lib-tests.sh compares the two). *)
fun hex (w : Word64.word) = StringCvt.padLeft #"0" 16 (Word64.fmt StringCvt.HEX w)

fun words (what, g, k) =
  if k = 0 then ()
  else let val (x, g) = Random.word64 g in print (what ^ " " ^ hex x ^ "\n"); words (what, g, k - 1) end

val () = words ("seed-0", Random.fromSeed 0w0, 10)
val () = words ("seed-0123456789ABCDEF", Random.fromSeed 0wx0123456789ABCDEF, 10)
val (a, b) = Random.split (Random.fromSeed 0w42)
val () = words ("split-left", a, 5)
val () = words ("split-right", b, 5)
val () =
  case String.fields (fn c => c = #":") (Random.toString b) of
    [_, gamma] => print ("split-right-gamma " ^ gamma ^ "\n")
  | _ => print "split-right-gamma ?\n"
val () =
  List.app (fn n =>
              let
                fun go (0, _) = ()
                  | go (i, g) = let val (x, g) = Random.below n g in print ("below-" ^ hex n ^ " " ^ hex x ^ "\n"); go (i - 1, g) end
              in
                go (5, Random.fromSeed 0w7)
              end)
           [0w1, 0w6, 0w1000, 0wx8000000000000001, 0wxFFFFFFFFFFFFFFFF]
