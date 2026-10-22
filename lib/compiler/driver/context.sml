(* Visibility for scoped builds, shared by batch compilation and static
   analysis. These records switch visibility; they do not undo unification. *)
structure CompilerBuildContext =
struct
  type t={env:Env.env ref,fixity:Fixity.env ref,declared:(string*string) list ref}
  type snapshot={env:Env.env,fixity:Fixity.env,sigs:SigMatch.sigma StringMap.map,
    funs:Elaborate.funinfo StringMap.map,binders:string StringMap.map,declared:int,bound:int}
  type delta={env:Env.env,directives:(string*Fixity.fixity) list,declared:(string*string) list,
    bound:string list,sigs:SigMatch.sigma StringMap.map,funs:Elaborate.funinfo StringMap.map,binders:string StringMap.map}
  fun new (env,fixity):t={env=env,fixity=fixity,declared=ref []}
  fun note ({declared,...}:t,result:UnitBasis.result)=
    declared:=List.map (fn n => ("fun",n)) (#funs result) @ List.map (fn n => ("sig",n)) (#sigs result) @ !declared
  fun snap ({env,fixity,declared}:t):snapshot={env= !env,fixity= !fixity,sigs= !Elaborate.sigs,funs= !Elaborate.funs,
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
        | _ => not (isSome exports)
        fun named (kind,map,base)=List.foldl (fn ((k,n),base) =>
          if k=kind andalso visible ((if kind="sig" then BuildFile.Sig else BuildFile.Fun),n) then
            (case StringMap.find (map,n) of SOME value => StringMap.insert (base,n,value) | NONE => base) else base) base (#declared change)
    in env:=Env.plus (#env before',exported);
       fixity:=Fixity.extend (#fixity before',if isSome exports then [] else #directives change);
       Elaborate.sigs:=named ("sig",#sigs change,#sigs before');
       Elaborate.funs:=named ("fun",#funs change,#funs before');
       UnitBasis.binders:=List.foldl (fn (key,base) => if keyVisible key then
         (case StringMap.find (#binders change,key) of SOME id => StringMap.insert (base,key,id) | NONE => base) else base)
         (#binders before') (#bound change)
    end
end
