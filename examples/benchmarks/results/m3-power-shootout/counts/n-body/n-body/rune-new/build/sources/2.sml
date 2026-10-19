(* Shootout's contiguous mutable 7-slot body layout; pair/update order retained. *)
structure Benchmark =
struct
  val name = "n-body"
  val daysPerYear = 365.24
  val solarMass = 4.0 * Math.pow (Math.pi,2.0)
  val delta = 0.01
  val initial = [0.0, 0.0, 0.0,
     0.0, 0.0, 0.0,
     1.0 * solarMass,
     4.84143144246472090E00,        (~1.16032004402742839E00), (~1.03622044471123109E~01),
     1.66007664274403694E~03*daysPerYear,     7.69901118419740425E~03*daysPerYear, (~6.90460016972063023E~05)*daysPerYear,
     9.54791938424326609E~04 * solarMass,

     8.34336671824457987E00,        4.12479856412430479E00,    (~4.03523417114321381E~01),
     (~2.76742510726862411E~03)*daysPerYear,  4.99852801234917238E~03*daysPerYear, 2.30417297573763929E~05*daysPerYear,
     2.85885980666130812E~04 * solarMass,

     1.28943695621391310E01,        (~1.51111514016986312E01), (~2.23307578892655734E~01),
     2.96460137564761618E~03*daysPerYear,     2.37847173959480950E~03*daysPerYear, (~2.96589568540237556E~05)*daysPerYear,
     4.36624404335156298E~05 * solarMass,

     1.53796971148509165E01,        (~2.59193146099879641E01), 1.79258772950371181E~01,
     2.68067772490389322E~03*daysPerYear,     1.62824170038242295E~03*daysPerYear, (~9.51592254519715870E~05)*daysPerYear,
     5.15138902046611451E~05 * solarMass
    ] : real list
  type vector = real * real * real
  fun plus ((x,y,z):vector,(u,v,w):vector) = (x+u,y+v,z+w)
  fun minus ((x,y,z):vector,(u,v,w):vector) = (x-u,y-v,z-w)
  fun scale k ((x,y,z):vector) = (k*x,k*y,k*z)
  fun magnitude2 ((x,y,z):vector) = x*x+y*y+z*z
  fun get a i = (Array.sub(a,i),Array.sub(a,i+1),Array.sub(a,i+2))
  fun put a i (x,y,z) = (Array.update(a,i,x);Array.update(a,i+1,y);Array.update(a,i+2,z))
  fun mass a i = Array.sub(a,i+6)
  fun offsetMomentum a =
    let val momenta = List.map (fn i => scale (mass a i) (get a (i+3))) [7,14,21,28]
    in put a 3 (scale (~1.0/solarMass) (List.foldr plus (0.0,0.0,0.0) momenta)) end
  fun energy a =
    let fun pairs pos m e j = if j=35 then e else
          let val distance = Math.sqrt (magnitude2 (minus(pos,get a j)))
          in pairs pos m (e-m*mass a j/distance) (j+7) end
        fun bodies e i = if i=35 then e else
          let val position = get a i
              val velocity = get a (i+3)
              val m = mass a i
              val potential = pairs position m e (i+7)
          in bodies (potential+0.5*m*magnitude2 velocity) (i+7) end
    in bodies 0.0 0 end
  fun advance a =
    let fun bodies i = if i=35 then () else
          let val position = get a i
              val m = mass a i
              fun pairs j = if j=35 then
                    put a i (plus(get a i,scale delta (get a (i+3))))
                  else let val difference = minus(position,get a j)
                           val distance2 = magnitude2 difference
                           val distance = Math.sqrt distance2
                           val magnitude = delta/(distance2*distance)
                           val increment = scale magnitude difference
                           val otherMass = mass a j
                           val _ = put a (i+3) (minus(get a (i+3),scale otherMass increment))
                           val _ = put a (j+3) (plus(get a (j+3),scale m increment))
                       in pairs (j+7) end
              val _ = pairs (i+7)
          in bodies (i+7) end
    in bodies 0 end
  fun matchesWith (absolute,relative) observed expected =
    List.length observed=37 andalso List.length expected=37 andalso
    ListPair.allEq (fn (a,b) => BenchInput.closeReal(a,b,absolute,relative)) (observed,expected)
  val matches = matchesWith (2.0E~10,2.0E~10)
  fun run [steps,reference,absolute,relative] =
    let val n = BenchInput.between (0,50000000) (BenchInput.integer steps)
        fun bound s = case Real.fromString s of SOME r => r | NONE => raise Fail "invalid n-body error bound"
        val tolerance = (bound absolute,bound relative)
        val a = Array.fromList initial
        val _ = offsetMomentum a
        val initialEnergy = energy a
        fun loop 0 = () | loop left = (advance a;loop(left-1))
        val _ = loop n
        val after = energy a
        val observed = initialEnergy::after::List.tabulate(35,fn i => Array.sub(a,i))
        val file = TextIO.openIn reference
        val text = TextIO.inputAll file
        val _ = TextIO.closeIn file
        val expected = List.map (fn s => case Real.fromString s of
          SOME r => r | NONE => raise Fail "invalid n-body reference") (String.tokens Char.isSpace text)
        val _ = if matchesWith tolerance observed expected then () else raise Fail "n-body energy or complete state differs"
    in Int.toString n end
    | run _ = raise Fail "n-body expects steps reference absolute-bound relative-bound"
end
