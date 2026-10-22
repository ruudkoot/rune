(* Compiler-root ownership. Roots are registered during module initialization;
   the baseline is sealed only after the entire compiler has initialized.
   Snapshots own table buckets and arrays, while immutable maps and each
   session's mutable type/AST graphs retain their identities. They are for
   switching owners, not for rolling back mutations within one owner. *)
structure CompilerState :> COMPILER_STATE =
struct
  type snapshot = (unit -> unit) list
  type root = {name : string, capture : bool -> (unit -> unit)}
  val roots : root list ref = ref []
  val baseline : snapshot option ref = ref NONE
  val next = ref 0
  datatype session = Session of {id : int, saved : snapshot option ref}
  val active : session list ref = ref []
  exception Closed
  exception Active

  fun root (name, capture) =
    if isSome (!baseline) then raise Fail ("compiler root registered after sealing: " ^ name)
    else if List.exists (fn r : root => #name r = name) (!roots)
    then raise Fail ("duplicate compiler root: " ^ name)
    else roots := {name = name, capture = capture} :: !roots

  fun names () = List.map #name (List.rev (!roots))
  fun capture copying = List.map (fn r : root => #capture r copying) (List.rev (!roots))
  fun restore saved = List.app (fn put => put ()) saved
  fun seal () = if isSome (!baseline) then () else baseline := SOME (capture true)

  fun refRoot (name, cell, clone) =
    root (name, fn copying =>
      let val saved = if copying then clone (!cell) else !cell
      in fn () => cell := (if copying then clone saved else saved) end)
  fun cellRoot (name, cell) = refRoot (name, cell, fn x => x)
  fun copyArray a = Array.tabulate (Array.length a, fn i => Array.sub (a, i))
  fun arrayRoot (name, array) =
    root (name, fn _ => let val saved = copyArray array
                        in fn () => Array.copy {src = saved, dst = array, di = 0} end)
  fun tableSave copying table =
    if copying then
      let val saved = IntTable.copy table
      in fn () => IntTable.restore (table, saved) end
    else
      let val saved = IntTable.saveStorage table
      in fn () => IntTable.restoreStorage (table, saved) end
  fun tableRoot (name, table) =
    root (name, fn copying => tableSave copying table)
  fun tableVectorRoot (name, tables) =
    root (name, fn copying =>
      let val saved = Vector.map (tableSave copying) tables
      in fn () => Vector.app (fn put => put ()) saved end)

  fun session () =
    let
      val () = seal ()
      val previous = capture false
      val saved = (restore (valOf (!baseline)); capture false)
                  handle e => (restore previous; raise e)
      val () = restore previous
      val id = !next
      val () = next := id + 1
    in Session {id = id, saved = ref (SOME saved)} end

  fun idOf (Session {id, ...}) = id
  fun save (Session {saved, ...}, state) = saved := SOME state
  fun stateOf (Session {saved, ...}) =
    case !saved of SOME state => state | NONE => raise Closed
  fun close (Session {id, saved}) =
    if List.exists (fn owner => idOf owner = id) (!active) then raise Active else saved := NONE

  fun withSession (owner as Session {id, saved}, f) =
    case !saved of
      NONE => raise Closed
    | SOME state =>
        if (case !active of current :: _ => idOf current = id | [] => false) then f ()
        else
          let
            val previous = capture false
            val callers = !active
            val () = case callers of caller :: _ => save (caller, previous) | [] => ()
            fun reset () =
              (restore (case callers of caller :: _ => stateOf caller | [] => previous); active := callers)
            val () = (restore state handle e => (reset (); raise e))
            val () = active := owner :: callers
            fun leave () =
              ((saved := SOME (capture false) handle e => (reset (); raise e)); reset ())
            val result = f () handle e => (leave (); raise e)
          in leave (); result end
end
