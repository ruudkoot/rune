(* A client of the compiler from Mid on (the haskell98 roadmap's M4, from
   its experiment E11): a program in Mid's text, with no source and no
   elaborator, through a list of passes the client edits, to a file the VM
   runs. What it does to the list:
     none      the list as it is
     remove    without refs and workers
     insert    with a pass of its own after lift, which counts the functions
     replace   with simplify replaced by simplify run twice
   mid-client-main.sml runs it on the layer from Mid on (MidPipeline),
   pipeline-client.sml on Rune's list (Pipeline). Each prints the list,
   and what it writes prints the same (tests/runner/tools.sml,
   compiler/mid-client). *)
structure MidClient =
struct
  val program = "\
    \(funs (fn g1 ((v1 : int)) : int\
    \  (let (v2 : bool) (prim int_lt v1 2 : (int * int) -> bool)\
    \  (if v2 (return 1)\
    \    (let (v3 : int) (prim int_sub v1 1 : (int * int) -> int)\
    \    (let (v4 : int) (app g1 v3)\
    \    (return (prim int_mul v1 v4 : (int * int) -> int))))))))\
    \(funs (fn g3 ((v8 : int * int)) : int\
    \  (let (v9 : int) (select 0 v8)\
    \  (let (v10 : int) (select 1 v8)\
    \  (let (v13 : bool) (prim int_lt v9 1 : (int * int) -> bool)\
    \  (if v13 (return v10)\
    \    (let (v14 : int) (prim int_sub v9 1 : (int * int) -> int)\
    \    (let (v15 : int) (prim int_add v10 v9 : (int * int) -> int)\
    \    (let (v16 : int * int) (tuple v14 v15)\
    \    (return (app g3 v16)))))))))))\
    \(val g2 : int (let (v5 : int) (app g1 10)\
    \  (let (v11 : int * int) (tuple v5 1)\
    \  (let (v12 : int) (app g3 v11) (return v12)))))\
    \(do () (let (v6 : string) (prim int_to_string g2 : int -> string)\
    \  (let (v7 : unit) (prim print v6 : string -> unit)\
    \  (return ()))))"

  (* the functions of the top level the pass of its own saw *)
  val functions = ref 0
  fun counted (p : Mid.program) : Mid.program =
    (functions := List.foldl (fn (Mid.Funs fs, n) => n + List.length fs | (_, n) => n) 0 p; p)
  fun twice (p : Mid.program) : Mid.program =
    let fun simplify p = Simplify.program (MidPipeline.simplifyOptions ()) p
    in simplify (simplify p) end

  fun edit (e : string) (ps : MidPipeline.midPass list) : MidPipeline.midPass list =
    case e of
      "none" => ps
    | "remove" => MidPipeline.removePass "workers" (MidPipeline.removePass "refs" ps)
    | "insert" => MidPipeline.insertAfter ("lift", {name = "client", from = 1, gate = fn () => true, run = counted}) ps
    | "replace" => MidPipeline.replacePass ("simplify", MidPipeline.pass ("simplify", twice)) ps
    | _ => raise Fail ("mid-client: no edit " ^ e)

  (* the program through the list whose names are given, to out *)
  fun compile ({names : string list, lowOfMid : Mid.program -> Low.program}, e : string, out : string) : unit =
    let
      val () = print (String.concatWith " " names ^ "\n")
      val low = lowOfMid (MidPipeline.midStage NONE MidText.parse program)
      val code = MidPipeline.targetStage low
    in
      Emit.writeFileAs (MidPipeline.fingerprint (), out, code);
      if e = "insert" then print ("client saw " ^ Int.toString (!functions) ^ " functions\n") else ()
    end

  fun arguments () : string * string =
    case CommandLine.arguments () of
      [e, out] => (e, out)
    | _ => raise Fail "mid-client EDIT OUT"
end
