(* The order in which SML/NJ's CM compiles the SML files of a library
   description, one line "FILE path" per file, of the portable dependency
   graph of CM.Graph, whose definitions are in dependency order. Run by
   tests/basis/xc2/smlnj-legacy/gen.sh with the host's sml, the description in
   XC2_CM. *)
val _ = CM.autoload "$/pgraph.cm";
structure P = PortableGraph;
val _ =
  case OS.Process.getEnv "XC2_CM" of
    NONE => OS.Process.exit OS.Process.failure
  | SOME cm =>
      (case CM.Graph.graph cm of
         NONE => OS.Process.exit OS.Process.failure
       | SOME {graph = P.GRAPH {defs, ...}, ...} =>
           List.app (fn P.DEF {rhs = P.COMPILE {src = (f, _), ...}, ...} => print ("FILE " ^ f ^ "\n")
                      | _ => ()) defs);
val _ = OS.Process.exit OS.Process.success;
