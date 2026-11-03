(* Fact edits (docs/testing.md, The checks of the cache; E18): each flips one
   fact that a fingerprint hashes, or that a key holds, and keeps the rest.
   The value keeps its name and type, so that a client's usage holds or
   breaks by that fact alone; soundness.sml's random edits do not flip them.
   Each is a scenario: the project built through a cache, edited, built again,
   the units compiled as the row says and the program the bytes a build
   without the cache gives, or both refusing it. *)
structure CacheFacts =
struct
  open Incremental

  (* what the edit does to the build *)
  datatype outcome = Compiles of string | Refused
  (* a fact the build file holds says so: a.sml and b.sml are its files *)
  type fact = {name : string, first : string, second : string, client : string, flags : string list, want : outcome,
               marks : string * string}

  val print' = "val () = print (Int.toString (A.g 1) ^ \"\\n\")"
  fun fact (name, first, second, client, flags, want) : fact =
    {name = name, first = first, second = second, client = client, flags = flags, want = want, marks = ("", "")}
  (* built from a build file, which says marks and then marks' *)
  fun marked (name, first, second, client, want, marks) : fact =
    {name = name, first = first, second = second, client = client, flags = ["--build", "p.build"], want = want, marks = marks}
  val two = "files a.sml b.sml end"
  fun structA body = "structure A = struct " ^ body ^ " end"

  val facts : fact list =
    [(* a value that is another global (Expand.globalAliases) *)
     fact ("alias", structA "fun h x = x + 1 fun k x = x + 2 val g = h", structA "fun h x = x + 1 fun k x = x + 2 val g = k",
           print', [], Compiles "a.sml b.sml"),
     (* a function known by name (Lower.knownBefore), each way *)
     fact ("known", structA "fun g x = x + 1", structA "val r = ref 1 val g = (r := 2; fn x => x + 1)",
           print', [], Compiles "a.sml b.sml"),
     fact ("knownback", structA "val r = ref 1 val g = (r := 2; fn x => x + 1)", structA "fun g x = x + 1",
           print', [], Compiles "a.sml b.sml"),
     (* a primitive under the name (Translate.primAliases), each way *)
     fact ("prim", structA "val g = Int.abs", structA "fun g (x : int) = x + 1",
           print', [], Compiles "a.sml b.sml"),
     fact ("primback", structA "fun g (x : int) = x + 1", structA "val g = Int.abs",
           print', [], Compiles "a.sml b.sml"),
     fact ("primalias", structA "val g : int -> int = Int.abs", structA "val g : int -> int = ~",
           print', [], Compiles "a.sml b.sml"),
     fact ("aliasprim", structA "fun h (x : int) = Int.abs x val g = h", structA "fun h (x : int) = x val g = h",
           print', [], Compiles "a.sml b.sml"),
     (* a constructor's tag, by the order of the datatype's constructors *)
     fact ("tag", structA "datatype t = X | Y fun g _ = 1", structA "datatype t = Y | X fun g _ = 1",
           "val () = print (case A.X of A.X => \"x\\n\" | A.Y => \"y\\n\")", [], Compiles "a.sml b.sml"),
     (* what an abstract type is (Ty.realizations) *)
     fact ("realised", "structure A :> sig type t val v : t val g : t -> int end = struct type t = int val v = 1 fun g x = x end",
           "structure A :> sig type t val v : t val g : t -> int end = struct type t = string val v = \"1\" fun g x = 1 end",
           "val () = print (Int.toString (A.g A.v) ^ \"\\n\")", [], Compiles "a.sml b.sml"),
     (* a type variable's equality *)
     fact ("eqvar", structA "fun g (x : 'a) = 0", structA "fun g x = if x = x then 0 else 1",
           "val () = print (Int.toString (A.g 1.5) ^ \"\\n\")", [], Refused),
     (* a type name's equality: an abstract type, whose definition is
        nothing else *)
     fact ("eqname", "structure A :> sig eqtype t val v : t end = struct type t = int val v = 1 end",
           "structure A :> sig type t val v : t end = struct type t = int val v = 1 end",
           "val () = print (if A.v = A.v then \"same\\n\" else \"other\\n\")", [], Refused),
     (* a new global of its own, of another value: its unit alone *)
     fact ("which", structA "val u = 1 val w = 2 val g = u", structA "val u = 1 val w = 2 val g = w",
           "val () = print (Int.toString A.g ^ \"\\n\")", [], Compiles "a.sml"),
     (* which value a name is (the anchor): the same global as another of
        the type, reached by a structure's other name, so that a remap by
        the old path would find the old value (build-cache issue 8) *)
     fact ("anchor", "structure A = struct val x = 1 end structure B = A",
           "structure A = struct val x = 1 end structure C = struct val x = 2 end structure B = C",
           "val () = print (Int.toString B.x ^ \"\\n\")", [], Compiles "a.sml b.sml"),
     (* a primitive by its own declaration, a usage of its structure *)
     fact ("primdirect", structA "val g = _prim \"int_abs\" : int -> int", structA "val g = _prim \"int_neg\" : int -> int",
           "structure C = A val () = print (Int.toString (C.g 1) ^ \"\\n\")", ["--allow-prim"], Compiles "a.sml b.sml"),
     (* a function that is a primitive (Expand.primGlobals), which a call
        of it in another unit becomes, reached by a structure's other name,
        where the usage is the structure and no inlv says what it is *)
     fact ("primfunction", structA "fun g (x : int) = Int.abs x", structA "fun g (x : int) = ~ x",
           "structure C = A val () = print (Int.toString (C.g 1) ^ \"\\n\")", [], Compiles "a.sml b.sml"),
     (* a marked function's or functor's body, which a client copies: an
        edit of its body is an edit of the client (the usages inl, inlv) *)
     marked ("inlfunctor", "functor F (X : sig val n : int end) = struct fun f y = y + X.n end",
             "functor F (X : sig val n : int end) = struct fun f y = y + X.n + 1 end",
             "structure B = F (struct val n = 2 end) val () = print (Int.toString (B.f 1) ^ \"\\n\")",
             Compiles "a.sml b.sml", ("inline functor F end\n" ^ two, "inline functor F end\n" ^ two)),
     marked ("inlvalue", structA "fun g x = x + 1", structA "fun g x = x + 2", print', Compiles "a.sml b.sml",
             ("inline val A.g end\n" ^ two, "inline val A.g end\n" ^ two)),
     (* the marks themselves: the configuration holds them, so every unit
        of the library compiles again, and a client copies no more *)
     marked ("markfunctor", "functor F (X : sig val n : int end) = struct fun f y = y + X.n end",
             "functor F (X : sig val n : int end) = struct fun f y = y + X.n end",
             "structure B = F (struct val n = 2 end) val () = print (Int.toString (B.f 1) ^ \"\\n\")",
             Compiles "a.sml b.sml", ("inline functor F end\n" ^ two, two)),
     marked ("markvalue", structA "fun g x = x + 1", structA "fun g x = x + 1", print', Compiles "a.sml b.sml",
             ("inline val A.g end\n" ^ two, two))]

  fun named name = List.find (fn (f : fact) => #name f = name) facts
  val prefix = "fact-"
  val cases = List.map (fn (f : fact) => prefix ^ #name f) facts

  fun run (s : state) (f : fact) =
    let
      val (marks, marks') = #marks f
      val () = (own s (if marks = "" then "a.sml b.sml" else ""); put s "a.sml" (#first f); put s "b.sml" (#client f))
      val () = if marks = "" then () else put s "p.build" marks
      val () = build s (#flags f)
      val () = check s "the project does not build before its edit" (#status (!(#result s)) = 0)
      val () = put s "a.sml" (#second f)
      val () = if marks = "" then () else put s "p.build" marks'
    in
      case #want f of
        Compiles expected => checkBuild s (#flags f) expected
      | Refused =>
          let
            val () = build s (#flags f)
            val plain = compile s (["--units", "--no-cache"] @ #flags f) "nocache.rbc"
          in
            check s "a build without the cache refuses the edit, and the fact edit wants that" (#status plain <> 0);
            check s "the build through the cache took what a build without it refuses" (#status (!(#result s)) <> 0)
          end
    end

  fun one (s : state) = run s (valOf (named (String.extract (#name s, size prefix, NONE))))
end
