(* Implements: HS_CLASSES *)
structure HsClasses :> HS_CLASSES =
struct
  structure M = HsStringMap

  type class = {key : string, supers : string list, methods : string list, kind : HsTypes.kind, defaults : string list}
  type instance = {id : string, cls : string, tycon : string, vars : int, ctx : HsTypes.pred list,
                   derived : bool, home : string}

  (* with the instances' identities by their modules: what a unit finds
     of its own, beside the instances of every unit before it
     (build-cache-issues.md, issue 39) *)
  type env = {classes : class M.map, instances : instance M.map, byHome : unit M.map M.map}

  val empty : env = {classes = M.empty, instances = M.empty, byHome = M.empty}

  fun instanceId (cls, tycon) = cls ^ "@" ^ tycon

  fun showInstance id =
    case String.fields (fn c => c = #"@") id of
      [cls, tycon] => HsTypes.nameOfKey cls ^ " " ^ HsTypes.nameOfKey tycon
    | _ => id

  fun addClass ({classes, instances, byHome} : env, c : class) =
    {classes = M.insert (classes, #key c, c), instances = instances, byHome = byHome}
  fun addInstance ({classes, instances, byHome} : env, i : instance) =
    {classes = classes, instances = M.insert (instances, #id i, i),
     byHome = M.insert (byHome, #home i, M.insert (getOpt (M.find (byHome, #home i), M.empty), #id i, ()))}

  fun withContext (env as {classes, instances, byHome} : env, id, ctx) =
    case M.find (instances, id) of
      SOME {id, cls, tycon, vars, derived, home, ...} =>
        {classes = classes,
         instances = M.insert (instances, id, {id = id, cls = cls, tycon = tycon, vars = vars, ctx = ctx, derived = derived,
                                               home = home}),
         byHome = byHome}
    | NONE => env

  fun findClass ({classes, ...} : env, k) = M.find (classes, k)
  fun findInstance ({instances, ...} : env, cls, tycon) =
    (HsUsage.read (HsUsage.Instance {cls = cls, tycon = tycon}); M.find (instances, instanceId (cls, tycon)))
  fun instances ({instances, ...} : env) = List.map #2 (M.listItems instances)
  fun instanceById ({instances, ...} : env, id) = M.find (instances, id)
  fun instancesOf ({instances, byHome, ...} : env, homes : string list) =
    let
      val ids = List.foldl (fn (h, s) => case M.find (byHome, h) of
                                           SOME is => M.foldl (fn (k, (), s) => M.insert (s, k, ())) s is
                                         | NONE => s)
                  M.empty homes
    in
      List.rev (M.foldl (fn (k, (), acc) => case M.find (instances, k) of SOME i => i :: acc | NONE => acc) [] ids)
    end
  fun classList ({classes, ...} : env) = List.map #2 (M.listItems classes)
  fun classesAt ({classes, ...} : env, prefixes : string list) =
    List.rev (List.foldl (fn (p, acc) => M.foldPrefix (fn (_, c, acc) => c :: acc) acc (classes, p)) [] prefixes)

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
