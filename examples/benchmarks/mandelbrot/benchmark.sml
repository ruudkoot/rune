structure Benchmark =
struct
  val name="mandelbrot"
  fun kernel (sz,maxCount) =
    let
    val x_base = ~2.0
    val y_base = 1.25
    val side = 2.5


    val delta = side / (real sz)

    val sum_iterations = ref 0

    fun loop1 i = if (i >= sz)
          then ()
          else let
            val c_im : real = y_base - (delta * real i)
            fun loop2 j = if (j >= sz)
                  then ()
                  else let
                    val c_re = x_base * (delta + real j)
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
                      sum_iterations := !sum_iterations + count;
                      loop2 (j+1)
                    end
            in
              loop2 0;
              loop1 (i+1)
            end

    in loop1 0; !sum_iterations end
  fun run [size,limit]=Int.toString(kernel(BenchInput.between(1,32768)(BenchInput.integer size),
      BenchInput.between(1,2048)(BenchInput.integer limit)))
  | run _=raise Fail "mandelbrot expects side iteration-limit"
end
