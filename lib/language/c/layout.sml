(* Implements: C_LAYOUT *)
structure CLayout : C_LAYOUT =
struct
  type source = CLex.location
  type scalar = {size : int, alignment : int, signed : bool option}
  type target = {name : string, pointer : scalar, enumeration : scalar,
    scalars : (string * scalar) list, maximumObject : IntInf.int}
  datatype layout = Atom of {size : IntInf.int, alignment : int}
    | Sequence of {size : IntInf.int, alignment : int, count : IntInf.int, element : layout}
    | Aggregate of {size : IntInf.int, alignment : int, union : bool, packed : bool, fields : field list}
  and field = FieldLayout of {name : string option, offset : IntInf.int, layout : layout, source : source}
  exception Error of source * string
  exception Shim of source * string
  fun size (Atom {size,...})=size | size(Sequence{size,...})=size | size(Aggregate{size,...})=size
  fun alignment(Atom{alignment,...})=alignment | alignment(Sequence{alignment,...})=alignment
    | alignment(Aggregate{alignment,...})=alignment
  fun round(value,alignment)=
    let val a=IntInf.fromInt alignment in IntInf.*(IntInf.div(IntInf.+(value,IntInf.-(a,1)),a),a) end
  fun compute {target=t:target,source,ty,lookup,constant} =
    let fun fail source message=raise Error(source,message)
        fun bounded source n=if n<0 orelse n> #maximumObject t then fail source "C object size exceeds the target limit" else n
        fun power n = n=1 orelse (n>1 andalso n mod 2=0 andalso power(n div 2))
        fun atom source ({size,alignment,...}:scalar)=
          if size<=0 orelse not(power alignment) then fail source "invalid target scalar layout"
          else Atom{size=bounded source(IntInf.fromInt size),alignment=alignment}
        fun find source namespace name seen flexible =
          let val identity=namespace ^ ":" ^ name
          in if List.exists(fn old=>old=identity)seen then fail source("cyclic C layout: " ^ name)
             else case lookup{namespace=namespace,name=name} of
               NONE=>fail source("incomplete C type: " ^ name)
             | SOME ty=>walk source (identity::seen) flexible ty end
        and walk source seen flexible ty = case ty of
          CParse.Builtin "void"=>fail source "void has no C object layout"
        | CParse.Builtin name=>(case List.find(fn(known,_)=>known=CType.canonical name)(#scalars t) of
              SOME(_,scalar)=>atom source scalar | NONE=>raise Shim(source,"unsupported C scalar layout: " ^ name))
        | CParse.Named name=>find source "typedef" name seen flexible
        | CParse.Pointer{qualifiers,...}=>
            if List.exists(fn name=>name="__ptr32" orelse name="__ptr64" orelse name="__unaligned")qualifiers
            then raise Shim(source,"qualified pointer representation requires a verified adapter")
            else atom source (#pointer t)
        | CParse.Function _=>fail source "a function has no object layout"
        | CParse.Enum _=>atom source (#enumeration t)
        | CParse.Attributed(base,attributes)=>
            let val words=List.concat(List.map(List.map #text)attributes)
            in if List.exists(fn word=>word="packed" orelse word="aligned" orelse word="align")words
               then raise Shim(source,"explicit aggregate attributes require a verified adapter")
               else walk source seen flexible base end
        | CParse.Array{element,bound}=>
            let val count=if null bound then if flexible then 0 else fail source "incomplete array layout" else constant bound
                val ()=if count<0 then fail source "negative C array bound" else ()
                val element=walk source seen false element
            in Sequence{size=bounded source(IntInf.*(count,size element)),alignment=alignment element,count=count,element=element} end
        | CParse.Record{kind,tag,fields=NONE,...}=>
            (case tag of NONE=>fail source "incomplete anonymous aggregate"
             | SOME name=>find source (case kind of CParse.Struct=>"struct" | CParse.Union=>"union") name seen flexible)
        | CParse.Record{kind,fields=SOME fields,pack,...}=>
            let val union=case kind of CParse.Union=>true | _=>false
                val ()=if null fields then raise Shim(source,"empty aggregates require a verified adapter") else ()
                val ()=case pack of NONE=>() | SOME n=>if power n then () else fail source "invalid packing alignment"
                fun effective n=case pack of NONE=>n | SOME p=>Int.min(p,n)
                fun collect([],offset,maximum,align,acc)=
                      Aggregate{size=bounded source(round(if union then maximum else offset,align)),alignment=align,
                        union=union,packed=isSome pack,fields=rev acc}
                  | collect(CParse.Field{name,ctype,bits,location}::rest,offset,maximum,align,acc)=
                      let val ()=if null bits then () else raise Shim(location,"bitfield layout/access requires a verified C adapter")
                          val layout=walk location seen (not union andalso null rest) ctype
                          val a=effective(alignment layout)
                          val at=if union then 0 else bounded location(round(offset,a))
                          val ending=bounded location(IntInf.+(at,size layout))
                      in collect(rest,ending,IntInf.max(maximum,size layout),Int.max(align,a),
                           FieldLayout{name=name,offset=at,layout=layout,source=location}::acc) end
            in collect(fields,0,0,1,[]) end
    in walk source [] false ty end
  fun member(layout,path)=
    let val unknown={file="<member>",line=1,column=1}
        fun candidates (Aggregate{fields,...}) name = List.concat(List.map(fn FieldLayout{name=field,offset,layout,source}=>
              case field of SOME n=>if n=name then [(offset,layout)] else []
              | NONE=>List.map(fn(inner,layout)=>(IntInf.+(offset,inner),layout))(candidates layout name))fields)
          | candidates _ _=[]
        fun walk(layout,[],offset)={offset=offset,layout=layout}
          | walk(layout,name::rest,offset)=case candidates layout name of
              [(at,field)]=>walk(field,rest,IntInf.+(offset,at))
            | []=>raise Error(unknown,"unknown aggregate member: " ^ name)
            | _=>raise Error(unknown,"ambiguous anonymous aggregate member: " ^ name)
    in walk(layout,path,0) end
end
