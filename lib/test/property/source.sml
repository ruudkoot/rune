(* The source a case of a property is drawn from (docs/plans/quickcheck.md,
   D3): the seed of the case, the size, the nodes the shrinker has set, and
   the nodes read, in the order they are read. A node is an address in an
   implicit tree: every generator reads its own subtree, and a node's word is
   the one set for it, or what its sampler makes of the hash of the seed and
   the address. Nothing of the tree is built but the nodes a case reads. *)
structure PropertySource =
struct
  (* What a node's word stands for, which is what the shrinker may do with it. *)
  datatype kind = IntNode | WordNode | CharNode | RealNode | BoolNode | MarkNode | LengthNode | ChoiceNode

  type node = {address : Word64.word, word : Word64.word, kind : kind}

  type source = {seed : Word64.word, size : int, set : node list, trail : node list ref}

  fun new (seed : Word64.word, size : int, set : node list) : source =
    {seed = seed, size = size, set = set, trail = ref []}

  (* The address of the root, and of child i of the node at a. *)
  val root : Word64.word = 0wx5EED5EED5EED5EED
  fun child (a : Word64.word, i : int) : Word64.word =
    Random.hash (Word64.+ (Word64.* (a, 0wxD1B54A32D192ED03), Word64.+ (Word64.fromInt i, 0wx9E3779B97F4A7C15)))

  (* The child of a node at an observation, for a function's argument. *)
  fun childAt (a : Word64.word, w : Word64.word) : Word64.word =
    Random.hash (Word64.+ (Word64.* (a, 0wxBF58476D1CE4E5B9), Word64.xorb (w, 0wx94D049BB133111EB)))

  (* The word of the node at a: the one set for it, or the sample of the
     node's random word. The node is logged, with its kind. *)
  fun read ({seed, set, trail, ...} : source, a : Word64.word, kind : kind, sample : Word64.word -> Word64.word) : Word64.word =
    let
      val w = case List.find (fn n : node => #address n = a) set of
                SOME n => #word n
              | NONE => sample (Random.hash (Word64.xorb (seed, a)))
    in
      trail := {address = a, word = w, kind = kind} :: !trail; w
    end

  fun size ({size, ...} : source) : int = size
  fun seed ({seed, ...} : source) : Word64.word = seed
  fun nodes ({trail, ...} : source) : node list = List.rev (!trail)
end
