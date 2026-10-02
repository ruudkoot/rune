structure Int63 =
struct
  type int = IntInf.int
  val minimum : int = ~4611686018427387904
  val maximum : int = 4611686018427387903
  fun checked x = if x < minimum orelse x > maximum then raise Overflow else x
  fun op + (a,b) = checked (IntInf.+(a,b))
  fun op - (a,b) = checked (IntInf.-(a,b))
  fun op * (a,b) = checked (IntInf.*(a,b))
  fun op ~ a = checked (IntInf.~ a)
  fun op div (a,b) = checked (IntInf.div(a,b))
  val op mod = IntInf.mod
  val op < = IntInf.< val op > = IntInf.> val op <= = IntInf.<= val op >= = IntInf.>=
  fun abs x = checked (IntInf.abs x)
  val toString = IntInf.toString
end
(* mandelbrot-rat.sml
 *
 * COPYRIGHT (c) 2024 The Fellowship of SML/NJ (https://www.smlnj.org)
 * All rights reserved.
 *
 * Mandelbrot sets using rational numbers instead of floating-point.
 *)

structure Kernel =
  struct
  structure Int = Int63
  type int = Int63.int
  val op + = Int63.+ val op - = Int63.- val op * = Int63.* val op ~ = Int63.~
  val op div = Int63.div val op mod = Int63.mod
  val op < = Int63.< val op > = Int63.> val op <= = Int63.<= val op >= = Int63.>=

    val name = "mandelbrot-rat"

    val results : string list = []

    (* rational number *)
    type fixed = int * int

    fun gcd (m, n) = if n = 0 then m else gcd (n, m mod n)

    fun fromInt (n : int) : fixed = (n, 1)

    fun shr (n, i) = IntInf.~>> (n, i)

    fun truncate (n, d) = if Int.abs d > 0x7FFFFFFF orelse Int.abs n > 0x7FFFFFFF
          then truncate (shr (n, 0w4), shr (d, 0w4))
          else (n, d)

    fun normalize (n, d) = if n = 0
          then (0, 1)
          else let
            val g = gcd (n, d)
            in
              if g = 1
                then truncate (n, d)
                else truncate (n div g, d div g)
            end

    fun add ((n1, d1), (n2, d2)) = if d1 = d2
          then truncate (n1 + n2, d1)
          else let
            val n1' = d2 * n1
            val n2' = d1 * n2
            in
              normalize (n1' + n2', d1 * d2)
            end

    fun sub ((n1, d1), (n2, d2)) = if d1 = d2
          then truncate (n1 - n2, d1)
          else let
            val n1' = d2 * n1
            val n2' = d1 * n2
            in
              normalize (n1' - n2', d1 * d2)
            end

    fun mul ((n1, d1), (n2, d2)) = normalize (n1 * n2, d1 * d2)

    fun divide ((n, d), m) = normalize (n, d * m)

    fun isPositive (n, d) = (n > 0 andalso d > 0) orelse (n < 0 andalso d < 0)

    infix 6 ++ --
    infix 7 ** //
    infix 9 over
    val op ++ = (add : fixed * fixed -> fixed)
    val op -- = (sub : fixed * fixed -> fixed)
    val op ** = (mul : fixed * fixed -> fixed)
    val op // = (divide : fixed * int -> fixed)
    val op over = ((fn x => x) : int * int -> fixed)

    val x_base = ~2 over 1
    val y_base = 9 over 8
    val side = 5 over 4

    val sz : int ref = ref 256
    val maxCount : int = 512

    fun delta () = side // (!sz)

    val sum_iterations : int ref = ref 0

    fun loop1 i = if (i >= !sz)
          then ()
          else let
            val c_im : fixed = y_base -- (delta() ** fromInt i)
            fun loop2 j = if (j >= !sz)
                  then ()
                  else let
                  (* NOTE: older versions of the benchmark had the following
                   * incorrect code:
                    val c_re = x_base * (delta + real_j)
                   *)
                    val c_re = x_base ++ (delta() ** fromInt j)
                    fun loop3 (count, z_re : fixed, z_im : fixed) = if (count < maxCount)
                          then let
                            val z_re_sq = z_re ** z_re
                            val z_im_sq = z_im ** z_im
                            in
                              if isPositive ((z_re_sq ++ z_im_sq) -- fromInt 4)
                                then count
                                else let
                                  val z_re_im = (z_re ** z_im)
                                  in
                                    loop3 (count+1,
                                      (z_re_sq -- z_im_sq) ++ c_re,
                                       z_re_im ++ z_re_im ++ c_im)
                                  end
                            end (* loop3 *)
                          else count
                    val count = loop3 (0, c_re, c_im)
                    in
                      sum_iterations := !sum_iterations + count;
                      loop2 (j+1)
                    end
            in
              loop2 0;
              loop1 (i+1)
            end


end
structure Benchmark=struct val name="mandelbrot-rat"
fun run [size,reps]=let val n=BenchInput.between(1,256)(BenchInput.integer size) val r=BenchInput.between(1,10)(BenchInput.integer reps)
fun one()=(Kernel.sz:=IntInf.fromInt n; Kernel.sum_iterations:=(0:IntInf.int); Kernel.loop1 (0:IntInf.int); IntInf.toString(!Kernel.sum_iterations))
fun loop(0,acc)=String.concatWith ";"(List.rev acc)|loop(k,acc)=loop(k-1,one()::acc)
in loop(r,[])end |run _=raise Fail "Mandelbrot expects dimension repetitions"end
