(* Implements: FOREIGN_VALIDATE *)
structure ForeignValidate : FOREIGN_VALIDATE =
struct
  type binding = {declaration : ForeignModel.declaration, policy : ForeignPolicy.functionPolicy}
  exception Error = ForeignModel.Error
  fun resolve {declarations, policy = p : ForeignPolicy.policy} =
    let
      val environment=ForeignModel.index declarations
      fun fail source message = raise Error (source, message)
      fun find namespace name = ForeignModel.lookup (environment, {family = #family p, namespace = namespace, name = name})
      fun function source name = case find "function" name of SOME d => d | NONE => fail source ("unknown selected function: " ^ name)
      fun expand source seen (ForeignModel.Attributed (base, _)) = expand source seen base
        | expand source seen (ForeignModel.Named identity) =
          let val key = ForeignModel.key identity
          in if List.exists (fn old => old = key) seen then fail source "cyclic typedef"
             else case ForeignModel.lookup (environment, identity) of SOME d => expand source (key :: seen) (#ty d)
               | NONE => fail source ("unknown foreign type: " ^ #name identity) end
        | expand _ _ ty = ty
      fun shape source ty = expand source [] ty
      fun readonly source seen (ForeignModel.Attributed (base, attributes)) =
            List.exists (fn a : ForeignModel.expression => List.exists (fn s => s = "const")
              (String.tokens Char.isSpace (#text a))) attributes orelse readonly source seen base
        | readonly source seen (ForeignModel.Named identity) =
            let val key = ForeignModel.key identity
            in if List.exists (fn old => old = key) seen then fail source "cyclic typedef"
               else case ForeignModel.lookup (environment, identity) of SOME d => readonly source (key :: seen) (#ty d)
                 | NONE => false end
        | readonly _ _ _ = false
      fun callbackType source ty = case shape source ty of ForeignModel.Pointer {target, ...} =>
            (case shape source target of ForeignModel.Callable f => SOME f | _ => NONE)
        | ForeignModel.Callable f => SOME f | _ => NONE
      fun duplicate source what values =
        let fun go [] = () | go (name :: rest) =
          if List.exists (fn old => old = name) rest then fail source ("duplicate " ^ what ^ ": " ^ name) else go rest
        in go values end
      val () = duplicate (#source p) "selection" (List.map(fn f:ForeignPolicy.functionPolicy=>ForeignModel.key{family= #family p,namespace= #namespace f,name= #foreign f})(#functions p))
      val () = duplicate (#source p) "SML member" (List.map #name (#functions p))
      val () = duplicate (#source p) "raw SML member" (List.map
        (fn f : ForeignPolicy.functionPolicy => getOpt (#raw f, ForeignPolicy.rawName (#foreign f))) (#functions p))
      val () = duplicate (#source p) "callback policy" (List.map #foreign (#callbacks p))
      val () = duplicate (#source p) "resource type" (#resources p)
      fun projection source (ForeignPolicy.Resource name) =
            if List.exists(fn known=>known=name)(#resources p) then () else fail source ("unknown resource type: " ^ name)
        | projection source (ForeignPolicy.Option item) = projection source item
        | projection source (ForeignPolicy.Vector item) = projection source item
        | projection source (ForeignPolicy.Array item) = projection source item
        | projection source (ForeignPolicy.Tuple items) = List.app (projection source) items
        | projection source (ForeignPolicy.Record fields) = List.app (projection source o #2) fields
        | projection _ _ = ()
      fun validateProjection (a : ForeignPolicy.valuePolicy) = Option.app (projection (#source a)) (#projection a)
      fun supported source behindPointer visited value =
        case value of
          ForeignModel.Scalar {family="c",name} =>
            if List.exists(fn bad=>String.isSubstring bad name)["long double","_Complex","_Imaginary","__m128","__m256","__m512","__int128","_Float128","__builtin_va_list"]
            then fail source ("unsupported selected C type: " ^ name) else ()
        | ForeignModel.Scalar {family,...} => fail source ("unsupported selected source family: " ^ family)
        | ForeignModel.Macro _ => fail source "selected macro requires an explicit typed C shim"
        | ForeignModel.BackendType {family,...} => fail source ("backend required for selected type: " ^ family)
        | ForeignModel.Named identity =>
            if List.exists(fn old=>old=ForeignModel.key identity)visited then () else
            (case ForeignModel.lookup(environment,identity) of NONE=>fail source("unknown selected type: " ^ #name identity)
             | SOME d=>supported (#source d) behindPointer (ForeignModel.key identity::visited) (#ty d))
        | ForeignModel.Attributed(base,attributes) =>
            (if List.exists(fn a:ForeignModel.expression=>String.isSubstring "vector_size" (#text a))attributes
             then fail source "selected vector ABI requires an unsupported backend" else ();
             supported source behindPointer visited base)
        | ForeignModel.Pointer{target,...} => supported source true visited target
        | ForeignModel.Array{element,...} => supported source behindPointer visited element
        | ForeignModel.Callable{result,parameters,prototype,...} =>
            (if prototype then () else fail source "selected function has no prototype";
             supported source false visited result;
             List.app(fn ForeignModel.Parameter{ty,...}=>supported source false visited ty)parameters)
        | ForeignModel.Aggregate{fields=SOME fields,...} =>
            List.app(fn ForeignModel.Field{ty,source,...}=>supported source behindPointer visited ty)fields
        | ForeignModel.Aggregate{fields=NONE,tag,...} =>
            if behindPointer then () else (case tag of NONE=>fail source "incomplete selected aggregate"
              | SOME identity=>if List.exists(fn old=>old=ForeignModel.key identity)visited then fail source "incomplete selected aggregate"
                else case ForeignModel.lookup(environment,identity) of NONE=>fail source "incomplete selected aggregate"
                  | SOME d=>supported source false (ForeignModel.key identity::visited) (#ty d))
        | ForeignModel.Enumeration _ => ()
      fun validateCallback (cb : ForeignPolicy.callbackPolicy) =
        let val declaration = case find "typedef" (#foreign cb) of SOME d => d
              | NONE => fail (#source cb) ("unknown callback typedef: " ^ #foreign cb)
            val f = case callbackType (#source cb) (#ty declaration) of SOME f => f
              | NONE => fail (#source cb) "callback annotation does not name a function pointer"
            val () = if #prototype f then () else fail (#source cb) "callback requires a prototype"
            val () = if #variadic f then fail (#source cb) "variadic callbacks are unsupported" else ()
            val () = if #lifetime cb = "registered" andalso not (isSome (#owner cb)) then
              fail (#source cb) "retained callback requires an owner" else ()
            val names = ListPair.map (fn (i, ForeignModel.Parameter {name, ...}) => getOpt (name, "arg" ^ Int.toString i))
              (List.tabulate (length (#parameters f), fn i => i), #parameters f)
            val () = case #failure cb of ForeignPolicy.ConstantFailure _ => ()
              | ForeignPolicy.ArgumentFailure {parameter, cases, ...} =>
                (if List.exists (fn name => name = parameter) names then () else fail (#source cb) "failure selector is not a callback parameter";
                 duplicate (#source cb) "callback failure case" (List.map #1 cases))
        in () end
      val () = List.app validateCallback (#callbacks p)
      fun annotation annotations name = List.find (fn a : ForeignPolicy.valuePolicy => #name a = SOME name) annotations
      fun isResource (SOME (ForeignPolicy.Resource _)) = true
        | isResource (SOME (ForeignPolicy.Option t)) = isResource (SOME t)
        | isResource _ = false
      fun stringType (SOME(ForeignPolicy.Scalar "string")) = true
        | stringType (SOME(ForeignPolicy.Option item)) = stringType(SOME item)
        | stringType _ = false
      fun pointer source unsafe result ty (annotation : ForeignPolicy.valuePolicy) =
        if unsafe then () else
        case shape source ty of
          ForeignModel.Pointer {target, ...} =>
            let val callback = callbackType source ty
                val () = if isSome (#nullable annotation) then () else fail (#source annotation) "pointer nullability is ambiguous"
                val () = if isSome callback then
                    (case #callback annotation of NONE => fail (#source annotation) "callback lifetime/thread policy is missing"
                     | SOME name => if List.exists (fn cb : ForeignPolicy.callbackPolicy => #foreign cb = name) (#callbacks p) then ()
                       else fail (#source annotation) ("unknown callback policy: " ^ name))
                  else if isSome (#ownership annotation) then () else fail (#source annotation) "pointer ownership is ambiguous"
                val () = if result orelse isSome (#direction annotation) then () else fail (#source annotation) "pointer direction is missing"
                val () = if stringType(#projection annotation) andalso not(#terminator annotation = SOME true orelse isSome(#extent annotation))
                    then fail (#source annotation) "string needs an explicit terminator or length" else ()
                val output = case #direction annotation of SOME ForeignPolicy.Out => true | SOME ForeignPolicy.InOut => true | _ => false
                val () = if output andalso readonly source [] target then fail (#source annotation) "output policy writes through a const pointer" else ()
                val scalarOutput = output andalso isSome (#output annotation) andalso
                  (case shape source target of ForeignModel.Scalar _ => true | _ => false)
                val () = if isSome callback orelse isResource (#projection annotation) orelse scalarOutput orelse isSome (#encoding annotation)
                  orelse isSome (#projection annotation) then () else fail (#source annotation) "pointer projection is ambiguous"
                val () = if not(isSome callback orelse isResource(#projection annotation) orelse scalarOutput orelse
                    isSome(#extent annotation) orelse (stringType(#projection annotation) andalso #terminator annotation=SOME true))
                  then fail (#source annotation) "pointer extent is ambiguous" else ()
                val () = if result andalso isResource(#projection annotation) andalso #ownership annotation=SOME(ForeignPolicy.Borrowed "call")
                  then fail (#source annotation) "returned resource cannot borrow a finished call arena" else ()
                val () = if output andalso not scalarOutput andalso not (isResource (#projection annotation)) andalso
                    not (isSome (#extent annotation)) then fail (#source annotation) "unbounded output buffer" else ()
            in () end
        | _ => if isSome (#callback annotation) then fail (#source annotation) "callback policy on a non-callback value" else ()
      fun one (policy : ForeignPolicy.functionPolicy) : binding =
        let val declaration = case find (#namespace policy) (#foreign policy) of SOME d=>d
              | NONE=>fail (#source policy)("unknown selected " ^ #namespace policy ^ ": " ^ #foreign policy)
            val ()=if List.exists(fn word=>word="static" orelse word="inline" orelse word="__forceinline") (#storage declaration)
              andalso not(isSome(#adapter policy)) then fail (#source policy) "selected static/inline function requires a C shim" else ()
            val () = supported (#source policy) false [] (#ty declaration)
            val () = List.app validateProjection (#result policy :: #parameters policy)
            val f = case shape (#source policy) (#ty declaration) of ForeignModel.Callable f => f
              | _ => fail (#source policy) "selection is not callable"
            val names = ListPair.map (fn (i, ForeignModel.Parameter {name, ...}) => getOpt (name, "arg" ^ Int.toString i))
              (List.tabulate (length (#parameters f), fn i => i), #parameters f)
            val annotations = #parameters policy
            val annotated = List.map (fn a : ForeignPolicy.valuePolicy => case #name a of SOME name => name
              | NONE => fail (#source a) "parameter annotation needs its foreign name") annotations
            val () = duplicate (#source policy) "parameter annotation" annotated
            val () = List.app (fn name => if List.exists (fn n => n = name) names then ()
              else fail (#source policy) ("unknown parameter annotation: " ^ name)) annotated
            val () = if #variadic f then
                if #variadic policy = "raw" andalso #unsafeRaw policy then ()
                else if isSome (#adapter policy) then () else fail (#source policy) "variadic selection requires explicit raw access or an adapter"
              else if #variadic policy = "raw" then fail (#source policy) "variadic policy on a fixed function" else ()
            fun argument (name, ForeignModel.Parameter {ty, ...}) =
              case annotation annotations name of
                SOME a => pointer (#source policy) (#unsafeRaw policy) false
                  (case shape (#source policy) ty of ForeignModel.Array{element,...}=>ForeignModel.Pointer{target=element,qualifiers=[]}
                    | other=>other) a
              | NONE => if #unsafeRaw policy then () else case shape (#source policy) ty of
                  ForeignModel.Pointer _ => fail (#source policy) ("missing pointer annotation: " ^ name)
                | ForeignModel.Array _ => fail (#source policy) ("missing decayed-array annotation: " ^ name)
                | _ => ()
            val () = ListPair.app argument (names, #parameters f)
            val () = pointer (#source policy) (#unsafeRaw policy) true (#result f) (#result policy)
            fun owned (a : ForeignPolicy.valuePolicy) = case #ownership a of
                SOME(ForeignPolicy.Owned release) =>
                  let val deallocator=function (#source a) release
                  in case shape (#source a) (#ty deallocator) of
                    ForeignModel.Callable{parameters=_::_,variadic=false,prototype=true,...}=>()
                  | _=>fail (#source a) "deallocator requires a fixed resource argument" end
              | SOME(ForeignPolicy.Borrowed scope) =>
                  if List.exists(fn known=>known=scope)["call","static","library"] orelse
                     List.exists(fn cb:ForeignPolicy.callbackPolicy=> #owner cb = SOME scope)(#callbacks p) then ()
                  else if String.isPrefix "parameter:" scope andalso List.exists(fn name=>name=String.extract(scope,10,NONE))names then ()
                  else fail (#source a)("unknown borrowed lifetime: " ^ scope)
              | NONE=>()
            val ()=List.app owned (#result policy::annotations)
            fun optional (a : ForeignPolicy.valuePolicy) result =
              case (#nullable a,#projection a) of
                (SOME false,SOME(ForeignPolicy.Option _))=>fail (#source a) "option projection contradicts non-null policy"
              | (SOME true,SOME(ForeignPolicy.Option _))=>()
              | (SOME true,SOME _)=>if result andalso #predicate(#errors policy)="null" then ()
                  else fail (#source a) "nullable value requires an option projection"
              | _=>()
            val ()=List.app(fn a=>optional a false)annotations
            val ()=optional (#result policy) true
            val ()=List.app(fn a:ForeignPolicy.valuePolicy=>if #consumes a andalso
              (#direction a <> SOME ForeignPolicy.In orelse not(isResource(#projection a)))
              then fail (#source a) "consumed value must be an input resource" else ())annotations
            val ()=if #consumes(#result policy) then fail (#source(#result policy)) "result cannot be consumed" else ()
            fun extent (a : ForeignPolicy.valuePolicy) = case #extent a of SOME (ForeignPolicy.ParameterLength name) =>
                  let val parameter = List.find(fn (n,_)=>n=name)(ListPair.zip(names,#parameters f))
                      fun integral (ForeignModel.Scalar{family="c",name}) = not(List.exists(fn word=>String.isSubstring word name)["void","float","double"])
                        | integral (ForeignModel.Enumeration _) = true
                        | integral (ForeignModel.Pointer{target,...}) = integral(shape (#source a) target)
                        | integral _ = false
                  in case parameter of NONE=>fail (#source a)("unknown buffer length parameter: " ^ name)
                     | SOME(_,ForeignModel.Parameter{ty,...})=>if integral(shape (#source a) ty) then ()
                       else fail (#source a) "buffer length parameter is not integral" end
                | _ => ()
            val () = List.app extent (#result policy :: annotations)
            val inputNames = List.filter (fn name => case annotation annotations name of
                  SOME a => #direction a <> SOME ForeignPolicy.Out | NONE => true) names
            fun leaves ForeignPolicy.Unit=[] | leaves(ForeignPolicy.Value name)=[name]
              | leaves(ForeignPolicy.Product values)=List.concat(List.map leaves values)
              | leaves(ForeignPolicy.Fields fields)=List.concat(List.map(leaves o #2)fields)
            val ()=case #input policy of NONE=>() | SOME tree=>
              if isSome(#adapter policy) then () else List.app(fn name=>
                if List.exists(fn leaf=>leaf=name)(leaves tree) orelse
                   List.exists(fn a:ForeignPolicy.valuePolicy=> #extent a=SOME(ForeignPolicy.ParameterLength name))annotations
                then () else fail (#source policy)("input projection omits native argument without an adapter: " ^ name))inputNames
            val outputNames = "$result" :: List.mapPartial (fn a : ForeignPolicy.valuePolicy =>
              case #direction a of SOME ForeignPolicy.Out => #name a | SOME ForeignPolicy.InOut => #name a | _ => NONE) annotations
            val () = case #input policy of NONE => () | SOME projection => ForeignProjection.check
              {source = #source policy, available = inputNames, projection = projection}
            val () = case #returns policy of NONE => () | SOME projection => ForeignProjection.check
              {source = #source policy, available = outputNames, projection = projection}
            val errors = #errors policy
            val () = if #capture errors = "text" andalso not (isSome (#getter errors)) then
              fail (#source policy) "text errors require an error getter" else ()
            val () = case (shape (#source policy) (#result f),#predicate errors) of
                (ForeignModel.Scalar{name="void",...},"none")=>()
              | (ForeignModel.Scalar{name="void",...},_)=>fail (#source policy) "error predicate requires a returned status"
              | (ForeignModel.Pointer _,_)=>()
              | (_,"null")=>fail (#source policy) "null failure predicate requires a pointer result"
              | _=>()
            val () = if isSome(#getter errors) andalso #capture errors<>"text" then fail (#source policy) "error getter requires text capture" else ()
            val () = case #getter errors of NONE => () | SOME name =>
              let val getter = function (#source policy) name
              in case shape (#source policy) (#ty getter) of
                ForeignModel.Callable {parameters = [], variadic = false, prototype = true, result, ...} =>
                  (case shape (#source policy) result of ForeignModel.Pointer{target,...}=>
                    (case shape (#source policy) target of ForeignModel.Scalar{name,...}=>
                      if String.isSubstring "char" name then () else fail (#source policy) "error getter must return a character string"
                    | _=>fail (#source policy) "error getter must return a character string")
                   | _=>fail (#source policy) "error getter must return a character string")
              | _ => fail (#source policy) "error getter must take no arguments" end
            val () = case #ownership (#result policy) of SOME (ForeignPolicy.Owned release) =>
                ignore (function (#source policy) release) | _ => ()
        in {declaration = declaration, policy = policy} end
    in List.map one (#functions p) end
end
