(* The source a case of a property is drawn from (docs/plans/quickcheck.md,
   D3): the seed of the case, the size, the nodes the shrinker has set, and
   what the case reads. A node is a position in an implicit tree: every
   generator reads its own subtree, and a node's word is the one set for it,
   or what its sampler makes of the hash of the seed and the node's address.
   Nothing of the tree is built but the nodes a case reads. The path of a
   position is kept beside its address, so that the shrinker can move the
   nodes of an element of a list to the place of the one before it. The
   shrinker may also zero a subtree: a node below one of the source's zeroed
   paths that it has not set reads 0, the simplest word, which makes a
   generated function a constant. *)
structure PropertySource =
struct
  (* What a node's word stands for, which is what the shrinker may do with it. *)
  datatype kind = IntNode | WordNode | CharNode | RealNode | BoolNode | MarkNode | LengthNode | ChoiceNode

  (* A position: the address of a node, and the steps from the root to it. *)
  type position = {address : Word64.word, path : Word64.word list}

  type node = {address : Word64.word, path : Word64.word list, word : Word64.word, kind : kind}

  (* A list's layout: the address of the node of its length, and the paths
     of its elements' parts and of their marks (listOf has none). *)
  type sequence = {length : Word64.word, parts : Word64.word list, marks : Word64.word list option}

  type source = {seed : Word64.word, size : int, set : node list, zeros : Word64.word list list,
                 trail : node list ref, sequences : sequence list ref,
                 (* the calls of generated functions, by the function's position, as text *)
                 calls : (position * string) list ref,
                 (* the calls of effect-observing functions, as the side of a law made them *)
                 effects : string list ref}

  fun new (seed : Word64.word, size : int, set : node list, zeros : Word64.word list list) : source =
    {seed = seed, size = size, set = set, zeros = zeros, trail = ref [], sequences = ref [], calls = ref [],
     effects = ref []}

  fun resized (s : source, n : int) : source =
    {seed = #seed s, size = n, set = #set s, zeros = #zeros s, trail = #trail s, sequences = #sequences s,
     calls = #calls s, effects = #effects s}

  fun step (a : Word64.word, w : Word64.word) : Word64.word =
    Random.hash (Word64.+ (Word64.* (a, 0wxD1B54A32D192ED03), Word64.+ (w, 0wx9E3779B97F4A7C15)))

  val root : position = {address = 0wx5EED5EED5EED5EED, path = []}

  (* The position one step below p: child i, or the child at an observation. *)
  fun childAt ({address, path} : position, w : Word64.word) : position =
    {address = step (address, w), path = path @ [w]}
  fun child (p : position, i : int) : position = childAt (p, Word64.fromInt i)

  fun isPrefix ([], _) = true
    | isPrefix (_, []) = false
    | isPrefix (x :: xs, y :: ys : Word64.word list) = x = y andalso isPrefix (xs, ys)

  (* The address of a path. *)
  fun addressOf (path : Word64.word list) : Word64.word = List.foldl (fn (w, a) => step (a, w)) (#address root) path

  (* The word of the node at p: the one set for it, 0 below a zeroed path,
     or the sample of the node's random word. The node is logged, with its
     kind. *)
  fun read (s : source, {address, path} : position, kind : kind, sample : Word64.word -> Word64.word) : Word64.word =
    let
      val w = case List.find (fn n : node => #address n = address) (#set s) of
                SOME n => #word n
              | NONE =>
                  if List.exists (fn z => isPrefix (z, path)) (#zeros s) then 0w0
                  else sample (Random.hash (Word64.xorb (#seed s, address)))
    in
      #trail s := {address = address, path = path, word = w, kind = kind} :: !(#trail s); w
    end

  fun sequence (s : source, q : sequence) : unit = #sequences s := q :: !(#sequences s)
  fun call (s : source, f : position, text : string) : unit = #calls s := (f, text) :: !(#calls s)
  fun effect (s : source, text : string) : unit = #effects s := text :: !(#effects s)

  (* The effects logged since the last call, which forgets them. *)
  fun takeEffects (s : source) : string list = List.rev (!(#effects s)) before #effects s := []

  fun size ({size, ...} : source) : int = size
  fun seed ({seed, ...} : source) : Word64.word = seed

  (* The nodes read, each once, in the order first read. *)
  fun nodes (s : source) : node list =
    let
      fun once ([], _) = []
        | once ((n : node) :: rest, seen) =
            if List.exists (fn a => a = #address n) seen then once (rest, seen)
            else n :: once (rest, #address n :: seen)
    in
      once (List.rev (!(#trail s)), [])
    end

  (* A real as the word of its IEEE 754 bits, and back (the encoding of a
     real node), computed with Real's own operations: PackRealLittle and
     PackReal64Little are optional in the Basis, and compilers have one or
     the other. Every NaN is the word 0wx7FF8000000000000. *)
  val two52 : real = 4503599627370496.0
  fun bitsOf (x : real) : Word64.word =
    let
      val sign : Word64.word = if Real.signBit x then 0wx8000000000000000 else 0w0
      val a = Real.abs x
    in
      if Real.isNan x then 0wx7FF8000000000000
      else if not (Real.isFinite x) then Word64.orb (sign, 0wx7FF0000000000000)
      else if Real.== (a, 0.0) then sign
      else
        let
          val {man, exp} = Real.toManExp a
          val e = exp + 1022
        in
          if e >= 1 then
            Word64.orb (Word64.orb (sign, Word64.<< (Word64.fromInt e, 0w52)),
                        Word64.fromLargeInt (Real.toLargeInt IEEEReal.TO_NEAREST ((man * 2.0 - 1.0) * two52)))
          else
            Word64.orb (sign, Word64.fromLargeInt (Real.toLargeInt IEEEReal.TO_NEAREST
                                                     (Real.fromManExp {man = man, exp = exp + 1074})))
        end
    end
  fun realOf (w : Word64.word) : real =
    let
      val e = Word64.toInt (Word64.andb (Word64.>> (w, 0w52), 0wx7FF))
      val f = Real.fromLargeInt (Word64.toLargeInt (Word64.andb (w, 0wxFFFFFFFFFFFFF)))
      val magnitude =
        if e = 0x7FF then (if Real.== (f, 0.0) then Real.posInf else 0.0 / 0.0)
        else if e = 0 then Real.fromManExp {man = f / two52, exp = ~1022}
        else Real.fromManExp {man = 1.0 + f / two52, exp = e - 1023}
    in
      if Word64.andb (w, 0wx8000000000000000) <> 0w0 then ~ magnitude else magnitude
    end

  fun sequences (s : source) : sequence list = List.rev (!(#sequences s))
  fun calls (s : source) : (position * string) list = List.rev (!(#calls s))
end
