(* Implements: C_DECLARATOR *)
structure CDeclarator : C_DECLARATOR =
struct
  exception Error of string
  fun identifier name=if size name>0 andalso
      (Char.isAlpha(String.sub(name,0)) orelse Char.contains "_$"(String.sub(name,0))) andalso
      CharVector.all(fn c=>Char.isAlphaNum c orelse Char.contains "_$" c)name
    then () else raise Error("invalid C identifier: " ^ name)
  fun words tokens=String.concatWith " "(List.map(fn(t:CLex.token)=> #text t)tokens)
  fun unwrap(CParse.Attributed(ty,_))=unwrap ty | unwrap ty=ty
  fun declaration(ty,name)=
    let val ()=identifier name
        fun combine(base,"")=base | combine(base,name)=base ^ " " ^ name
        fun render(CParse.Builtin base,name)=combine(CType.canonical base,name)
          | render(CParse.Named base,name)=(identifier base;combine(base,name))
          | render(CParse.Pointer{target,qualifiers},name)=
              let val pointer="*" ^ (if null qualifiers then "" else String.concatWith " " qualifiers ^ " ") ^ name
                  val indirect=case unwrap target of CParse.Function _=>true | CParse.Array _=>true | _=>false
              in render(target,if indirect then "(" ^ pointer ^ ")" else pointer) end
          | render(CParse.Array{element,bound},name)=render(element,name ^ "[" ^ words bound ^ "]")
          | render(CParse.Function{result,parameters,variadic,prototype},name)=
              let fun parameter(CParse.Parameter{ctype,name})=render(ctype,case name of NONE=>"" | SOME name=>(identifier name;name))
                  val args=List.map parameter parameters
                  val args=if variadic then if null args then raise Error "C varargs require a fixed argument" else args @ ["..."]
                    else if null args andalso prototype then ["void"] else args
              in render(result,name ^ "(" ^ String.concatWith ", " args ^ ")") end
          | render(CParse.Record{kind,tag=SOME tag,...},name)=
              (identifier tag;combine((case kind of CParse.Struct=>"struct " | CParse.Union=>"union ") ^ tag,name))
          | render(CParse.Enum{tag=SOME tag,...},name)=(identifier tag;combine("enum " ^ tag,name))
          | render(CParse.Attributed(ty,attributes),name)=
              String.concatWith " "(List.map words attributes) ^ " " ^ render(ty,name)
          | render _=raise Error "anonymous aggregate/enum requires an original named alias"
    in render(ty,name) end
end
