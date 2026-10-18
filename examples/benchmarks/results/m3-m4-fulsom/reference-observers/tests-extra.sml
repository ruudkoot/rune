 val _=check"raw-driver/N"(fn()=>NC.runRaw["4","depth-4.hex"]="1708")
 val _=check"raw-driver/E"(fn()=>EC.runRaw["4","depth-4.hex"]="1708")
 structure Undemanded=BenchFulsomCheckFn(struct fun picture(_:int):int BenchStream.stream=raise Fail"zero-work picture"end)
 val _=check"zero-repetitions-skip-renderer"(fn()=>Undemanded.runHashed["0","4","depth-4.hex","0"]="0:0")
 val _=check"strict-opaque-front-quad-skips-hidden-octree"(fn()=>
 let val hidden=L.delay(fn()=>raise Fail"hidden octree")
     val front=L.delay(fn()=>E.QFull E.white)
 in case L.force(E.qo hidden front)of E.QFull _=>true|_=>false end)
 val _=check"strict-false-change-keeps-dead-residual-undemanded"(fn()=>
 let val shape=L.delay(fn()=>E.Function(fn rgb=>fn _=>L.delay(fn()=>E.Result(E.I.point 1.0,L.delay(fn()=>raise Fail"dead csg"),rgb,L.delay(fn()=>false)))))
     val result=E.calc shape E.white(E.I.point 0.0,E.I.point 0.0,E.I.point 0.0)
 in E.I.greater(E.answer result)(E.I.point 0.0)andalso not(E.changed result)end)
