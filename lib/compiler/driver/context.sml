(* Visibility for scoped builds, shared by batch compilation and static
   analysis. These records switch visibility; they do not undo unification. *)
structure CompilerBuildContext =
struct
  type exports=(BuildFile.kind*string) list
  type snapshot={env:Env.env,fixity:Fixity.env,sigs:SigMatch.sigma StringMap.map,
    funs:Elaborate.funinfo StringMap.map,binders:string StringMap.map,declared:int,bound:int}
  type delta={env:Env.env,directives:(string*Fixity.fixity) list,declared:(string*string) list,
    bound:string list,sigs:SigMatch.sigma StringMap.map,funs:Elaborate.funinfo StringMap.map,binders:string StringMap.map}
  (* A build file used: what it declared, the boundaries around its first use
     that are open, and the exports of those that have closed, which is what
     a later use outside them sees of it (replay) *)
  type used={file:string,change:delta,within:int list,through:exports list}
  (* boundaries: the open ones, the innermost first *)
  type t={env:Env.env ref,fixity:Fixity.env ref,declared:(string*string) list ref,boundaries:int list ref,
    next:int ref,used:used list ref}
  fun new (env,fixity):t={env=env,fixity=fixity,declared=ref [],boundaries=ref [],next=ref 0,used=ref []}
  fun noteNames ({declared,...}:t,funs,sigs)=
    declared:=List.map (fn n => ("fun",n)) funs @ List.map (fn n => ("sig",n)) sigs @ !declared
  fun note (t,result:UnitBasis.result)=noteNames (t,#funs result,#sigs result)
  fun snap ({env,fixity,declared,...}:t):snapshot={env= !env,fixity= !fixity,sigs= !Elaborate.sigs,funs= !Elaborate.funs,
    binders= !UnitBasis.binders,declared=length (!declared),bound=length (!UnitBasis.bindLog)}
  fun delta ({declared,...}:t,before':snapshot,after:snapshot):delta=
    {env=UnitBasis.envDelta (#env before',#env after),
     directives=List.take (#list (#fixity after),length (#list (#fixity after))-length (#list (#fixity before'))),
     declared=List.rev (List.take (!declared,length (!declared)- #declared before')),
     bound=List.rev (List.take (!UnitBasis.bindLog,length (!UnitBasis.bindLog)- #bound before')),
     sigs= #sigs after,funs= #funs after,binders= #binders after}
  fun apply ({env,fixity,...}:t,before':snapshot,change:delta,exports) =
    let fun visible (kind,name)=case exports of NONE => true | SOME values => List.exists (fn value => value=(kind,name)) values
        val Env.Env {vals,tys,strs,...}= #env change
        val exported=Env.make {origins=Env.origins (#env change),vals=if isSome exports then StringMap.empty else vals,
          tys=StringMap.filteri (fn (n,_) => visible (BuildFile.Ty,n)) tys,
          strs=StringMap.filteri (fn (n,_) => visible (BuildFile.Str,n)) strs}
        fun keyVisible key=case String.fields (fn c => c= #" ") key of
          ["s",name] => visible (BuildFile.Str,name) | ["t",name] => visible (BuildFile.Ty,name)
        | ["sig",name] => visible (BuildFile.Sig,name) | ["fun",name] => visible (BuildFile.Fun,name)
        | ["fix",name] => visible (BuildFile.Fix,name)
        | _ => not (isSome exports)
        fun named (kind,map,base)=List.foldl (fn ((k,n),base) =>
          if k=kind andalso visible ((if kind="sig" then BuildFile.Sig else BuildFile.Fun),n) then
            (case StringMap.find (map,n) of SOME value => StringMap.insert (base,n,value) | NONE => base) else base) base (#declared change)
    in env:=Env.plus (#env before',exported);
       fixity:=Fixity.extend (#fixity before',List.filter (fn (n,_) => visible (BuildFile.Fix,n)) (#directives change));
       Elaborate.sigs:=named ("sig",#sigs change,#sigs before');
       Elaborate.funs:=named ("fun",#funs change,#funs before');
       UnitBasis.binders:=List.foldl (fn (key,base) => if keyVisible key then
         (case StringMap.find (#binders change,key) of SOME id => StringMap.insert (base,key,id) | NONE => base) else base)
         (#binders before') (#bound change)
    end

  fun restore ({env,fixity,...}:t,b:snapshot)=
    (env:= #env b;fixity:= #fixity b;Elaborate.sigs:= #sigs b;Elaborate.funs:= #funs b;UnitBasis.binders:= #binders b)

  (* a library's boundary as what the libraries' walk reads it as *)
  fun exportsOf (exports:LibraryScope.exports):exports=
    List.map (fn (kind,name) => ((case kind of "structure" => BuildFile.Str | "signature" => BuildFile.Sig
                                             | "functor" => BuildFile.Fun | "type" => BuildFile.Ty | _ => BuildFile.Fix),name)) exports
  (* this context as LibraryScope's walk goes through it *)
  fun site (t:t):(snapshot,delta) LibraryScope.site=
    {get=fn () => snap t,set=fn b => restore (t,b),change=fn (b,a,_) => delta (t,b,a),
     add=fn (onto,change,filter) => (apply (t,onto,change,Option.map exportsOf filter);snap t)}

  (* ---- boundaries, and what a second use sees through them (docs/build.md,
     D8) ---- *)

  fun enter ({boundaries,next,...}:t):int =
    let val id= !next in next:=id+1;boundaries:=id :: !boundaries;id end
  (* out of the first part of a `local`: a use first seen in the second part
     is not behind it, and one first seen in the first part is still seen *)
  fun pause ({boundaries,...}:t,id:int)=boundaries:=List.filter (fn other => other<>id) (!boundaries)
  (* the boundary over: a build file first used inside it is seen outside it
     through its exports *)
  fun leave (t as {used,...}:t,id:int,exports)=
    (pause (t,id);
     used:=List.map (fn u as {file,change,within,through} =>
       if List.exists (fn other => other=id) within
       then {file=file,change=change,within=List.filter (fn other => other<>id) within,through=exports :: through}
       else u) (!used))
  (* A build file with a boundary of its own is seen as that boundary shows
     it, by every `use` of it: the boundaries around its first use are the
     first user's business, and a library that shares it with another would
     otherwise see what depends on which came first. Only one without leans on
     the boundary around it to hide what it declares. *)
  fun record ({used,boundaries,...}:t,file,change,steps)=
    used:={file=file,change=change,within=if CompilerProject.bounded steps then [] else !boundaries,through=[]} :: !used
  (* a build file used again: what its first use declared, through the
     boundaries that have closed around that use; false where it is the first *)
  fun replay (t as {used,...}:t,file) : bool =
    case List.find (fn u:used => #file u=file) (!used) of
      NONE => false
    | SOME {change,through,...} =>
        let val exports=case through of
              [] => NONE
            | first :: rest => SOME (List.foldl (fn (more,kept) =>
                List.filter (fn e => List.exists (fn x => x=e) more) kept) first rest)
        in apply (t,snap t,change,exports);true end

  (* what is wrong with a boundary's exports, if anything, change being what
     its inside declared. An export names what its inside sees: what it
     declares, or what was in scope before it, which stays so. And `type` is a
     type abbreviation's, as --basis-index asks: through a datatype's it would
     lend its constructors to a replication, which the boundary hides *)
  fun exportProblem ({env,...}:t,change:delta,exports:exports) : string option =
    let
      fun kindName k=case k of BuildFile.Str => "structure" | BuildFile.Sig => "signature"
                             | BuildFile.Fun => "functor" | BuildFile.Ty => "type" | BuildFile.Fix => "fixity"
      fun inScope (kind,name)=
        case kind of
          BuildFile.Str => StringMap.member (Env.strs (!env),name)
        | BuildFile.Ty => StringMap.member (Env.tys (!env),name)
        | BuildFile.Sig => StringMap.member (!Elaborate.sigs,name)
        | BuildFile.Fun => StringMap.member (!Elaborate.funs,name)
        | BuildFile.Fix => List.exists (fn (n,_) => n=name) (#directives change)
      fun problem (kind,name)=
        if not (inScope (kind,name))
        then SOME ("a library exports " ^ kindName kind ^ " " ^ name ^ ", and nothing of that name is in scope")
        else
          case (kind,StringMap.find (Env.tys (#env change),name)) of
            (BuildFile.Ty,SOME (Env.TyStr {cons=_ :: _,...})) =>
              SOME ("a library exports type " ^ name ^ ", which is a datatype: a `type` export is a type abbreviation's")
          | _ => NONE
    in List.foldl (fn (e,found) => case found of SOME _ => found | NONE => problem e) NONE exports end
end
