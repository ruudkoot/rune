(* The units of a program, linked into one (docs/units.md;
   docs/plans/incremental-compilation.md, D7 and M2). A unit is compiled on
   its own, after the units before it, into code numbered from 0: its own
   functions, its top level the first of them, then the functions of
   earlier units it calls by name; the globals it names, its own and theirs,
   in the order it first names them; its constants, labels, files and
   inlined frames. Linking gives each unit a base for each of these and
   renumbers every operand that names one, by the kind the instruction set
   gives it (RegCodes.linked, Opcodes.linked): an own function or
   constant by the unit's base, a function or global of another unit by
   its name, through the unit that defines it. A unit names what it
   declared, and what earlier units did, by a key: a unit's identity and a
   number there (UnitBasis, which gives the numbers), so that a unit's code
   does not depend on what was compiled before it.

   A unit's top level ends in a tail call of the next unit's (Lower, the
   import `next`), so that the program's function 0 is the first unit's
   top level and one top level is running at a time, as in a program
   compiled whole: a trace shows the same frames. The last unit's goes to
   a function that returns. *)
structure Link =
struct
  open Code

  (* A unit as the compile made it, its names the session's stamps: the
     stamp of every global it names, by its index here; the stamps of the
     globals it sets (its own); the functions of earlier units it calls by
     name, and the next unit's top level (stamp `next`), by their index here;
     and its own functions that other units may call by name, by stamp. Its
     own functions are those of code. *)
  type sessionCode = {code : Code.program,
                      globals : (int * int) list,      (* stamp, index here *)
                      defines : int list,              (* stamps *)
                      imports : (int * int) list,      (* index here, stamp *)
                      exports : (int * int) list}      (* stamp, index here *)

  (* A name a unit's code has of a unit: that unit's identity and its number
     there; the next unit's top level is {unit = "", number = ~1} *)
  type key = {unit : string, number : int}

  (* A unit as it is linked, written and loaded: its identity; each global
     it names, by its index here; the functions of earlier units it calls by
     name, and the next unit's top level, by their index here; and its own
     functions that other units may call by name, by number. The globals
     whose key is the unit's own are those it sets. *)
  type unitCode = {code : Code.program,
                   identity : string,
                   provenance : string option,
                   globals : (key * int) list,         (* key, index here *)
                   imports : (int * key) list,         (* index here, key *)
                   exports : (int * int) list}         (* number, index here *)

  (* the stamp a unit's top level names the next unit's by, and its key *)
  val next = Lower.nextUnit
  val nextKey : key = {unit = "", number = ~1}

  (* The globals a unit's code sets, by stamp, each once: its own. *)
  fun defines (p : Low.program) : int list =
    IntMap.listKeys
      (List.foldl (fn ({blocks, ...} : Low.func, acc) =>
                     List.foldl (fn ({instrs, ...} : Low.block, acc) =>
                                   List.foldl (fn (Low.Def (_, Low.SetGlobal (g, _)), acc) => IntMap.insert (acc, g, ())
                                                | (_, acc) => acc)
                                              acc instrs)
                                acc blocks)
                  IntMap.empty p)

  fun bug msg = Error.bug ("link: " ^ msg)

  (* Units whose interfaces do not fit: a unit calls a function of another,
     or reads a global of it, as other than that unit declares it (Code.expects
     against Code.meta and Code.program's globalReps; the linting roadmap's
     D15) *)
  exception Mismatch of string

  (* RUNE_LINK_CHECK=0: the interfaces not checked, to measure what the
     check costs *)
  fun checking () = OS.Process.getEnv "RUNE_LINK_CHECK" <> SOME "0"

  (* whether a value of one representation may be where another is wanted:
     one is the other's, or a downcast the types justify (RegVerify) *)
  fun fits (a : int, b : int) : bool = RegVerify.le (a, b) orelse RegVerify.le (b, a)
  fun repName r = Low.repName (Low.repOfCode r)
  (* the representations a mask holds *)
  fun repsIn (mask : int) : int list =
    let fun go (r, m) = if m = 0 then [] else if m mod 2 = 1 then r :: go (r + 1, m div 2) else go (r + 1, m div 2)
    in go (0, mask) end

  (* The function the last unit's top level goes to, made by the target
     from Low as every other function is: it returns its argument. *)
  fun endFunction (target : Low.program -> Code.program) : Code.program =
    target [{id = 0, name = "<toplevel>", params = [0], ncaptured = 0, nvars = 1,
             blocks = [{label = 0, params = [], instrs = [], transfer = Low.Return 0}], pos = NONE,
             reps = Vector.fromList [Low.RUnit], result = Low.RUnit, captures = []}]

  (* What each unit of the last program linked exports, by its numbers, as
     the program has it -- a function (0) or a global (1), its number in the
     unit, its index in the program -- for a unit loaded into the program
     later to name (docs/units.md, Dynamic modules) *)
  val lastExports : (string * (int * int * int) list) list ref = ref []
  val () = CompilerState.cellRoot ("Link.lastExports", lastExports)
  (* Interface identities deliberately survive implementation-only changes.
     Provenance travels with each immutable unit, including through files. *)
  fun provenance (target,mode,sourceHash) =
    Pickle.hash (Config.identity ^ ":" ^ target ^ ":" ^ Source.modeName mode ^ ":" ^ sourceHash)
  val sourceMarker = "\001RuneSource:"
  fun sourceName (identity,hash) = sourceMarker ^ hash ^ ":" ^ identity
  (* the hash runs to the first ":" after the marker: it is hexadecimal
     digits, as many as Pickle.hash gives *)
  fun sourceOf (identity,name) =
    if not (String.isPrefix sourceMarker name) then NONE else
    let val rest=String.extract (name,String.size sourceMarker,NONE)
        val (hash,tail)=Substring.splitl (fn c => c <> #":") (Substring.full rest)
    in if Substring.size hash > 0 andalso Substring.size tail > 0
          andalso Substring.string (Substring.triml 1 tail)=identity
       then SOME (Substring.string hash) else NONE end

  fun program (target : Low.program -> Code.program, linked : (int * int) list vector, units : unitCode list)
      : Code.program =
    let
      val units = units @ [{code = endFunction target, identity = "", provenance=NONE, globals = [], imports = [], exports = []}]
      val sourceHashes=List.foldl (fn (u : unitCode,m) => case #provenance u of NONE => m
        | SOME hash => StringMap.insert (m,#identity u,hash)) StringMap.empty units
      (* every key a number of the link's own: next is next *)
      val keyIds : int StringMap.map ref = ref StringMap.empty
      (* how many: StringMap.numItems would walk the map at each new key *)
      val nkeyIds = ref 0
      fun keyId ({unit, number} : key) : int =
        if unit = "" andalso number = ~1 then next
        else
          let val k = unit ^ "\000" ^ Int.toString number
          in
            case StringMap.find (!keyIds, k) of
              SOME i => i
            | NONE => let val i = !nkeyIds in nkeyIds := i + 1; keyIds := StringMap.insert (!keyIds, k, i); i end
          end
      (* the bases of each unit's functions *)
      val nunits = List.length units
      val fbases =
        Vector.fromList (List.rev (#2 (List.foldl (fn (u : unitCode, (b, acc)) => (b + List.length (#funcs (#code u)), b :: acc))
                                                  (0, []) units)))
      (* every function another unit may call by name, by stamp *)
      val exported =
        #2 (List.foldl (fn (u : unitCode, (i, m)) =>
                          (i + 1, List.foldl (fn ((n, f), m) =>
                                                IntMap.insert (m, keyId {unit = #identity u, number = n},
                                                               Vector.sub (fbases, i) + f)) m
                                             (#exports u)))
                       (0, IntMap.empty) units)
      (* the files and inlined frames of the whole, in order *)
      val files : string list ref = ref []
      val nfiles = ref 0
      val fileIndex : int StringMap.map ref = ref StringMap.empty
      fun fileIdx name =
        case StringMap.find (!fileIndex, name) of
          SOME i => i
        | NONE => let val i = !nfiles in files := name :: !files; nfiles := i + 1; fileIndex := StringMap.insert (!fileIndex, name, i); i end
      val inlines : (string * int * int * int * int) list ref = ref []
      val ninlines = ref 0
      val consts : Lambda.const list ref = ref []
      val nconsts = ref 0
      val nglobals = ref 0
      val globalOf : int IntMap.map ref = ref IntMap.empty
      (* what each global holds, as the unit that sets it declares, by its
         number in the program *)
      val globalReps : (int * int) list ref = ref []
      (* what each unit expects of the units before it, by their numbers in
         the program, checked once every unit is linked: a call (the unit,
         the callee's key, its function, the arity, the masks of what is
         passed and of what the result is taken as) and a read of a global
         (the unit, the global's key, its number, the mask) *)
      val calls : (string * key * int * int * int list * int) list ref = ref []
      val reads : (string * key * int * int) list ref = ref []
      val nlabels = ref 0
      fun linkUnit (i, u : unitCode) : Code.func list =
        let
          val code = #code u
          val fbase = Vector.sub (fbases, i)
          val nown = List.length (#funcs code)
          val cbase = !nconsts
          val lbase = !nlabels
          val ibase = !ninlines
          (* the stamp of each global it names, by its index here *)
          val stamps = Array.array (#nglobals code, ~1)
          val () = List.app (fn (k, ix) => Array.update (stamps, ix, keyId k)) (#globals u)
          (* the globals it sets, its own, get the next numbers, in the order
             of their index here; the others are another unit's *)
          val own = List.foldl (fn (({unit, ...} : key, ix), m) =>
                                  if unit = #identity u then IntMap.insert (m, Array.sub (stamps, ix), ()) else m)
                               IntMap.empty (#globals u)
          val () =
            Array.app (fn st =>
                         if IntMap.member (own, st) andalso not (IntMap.member (!globalOf, st))
                         then (globalOf := IntMap.insert (!globalOf, st, !nglobals); nglobals := !nglobals + 1)
                         else ())
                      stamps
          val globalMap =
            Array.tabulate (Array.length stamps,
                            fn ix => let val st = Array.sub (stamps, ix)
                                     in case IntMap.find (!globalOf, st) of
                                          SOME g => g
                                        | NONE => bug ("a global is set by no unit before (" ^ Int.toString st ^ ")")
                                     end)
          val () =
            case #globalReps code of
              [] => ()
            | rs =>
                let val rv = Vector.fromList rs
                in
                  List.app (fn (k : key, ix) =>
                              if #unit k = #identity u andalso ix >= 0 andalso ix < Vector.length rv
                              then globalReps := (Array.sub (globalMap, ix), Vector.sub (rv, ix)) :: !globalReps else ())
                           (#globals u)
                end
          val importMap = List.foldl (fn ((ix, k), m) => IntMap.insert (m, ix, keyId k)) IntMap.empty (#imports u)
          fun func f =
            if f < nown then fbase + f
            else case IntMap.find (importMap, f) of
                   SOME s =>
                     if s = next then Vector.sub (fbases, i + 1)
                     else (case IntMap.find (exported, s) of
                             SOME g => g
                           | NONE => bug ("a function is exported by no unit before (" ^ Int.toString s ^ ")"))
                 | NONE => bug ("function " ^ Int.toString f ^ " of a unit is neither its own nor imported")
          fun global g = Array.sub (globalMap, g)
          val () =
            if not (checking ()) then ()
            else
              let
                val keyOf = List.foldl (fn ((ix, k), m) => IntMap.insert (m, ix, k)) IntMap.empty (#imports u)
                val {calls = cs, reads = rs} = #expects code
              in
                List.app (fn (fid, n, masks, rm) =>
                            if fid < nown then ()
                            else
                              case IntMap.find (keyOf, fid) of
                                SOME k => calls := (#identity u, k, func fid, n, masks, rm) :: !calls
                              | NONE => ())
                         cs;
                case rs of
                  [] => ()
                | _ =>
                    let val rv = Vector.fromList rs
                    in
                      List.app (fn (k : key, ix) =>
                                  if #unit k = #identity u orelse ix < 0 orelse ix >= Vector.length rv then ()
                                  else
                                    let val m = Vector.sub (rv, ix)
                                    in if m = 0 then () else reads := (#identity u, k, global ix, m) :: !reads end)
                               (#globals u)
                    end
              end
          fun renumber (kind, v) =
            case kind of
              0 => func v
            | 1 => global v
            | _ => cbase + v
          fun operands (opc, args : 'a list, get : 'a -> int option, put : 'a * int -> 'a) : 'a list =
            let
              val ks = Vector.sub (linked, opc)
              fun go (_, []) = []
                | go (n, a :: rest) =
                    (case (List.find (fn (p, _) => p = n) ks, get a) of
                       (SOME (_, k), SOME v) => put (a, renumber (k, v))
                     | _ => a) :: go (n + 1, rest)
            in go (0, args) end
          val files = Vector.fromList (#files code)
          val fileMap = Vector.map fileIdx files
          fun file f = if f >= 0 andalso f < Vector.length fileMap then Vector.sub (fileMap, f) else f
          fun inline j = if j = 0 then 0 else ibase + j
          fun item it =
            case it of
              Op (opc, args) => Op (opc, operands (opc, args, SOME, fn (_, v) => v))
            | Ops (opc, args) =>
                Ops (opc, List.map (fn I v => I v | L l => L (lbase + l))
                                   (operands (opc, args, fn I v => SOME v | L _ => NONE, fn (_, v) => I v)))
            | OpLab (opc, l) => OpLab (opc, lbase + l)
            | OpLabImm (opc, l, x) => OpLabImm (opc, lbase + l, x)
            | Lab l => Lab (lbase + l)
            | Pos (f, line, col, j) => Pos (file f, line, col, inline j)
          fun meta NONE = NONE
            | meta (SOME {arity, reps, blocks, loops, result, captures} : meta option) =
                SOME {arity = arity, reps = reps, blocks = List.map (fn (l, ps) => (lbase + l, ps)) blocks,
                      loops = List.map (fn l => lbase + l) loops, result = result, captures = captures}
          val () =
            List.app (fn (name, f, line, col, parent) =>
                        (inlines := (name, if line = 0 then f else file f, line, col, inline parent) :: !inlines;
                         ninlines := !ninlines + 1))
                     (#inlines code)
          val () = List.app (fn c => (consts := c :: !consts; nconsts := !nconsts + 1)) (#consts code)
          val () = nlabels := lbase + #nlabels code
        in
          List.map (fn ({id, nlocals, code, name, meta = m} : func) =>
                      {id = fbase + id, nlocals = nlocals, code = List.map item code, name = name, meta = meta m})
                   (#funcs code)
        end
      val funcs = List.concat (List.rev (#2 (List.foldl (fn (u, (i, acc)) => (i + 1, linkUnit (i, u) :: acc)) (0, []) units)))
      val () =
        lastExports :=
          List.mapPartial
            (fn (i, u : unitCode) =>
               if #identity u = "" then NONE
               else
                 (* by kind and number: a unit read from the cache lists its
                    globals in another order than its compile did; the
                    first of a kind and number kept, by a merge sort, not
                    an insertion sort, which took the square of a unit's
                    exports (functors-units, E3) *)
                 SOME (#identity u,
                       let
                         fun lt ((k, n, _), (k', n', _)) = k < k' orelse (k = k' andalso n < n')
                         fun merge ([], ys) = ys
                           | merge (xs, []) = xs
                           | merge (x :: xs, y :: ys) =
                               if lt (y, x) then y :: merge (x :: xs, ys)
                               else if lt (x, y) then x :: merge (xs, y :: ys)
                               else x :: merge (xs, ys)
                         fun sort [] = []
                           | sort [x] = [x]
                           | sort xs = let val h = List.length xs div 2
                                       in merge (sort (List.take (xs, h)), sort (List.drop (xs, h))) end
                       in sort end
                                  ((0, ~1, Vector.sub (fbases, i)) ::
                                   List.map (fn (n, f) => (0, n, Vector.sub (fbases, i) + f)) (#exports u)
                                   @ List.mapPartial (fn (k : key, _) =>
                                                        if #unit k = #identity u
                                                        then Option.map (fn g => (1, #number k, g)) (IntMap.find (!globalOf, keyId k))
                                                        else NONE)
                                                     (#globals u))))
            (ListPair.zip (List.tabulate (nunits, fn i => i), units))
      val () = lastExports := List.concat (List.map (fn (identity,exports) =>
        (identity,exports) ::
          (case StringMap.find (sourceHashes,identity) of NONE => [] | SOME hash =>
            [(sourceName (identity,hash),
              List.filter (fn (kind,number,_) => kind=0 andalso number= ~1) exports)])) (!lastExports))
      val greps = Array.array (!nglobals, 0)
      val () = List.app (fn (g, r) => Array.update (greps, g, r)) (!globalReps)
      val prog : Code.program =
        {consts = List.rev (!consts), nglobals = !nglobals, funcs = funcs, files = List.rev (!files),
         inlines = List.rev (!inlines), nlabels = !nlabels,
         globalReps = if List.null (!globalReps) then [] else Array.foldr (op ::) [] greps,
         expects = expectsNothing}
      (* the interfaces: what each unit expects of the units before it,
         against what they declare -- in time linear in the imports, where a
         check of the whole program took a fifth of a warm build (the linting
         roadmap's D15); a check of level 0, always on but where --lint=off
         says, which --pass-stats counts as "link" and which moves none of
         the compiler's counters (Pass.checkAt; the roadmap's D12) *)
      val () =
        if List.null (!calls) andalso List.null (!reads) then ()
        else Pass.checkAt ("link", 0) (fn () =>
          let
            val metas = Array.array (List.length funcs, NONE)
            val () = List.app (fn ({id, meta, name, ...} : func) =>
                                 if id >= 0 andalso id < Array.length metas then Array.update (metas, id, SOME (name, meta)) else ())
                              funcs
            val wrong : string list ref = ref []
            fun no msg = wrong := msg :: !wrong
            fun named what ({unit, number} : key) =
              if unit = "" then "the next unit's top level" else unit ^ "'s " ^ what ^ " " ^ Int.toString number
            fun call (importer, k, g, n, masks, rm) =
              case (if g >= 0 andalso g < Array.length metas then Array.sub (metas, g) else NONE) of
                SOME (name, SOME {arity, reps, result, ...}) =>
                  let
                    val what = importer ^ " calls " ^ name ^ " (" ^ named "function" k ^ ")"
                    val rv = Vector.fromList reps
                  in
                    if n <> arity then no (what ^ (if n < 0 then " with two counts of arguments" else " with " ^ Int.toString n ^ " arguments")
                                           ^ ", where it takes " ^ Int.toString arity)
                    else
                      (ignore (List.foldl (fn (mask, j) =>
                                             let val q = if j < Vector.length rv then Vector.sub (rv, j) else 0
                                             in
                                               List.app (fn r => if fits (r, q) then ()
                                                                 else no (what ^ " with " ^ repName r ^ " for its argument "
                                                                          ^ Int.toString j ^ ", where it takes " ^ repName q))
                                                        (repsIn mask);
                                               j + 1
                                             end) 0 masks);
                       List.app (fn e => if fits (result, e) then ()
                                         else no (what ^ " and takes its result as " ^ repName e ^ ", where it returns " ^ repName result))
                                (repsIn rm))
                  end
              | SOME (_, NONE) => ()
              | NONE => no (importer ^ " calls " ^ named "function" k ^ ", which is no function of the program")
            fun read (importer, k, g, mask) =
              let val q = if g >= 0 andalso g < Array.length greps then Array.sub (greps, g) else 0
              in
                List.app (fn r => if fits (q, r) then ()
                                  else no (importer ^ " reads " ^ named "global" k ^ " as " ^ repName r ^ ", where it holds " ^ repName q))
                         (repsIn mask)
              end
          in
            List.app call (List.rev (!calls));
            if List.null (!globalReps) then () else List.app read (List.rev (!reads));
            case List.rev (!wrong) of
              [] => ()
            | ws => raise Mismatch (String.concatWith "; " (List.take (ws, Int.min (3, List.length ws)))
                                    ^ (if List.length ws > 3 then "; and " ^ Int.toString (List.length ws - 3) ^ " more" else ""))
          end) ()
      (* the program checked whole too, at level 2 or where
         RUNE_REGVERIFY_LINK says (docs/plans/correctness/linting.md, M9
         and M16) *)
      val () = RegVerify.linked prog
    in
      prog
    end
end
