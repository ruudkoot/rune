(* Implements: HS_CLASSES *)
structure HsClasses :> HS_CLASSES =
struct
  structure M = HsStringMap

  type class = {key : string, supers : string list, methods : string list, kind : HsTypes.kind}
  type instance = {id : string, cls : string, tycon : string, vars : int, ctx : HsTypes.pred list,
                   derived : bool, home : string}

  type env = {classes : class M.map, instances : instance M.map}

  val empty : env = {classes = M.empty, instances = M.empty}

  fun instanceId (cls, tycon) = cls ^ "@" ^ tycon

  fun showInstance id =
    case String.fields (fn c => c = #"@") id of
      [cls, tycon] => HsTypes.nameOfKey cls ^ " " ^ HsTypes.nameOfKey tycon
    | _ => id

  fun addClass ({classes, instances} : env, c : class) = {classes = M.insert (classes, #key c, c), instances = instances}
  fun addInstance ({classes, instances} : env, i : instance) = {classes = classes, instances = M.insert (instances, #id i, i)}

  fun withContext (env as {classes, instances} : env, id, ctx) =
    case M.find (instances, id) of
      SOME {id, cls, tycon, vars, derived, home, ...} =>
        {classes = classes,
         instances = M.insert (instances, id, {id = id, cls = cls, tycon = tycon, vars = vars, ctx = ctx, derived = derived,
                                               home = home})}
    | NONE => env

  fun findClass ({classes, ...} : env, k) = M.find (classes, k)
  fun findInstance ({instances, ...} : env, cls, tycon) =
    (HsUsage.read (HsUsage.Instance {cls = cls, tycon = tycon}); M.find (instances, instanceId (cls, tycon)))
  fun instances ({instances, ...} : env) = List.map #2 (M.listItems instances)
  fun classList ({classes, ...} : env) = List.map #2 (M.listItems classes)

  fun superPath (env, c, s) =
    if c = s then SOME [c]
    else
      case findClass (env, c) of
        NONE => NONE
      | SOME {supers, ...} =>
          List.foldl (fn (d, SOME p) => SOME p
                       | (d, NONE) => Option.map (fn p => c :: p) (superPath (env, d, s)))
            NONE supers

  fun superclasses (env, c) =
    let
      fun go ([], acc) = List.rev acc
        | go (d :: rest, acc) =
            if List.exists (fn x => x = d) acc then go (rest, acc)
            else go (rest @ (case findClass (env, d) of SOME {supers, ...} => supers | NONE => []), d :: acc)
    in
      go (case findClass (env, c) of SOME {supers, ...} => supers | NONE => [], [])
    end
end
