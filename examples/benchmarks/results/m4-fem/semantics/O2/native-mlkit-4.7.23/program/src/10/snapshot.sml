functor BenchFemSnapshotFn(K:sig
 structure A:sig
  type 'a store type 'a vec type 'a vbm
  val range:int->int->int list
  val arrayBounds:'a store->int*int
  val sub:'a store->int->'a
  val elements:'a vec->'a list
  val vbpositions:int->int vec->(int*int)list
  val vbdim:'a vbm->int
  val vbdiag:'a vbm->int vec
  val vbsub:'a vbm->int*int->'a
 end
 type database
 val database:string->database
 val ints:database->int A.store
 val reals:database->real A.store
 val nnode:database->int
 val degreeCount:database->int
 val nodeDegrees:database->int->int list
 val diagonal:database->int A.vec
 val stiffness:database->real A.vbm
 val decompose:real A.vbm->real A.vbm
 val loads:database->real A.vec
 val forward:real A.vec->real A.vbm->real A.vec
 val backward:real A.vec->real A.vbm->real A.vec
 val displacement:database->real A.vec
 val forces:database->real A.vec->real A.vec
end)=
struct
 fun integers name values=name^" "^String.concatWith" "(List.map Int.toString values)^"\n"
 fun floats name values=name^" "^String.concatWith" "(List.map(fn x=>Word32.toString(BenchFemFloat.bits x))values)^"\n"
 fun arrayValues array=let val(low,high)=K.A.arrayBounds array in List.map(K.A.sub array)(K.A.range low high)end
 fun band matrix=List.map(K.A.vbsub matrix)(K.A.vbpositions(K.A.vbdim matrix)(K.A.vbdiag matrix))
 fun render text=
   let val db=K.database text
       val matrix=K.stiffness db
       val factor=K.decompose matrix
       val load=K.loads db
       val forward=K.forward load factor
       val solution=K.backward forward factor
       val displacement=K.displacement db
       val forces=K.forces db displacement
   in integers"idatabase"(arrayValues(K.ints db))^
      floats"rdatabase"(arrayValues(K.reals db))^
      integers"degrees"(List.concat(List.map(K.nodeDegrees db)(K.A.range 1(K.nnode db))))^
      integers"degree-count"[K.degreeCount db]^
      integers"diagonal"(K.A.elements(K.diagonal db))^
      floats"stiffness"(band matrix)^floats"decomposition"(band factor)^
      floats"load"(K.A.elements load)^floats"forward"(K.A.elements forward)^
      floats"solution"(K.A.elements solution)^floats"displacement"(K.A.elements displacement)^
      floats"forces"(K.A.elements forces)
   end
end
