(* Mutable unification variables are private to elaboration. Generic variables
   form type schemes; instantiation copies only those variables. *)
signature TYPES =
sig
  datatype ty = TInt | TBool | TString | TUnit | TFunction of ty * ty
              | TTuple of ty list | TData of tycon * ty list | TVar of variable ref
  and variable = Unbound of int * int * bool | Link of ty | Generic of int * bool
  and tycon = TypeConstructor of {id : int, name : string, arity : int,
      equality : bool ref, constructors : int list ref}
  val root : Source.pos -> ty -> ty
  val admits : Source.pos -> ty -> bool
  val noEscape : Source.pos -> int -> ty -> unit
  val reset : unit -> unit
  val fresh : Source.pos -> int -> ty
  val unify : Source.pos -> ty -> ty -> unit
  val equality : Source.pos -> ty -> unit
  val generalize : Source.pos -> int -> bool -> ty -> unit
  val instantiate : Source.pos -> int -> ty -> ty
end
structure Types :> TYPES =
struct
  datatype ty = TInt | TBool | TString | TUnit | TFunction of ty * ty
              | TTuple of ty list | TData of tycon * ty list | TVar of variable ref
  and variable = Unbound of int * int * bool | Link of ty | Generic of int * bool
  and tycon = TypeConstructor of {id : int, name : string, arity : int,
      equality : bool ref, constructors : int list ref}
  val next = ref 0
  val work = ref 0
  fun reset () = (next := 0; work := 0)
  fun tick p = (work := !work+1; if !work > 1000000 then
      Source.fail p "limit" "type inference exceeds 1000000 steps" else ())
  fun fresh p level =
    if !next >= Source.maxCount then Source.fail p "limit" "too many type variables"
    else let val id = !next in next := id+1; TVar (ref (Unbound (id,level,false))) end
  fun root p (TVar r) = (tick p; case !r of Link t =>
        let val t' = root p t in r := Link t'; t' end | _ => TVar r)
    | root p t = (tick p; t)
  fun shape TInt = "int" | shape TBool = "bool" | shape TString = "string"
    | shape TUnit = "unit" | shape (TFunction _) = "function"
    | shape (TTuple _) = "tuple" | shape (TVar _) = "type variable"
    | shape (TData (TypeConstructor {name,...},_)) = name
  fun equality p t = case root p t of
      TFunction _ => Source.fail p "type" "functions do not admit equality"
    | TTuple ts => List.app (equality p) ts
    | TData (TypeConstructor {equality=eq,...},ts) =>
        if !eq then List.app (equality p) ts
        else Source.fail p "type" "datatype does not admit equality"
    | TVar r => (case !r of Unbound (id,lev,_) => r := Unbound (id,lev,true)
                  | _ => Source.fail p "internal" "unexpected type scheme in equality")
    | _ => ()
  (* With parameters assumed equal, compute the greatest equality solution. *)
  fun admits p t = case root p t of
      TFunction _ => false | TTuple ts => List.all (admits p) ts
    | TData (TypeConstructor {equality=eq,...},ts) => !eq andalso List.all (admits p) ts
    | _ => true
  fun noEscape p first t = case root p t of
      TData (TypeConstructor {id,...},ts) =>
        if id >= first then Source.fail p "type" "local datatype escapes its scope"
        else List.app (noEscape p first) ts
    | TFunction (a,b) => (noEscape p first a; noEscape p first b)
    | TTuple ts => List.app (noEscape p first) ts
    | _ => ()
  (* Occurs checking also lowers levels of escaping variables. This prevents
     generalization of variables shared with a surrounding lexical scope. *)
  fun occurs p id level t = case root p t of
      TVar r => (case !r of Unbound (other,lev,eq) =>
          if id = other then Source.fail p "type" "infinite type (occurs check)"
          else if lev > level then r := Unbound (other,level,eq) else ()
        | _ => Source.fail p "internal" "unexpected type scheme in unification")
    | TFunction (a,b) => (occurs p id level a; occurs p id level b)
    | TTuple ts => List.app (occurs p id level) ts
    | TData (_,ts) => List.app (occurs p id level) ts
    | _ => ()
  fun unify p left right =
    let val leftRoot = root p left val rightRoot = root p right
        fun bind r t = case !r of
            Unbound (id,level,eq) => (occurs p id level t;
                if eq then equality p t else (); r := Link t)
          | _ => Source.fail p "internal" "cannot unify a type scheme"
    in case (leftRoot,rightRoot) of
        (TVar r,TVar s) => if r = s then () else bind r rightRoot
      | (TVar r,_) => bind r rightRoot | (_,TVar r) => bind r leftRoot
      | (TInt,TInt) => () | (TBool,TBool) => () | (TString,TString) => () | (TUnit,TUnit) => ()
      | (TFunction (leftArg,leftResult),TFunction (rightArg,rightResult)) =>
          (unify p leftArg rightArg; unify p leftResult rightResult)
      | (TData (TypeConstructor {id=x,...},xs),TData (TypeConstructor {id=y,...},ys)) =>
          if x <> y then Source.fail p "type" "distinct datatype identities"
          else ListPair.app (fn (a,b) => unify p a b) (xs,ys)
      | (TTuple xs,TTuple ys) => if List.length xs <> List.length ys then
          Source.fail p "type" "tuple arities differ"
          else ListPair.app (fn (x,y) => unify p x y) (xs,ys)
      | _ => Source.fail p "type" ("expected " ^ shape leftRoot ^ ", got " ^ shape rightRoot)
    end
  fun generalize p level eligible t = case root p t of
      TVar r => (case !r of Unbound (id,lev,eq) =>
          if lev > level then r := (if eligible then Generic (id,eq) else Unbound (id,level,eq)) else ()
        | _ => ())
    | TFunction (a,b) => (generalize p level eligible a; generalize p level eligible b)
    | TTuple ts => List.app (generalize p level eligible) ts
    | TData (_,ts) => List.app (generalize p level eligible) ts
    | _ => ()
  fun instantiate p level scheme =
    let val copies = ref ([] : (int * ty) list)
        fun copy t = case root p t of
            TVar r => (case !r of Generic (id,eq) =>
                (case List.find (fn (n,_) => n = id) (!copies) of SOME (_,v) => v
                 | NONE => let val v = fresh p level
                               val () = if eq then equality p v else ()
                           in copies := (id,v):: !copies; v end)
              | _ => TVar r)
          | TFunction (a,b) => let val a' = copy a val b' = copy b in TFunction (a',b') end
          | TTuple ts => TTuple (List.map copy ts)
          | TData (tc,ts) => TData (tc,List.map copy ts)
          | resolved => resolved
    in copy scheme end
end
