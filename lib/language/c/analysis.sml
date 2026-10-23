(* Implements: C_ANALYSIS *)
structure CAnalysis :> C_ANALYSIS =
struct
  datatype enumRule=SignedEnums | UnsignedNonnegative
  type target={integers:CInteger.target,objects:CLayout.target,charSigned:bool,sizeType:CInteger.integerType,enumRule:enumRule}
  type source=CLex.location
  datatype definition=Initial | Successor of string | Expression of CLex.token list
  type namedType={ty:CParse.ctype,source:source}
  type enumerator={name:string,definition:definition,source:source,order:int}
  type environment={target:target,types:(string*namedType list)list Array.array,
    enums:(string*enumerator list)list Array.array,objects:(string*CParse.ctype)list Array.array,
    typedefs:string list,memo:(string*CInteger.value)list ref}
  exception Error of source*string
  val nowhere={file="<C analysis>",line=1,column=1}
  fun hash name=CharVector.foldl(fn(c,n)=>(n*33+Char.ord c) mod 4093)0 name
  fun get table name=case List.find(fn(n,_)=>n=name)(Array.sub(table,hash name)) of SOME(_,value)=>SOME value | NONE=>NONE
  fun put table name value=let val bucket=hash name
    in Array.update(table,bucket,(name,value)::List.filter(fn(n,_)=>n<>name)(Array.sub(table,bucket))) end
  fun key namespace name=namespace ^ ":" ^ name
  fun tokens ts=CLex.scan{file="<type comparison>",text=String.concatWith " "(List.map(fn(t:CLex.token)=> #text t)ts)}
  fun normal(CParse.Builtin name)=CParse.Builtin(CType.canonical name)
    | normal(CParse.Pointer{target,qualifiers})=CParse.Pointer{target=normal target,qualifiers=qualifiers}
    | normal(CParse.Array{element,bound})=CParse.Array{element=normal element,bound=tokens bound}
    | normal(CParse.Function{result,parameters,variadic,prototype})=CParse.Function{result=normal result,
        parameters=List.map(fn CParse.Parameter{ctype,...}=>CParse.Parameter{name=NONE,ctype=normal ctype})parameters,
        variadic=variadic,prototype=prototype}
    | normal(CParse.Attributed(ty,attributes))=CParse.Attributed(normal ty,List.map tokens attributes)
    | normal(CParse.Record{kind,tag,fields,pack})=CParse.Record{kind=kind,tag=tag,pack=pack,
        fields=Option.map(List.map(fn CParse.Field{name,ctype,bits,...}=>CParse.Field{name=name,ctype=normal ctype,bits=tokens bits,location=nowhere}))fields}
    | normal(CParse.Enum{tag,values})=CParse.Enum{tag=tag,values=Option.map(List.map(fn(n,ts)=>(n,tokens ts)))values}
    | normal ty=ty
  fun create{target,declarations} : environment =
    let val types=Array.array(4093,[]) val enums=Array.array(4093,[]) val objects=Array.array(4093,[])
        val typedefs=ref [] val serial=ref 0
        fun addType namespace name ty source=
          let val id=key namespace name val old=getOpt(get types id,[])
          in if List.exists(fn({ty=known,source=at}:namedType)=>known=ty andalso source=at)old then ()
             else put types id ({ty=ty,source=source}::old) end
        fun addEnum name definition source=
          let val old=getOpt(get enums name,[])
          in if List.exists(fn(e:enumerator)=> #definition e=definition andalso #source e=source)old then ()
             else (serial:= !serial+1;put enums name ({name=name,definition=definition,source=source,order= !serial}::old)) end
        fun collectAttrs source attributes (CParse.Attributed(ty,more))=collectAttrs source (attributes @ more) ty
          | collectAttrs source _ (CParse.Pointer{target,...})=collectAttrs source [] target
          | collectAttrs source _ (CParse.Array{element,...})=collectAttrs source [] element
          | collectAttrs source _ (CParse.Function{result,...})=collectAttrs source [] result
          | collectAttrs source attributes (ty as CParse.Record{kind,tag,fields,...})=
              (case tag of NONE=>() | SOME tag=>addType(case kind of CParse.Struct=>"struct" | CParse.Union=>"union")tag (decorate ty attributes) source;
               case fields of NONE=>() | SOME fields=>List.app(fn CParse.Field{ctype,location,...}=>collectAttrs location [] ctype)fields)
          | collectAttrs source attributes (ty as CParse.Enum{tag,values})=
              (case tag of NONE=>() | SOME tag=>addType "enum" tag (decorate ty attributes) source;
               case values of NONE=>() | SOME values=>
                 let fun loop([],_) = () | loop((name,ts)::rest,previous)=
                       (addEnum name (if not(null ts) then Expression ts else case previous of NONE=>Initial | SOME p=>Successor p) source;
                        loop(rest,SOME name))
                 in loop(values,NONE) end)
          | collectAttrs _ _ _=()
        and decorate ty []=ty | decorate ty attributes=CParse.Attributed(ty,attributes)
        fun declaration(CParse.Declaration{name,ctype,storage,location,...})=
              (collectAttrs location [] ctype;case name of NONE=>() | SOME name=>
                if List.exists(fn s=>s="typedef")storage then
                  (addType "typedef" name ctype location;typedefs:=name:: !typedefs)
                else put objects name ctype)
          | declaration _=()
        val ()=List.app declaration declarations
    in {target=target,types=types,enums=enums,objects=objects,typedefs= !typedefs,memo=ref []} end
  fun incomplete(CParse.Attributed(ty,_))=incomplete ty
    | incomplete(CParse.Record{fields=NONE,...})=true | incomplete(CParse.Enum{values=NONE,...})=true | incomplete _=false
  fun lookup(e:environment){namespace,name}=
    case get(#types e)(key namespace name) of NONE=>NONE | SOME []=>NONE | SOME entries=>
      let val complete=List.filter(fn(entry:namedType)=>not(incomplete(#ty entry)))entries
          val selected=if null complete then entries else complete
          val first=hd selected
      in if List.all(fn(entry:namedType)=>normal(#ty entry)=normal(#ty first))selected then SOME(#ty first)
         else raise Error(#source first,"ambiguous C " ^ namespace ^ ": " ^ name) end
  fun resolve e ty=
    let fun walk seen(CParse.Attributed(ty,_))=walk seen ty
          | walk seen(CParse.Named name)=if List.exists(fn n=>n=name)seen then raise Error(nowhere,"cyclic C typedef: " ^ name)
            else(case lookup e {namespace="typedef",name=name} of NONE=>raise Error(nowhere,"unknown C typedef: " ^ name) | SOME ty=>walk(name::seen)ty)
          | walk _ ty=ty
    in walk [] ty end
  fun enumDefinition(e:environment) name=case get(#enums e)name of NONE=>NONE | SOME []=>NONE
    | SOME(first::rest)=>if List.all(fn(d:enumerator)=> #definition d= #definition first andalso #source d= #source first)rest
      then SOME first else raise Error(#source first,"ambiguous C enumerator: " ^ name)
  fun integerAt(e:environment) active ty=
    let val{integers,charSigned,enumRule,...}= #target e
        fun walk seen (CParse.Attributed(ty,attributes))=
              if null(CType.layoutAttributes attributes) then walk seen ty
              else raise CLayout.Shim(nowhere,"integer representation attributes require a native adapter")
          | walk seen(CParse.Named name)=if List.exists(fn n=>n=name)seen then raise Error(nowhere,"cyclic C typedef: " ^ name)
              else(case lookup e {namespace="typedef",name=name} of NONE=>raise Error(nowhere,"unknown C typedef: " ^ name)
                | SOME ty=>walk(name::seen)ty)
          | walk seen(CParse.Enum{tag,values=NONE})=
              (case tag of NONE=>raise Error(nowhere,"incomplete C enum") | SOME tag=>
                if List.exists(fn n=>n="enum:" ^ tag)seen then raise Error(nowhere,"incomplete C enum: " ^ tag) else
                (case lookup e {namespace="enum",name=tag} of SOME ty=>walk(("enum:" ^ tag)::seen)ty
                 | _=>raise Error(nowhere,"incomplete C enum: " ^ tag)))
          | walk _ (CParse.Enum{values=SOME values,...})=
              let val values=List.map(fn(name,_)=>enumValue e active name)values
                  val signed=enumRule=SignedEnums orelse List.exists(fn(v:CInteger.value)=> #integer v<0)values
              in SOME(CInteger.integerType integers CInteger.Int signed) end
          | walk _ ty=CType.integer{target=integers,charSigned=charSigned,ty=ty}
    in walk [] ty end
  and evaluate(e:environment) visible active ts=
    let val{integers,sizeType,...}= #target e
        fun lookupValue name=case enumDefinition e name of
            SOME definition=>if (case visible of NONE=>false | SOME order=> #order definition>=order) then NONE else
              let val value=enumValue e active name in SOME{ty=CParse.Builtin(CType.spelling(#ty value)),value=SOME(#integer value)} end
          | NONE=>Option.map(fn ty=>{ty=ty,value=NONE})(get(#objects e)name)
        fun measure ty=let val layout=layoutAt e active {ty=ty,source=case ts of []=>nowhere | t::_=> #location t}
          in {size=CLayout.size layout,alignment=CLayout.alignment layout} end
    in CExpression.evaluate{target=integers,sizeType=sizeType,tokens=ts,lookup=lookupValue,
      resolveType=fn ts=>CType.parse{tokens=ts,typedefs= #typedefs e},integerType=integerAt e active,measure=measure} end
  and enumValue(e:environment) active name=
    if List.exists(fn n=>n=name)active then raise Error(nowhere,"cyclic C enumerator: " ^ name) else
    case List.find(fn(n,_)=>n=name)(!(#memo e)) of SOME(_,value)=>value | NONE=>
      (case enumDefinition e name of NONE=>raise Error(nowhere,"unknown C enumerator: " ^ name)
       | SOME definition=>
         let val ty=CInteger.integerType(#integers(#target e))CInteger.Int true
             val value=case #definition definition of Initial=>{integer=0,ty=ty}
               | Successor previous=>let val previous=enumValue e (name::active)previous in {integer=IntInf.+(#integer previous,1),ty=ty} end
               | Expression ts=>evaluate e (SOME(#order definition))(name::active)ts
             val(lo,hi)=CInteger.limits ty val n= #integer value
             val ()=if n<lo orelse n>hi then raise Error(#source definition,"extended C enumerator representation requires a native adapter") else ()
             val value={integer=n,ty=ty}
             val ()= #memo e:=(name,value):: !(#memo e)
         in value end)
  and layoutAt(e:environment) active {ty,source}=
    let fun check seen ty=case ty of
          CParse.Attributed(ty,_)=>check seen ty
        | CParse.Named name=>if List.exists(fn n=>n="typedef:" ^ name)seen then () else
            (case lookup e {namespace="typedef",name=name} of NONE=>() | SOME ty=>check(("typedef:" ^ name)::seen)ty)
        | CParse.Enum _=>ignore(integerAt e active ty)
        | CParse.Array{element,...}=>check seen element
        | CParse.Record{kind,tag,fields=NONE,...}=>
            (case tag of NONE=>() | SOME tag=>let val namespace=case kind of CParse.Struct=>"struct" | CParse.Union=>"union"
                  val id=key namespace tag
                in if List.exists(fn n=>n=id)seen then () else
                  case lookup e {namespace=namespace,name=tag} of NONE=>() | SOME ty=>check(id::seen)ty end)
        | CParse.Record{fields=SOME fields,...}=>List.app(fn CParse.Field{ctype,...}=>check seen ctype)fields
        | _=>()
        val ()=check [] ty
    in CLayout.compute{target= #objects(#target e),source=source,ty=ty,lookup=lookup e,
      constant=fn ts=> #integer(evaluate e NONE active ts)} end
  fun integer e ty=integerAt e []ty
    handle CExpression.Error p=>raise Error p | CLayout.Error p=>raise Error p
  fun expression e ts=evaluate e NONE []ts
    handle CExpression.Error p=>raise Error p | CLayout.Error p=>raise Error p
  fun enumerator e name=enumValue e []name
    handle CExpression.Error p=>raise Error p | CLayout.Error p=>raise Error p
  fun layout e input=layoutAt e []input
    handle CExpression.Error p=>raise Error p | CLayout.Error p=>raise Error p
end
