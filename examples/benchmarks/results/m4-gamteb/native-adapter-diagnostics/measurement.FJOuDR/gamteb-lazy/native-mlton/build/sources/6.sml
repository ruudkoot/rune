(*

      Patricia Fasel
      Los Alamos National Laboratory
      1990 August

 Copyright, 1990, The Regents of the University of California.
 This software was produced under a U.S. Government contract (W-7405-ENG-36)
 by the Los Alamos National Laboratory, which is operated by the University
 of California for the U.S. Department of Energy.  The U.S. Government is
 licensed to use, reproduce, and distribute this software.  Permission is
 granted to the public to copy and use this software without charge, provided
 that this notice and any statement of authorship are reproduced on all
 copies.  Neither the Government nor the University makes any warranty,
 express or implied, or assumes any liability for the use of this software.

*)
functor BenchGamtebTablesFn(D:BENCH_SUSPEND) =
struct
  fun table logarithm values=Vector.fromList(List.map(fn x=>D.delay(fn()=>
    if x<0.0000001 then ~30.0 else Math.ln(if logarithm then x else 2.2*x)))values)
  val erg=table true [0.001,0.0015,0.002,0.003,0.004,0.005,0.006,0.008,0.01,0.015,0.02,0.03,0.04,0.05,0.06,0.08,0.1,0.15,0.2,0.3,0.4,0.5,0.6,0.8,1.0,1.5,2.0,3.0,4.0,5.0,6.0,8.0,10.0,15.0,20.0]
  val xc=table false [0.015,0.0296,0.0451,0.0717,0.0913,0.105,0.115,0.128,0.137,0.152,0.160,0.165,0.165,0.163,0.160,0.153,0.146,0.133,0.122,0.106,0.0953,0.0867,0.0802,0.0707,0.0637,0.0516,0.0440,0.0346,0.0289,0.025,0.0221,0.0181,0.0154,0.0114,0.00913]
  val xp=table false [0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0000792,0.000316,0.000923,0.00153,0.00208,0.00256,0.00343,0.00414,0.00547,0.00652]
  val xpe=table false [2010.0,632.0,280.0,87.7,37.3,18.9,10.4,4.01,1.91,0.489,0.192,0.0491,0.0186,0.00887,0.00481,0.00179,0.000862,0.000234,0.0000918,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0]
  fun at values i=D.force(Vector.sub(values,i-1))
end
