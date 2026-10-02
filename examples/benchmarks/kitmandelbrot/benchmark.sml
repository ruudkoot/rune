structure Kernel=struct
(*kitmandelbrot.sml*)

fun digit n = chr(ord #"0" + n)
fun digits(n,acc) =
      if n >=0 andalso n<=9 then digit n:: acc
      else digits (n div 10, digit(n mod 10) :: acc)

fun int_to_string(n) = implode(digits(n,[]))

(* mandelbrot.sml *)

(*
structure Kernel =
  struct
*)
    val x_base = ~2.0
    val y_base = 1.25
    val side = 2.5

    val sz = ref 2048
    val maxCount = 1024

    fun delta () = side / (real (!sz))

    val sum_iterations = ref 0
    val sum_steps = ref 0

    fun loop1 i = if (i >= !sz)
          then ()
          else let
            val c_im : real = y_base - (delta() * real i)
            fun loop2 j = if (j >= !sz)
                  then ()
                  else let
                    val c_re = x_base * (delta() + real j)
                    fun loop3 (count, z_re : real, z_im : real) = if (count < maxCount)
                          then let
                            val z_re_sq = z_re * z_re
                            val z_im_sq = z_im * z_im
                            in
                              if ((z_re_sq + z_im_sq) > 4.0)
                                then count
                                else let
                                  val z_re_im = (z_re * z_im)
                                  in
                                    loop3 (count+1,
                                      (z_re_sq - z_im_sq) + c_re,
                                       z_re_im + z_re_im + c_im)
                                  end
                            end (* loop3 *)
                          else count
                    val count = loop3 (0, c_re, c_im)
                    in
                      sum_iterations := !sum_iterations + 1(*count*);
              sum_steps := !sum_steps + count;
                      loop2 (j+1)
                    end
            in
              loop2 0;
              loop1 (i+1)
            end


end
structure Benchmark=struct val name="kitmandelbrot"
fun run [size,reps]=let val n=BenchInput.between(1,2048)(BenchInput.integer size) val r=BenchInput.between(1,10)(BenchInput.integer reps)
fun one()=(Kernel.sz:=n; Kernel.sum_iterations:=0; Kernel.sum_steps:=0;Kernel.loop1 0; Int.toString(!Kernel.sum_iterations)^" "^Int.toString(!Kernel.sum_steps))
fun loop(0,acc)=String.concatWith ";"(List.rev acc)|loop(k,acc)=loop(k-1,one()::acc)
in loop(r,[])end |run _=raise Fail "Mandelbrot expects dimension repetitions"end
