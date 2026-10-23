(* Implements: FOREIGN_MODEL *)
structure ForeignModel : FOREIGN_MODEL =
struct
  type source = {file : string, line : int, column : int}
  type identity = {family : string, namespace : string, name : string}
  type expression = {family : string, text : string, source : source}
  datatype foreignType = Scalar of {family : string, name : string} | Named of identity
    | Pointer of {target : foreignType, qualifiers : string list}
    | Array of {element : foreignType, bound : expression option}
    | Callable of {result : foreignType, parameters : parameter list, variadic : bool, prototype : bool}
    | Aggregate of {kind : string, tag : identity option, fields : field list option, packing : int option}
    | Enumeration of {tag : identity option, values : (string * expression option) list option}
    | Attributed of foreignType * expression list
    | Macro of {parameters : string list option, variadic : bool, body : expression}
    | BackendType of {family : string, description : string}
  and parameter = Parameter of {name : string option, ty : foreignType}
  and field = Field of {name : string option, ty : foreignType, bits : expression option, source : source}
  type declaration = {identity : identity, ty : foreignType, storage : string list, source : source}
  type scalarLayout = {size : int, alignment : int, signed : bool option}
  datatype byteOrder = Little | Big
  type target = {name : string, abi : string, byteOrder : byteOrder, scalars : (string * scalarLayout) list}
  type layout = {size : IntInf.int, alignment : int, fields : (string * IntInf.int) list}
  type capabilities = {backend : string, families : string list, mechanisms : string list,
    callbacks : string list, unsupported : string list}
  exception Error of source * string
  fun key ({family, namespace, name} : identity) =
    String.concat (List.map (fn s => Int.toString (size s) ^ ":" ^ s) [family, namespace, name])
  fun id namespace name : identity = {family = "c", namespace = namespace, name = name}
  fun expression source [] = NONE
    | expression source tokens = SOME {family = "c", text = CLex.spelling tokens,
        source = #1 (CLex.diagnostic (hd tokens, ""))}
  fun compareSource (a:source,b:source) = case String.compare(#file a,#file b) of
      EQUAL => (case Int.compare(#line a,#line b) of EQUAL=>Int.compare(#column a,#column b) | order=>order)
    | order=>order
  fun beforeDeclaration (a:declaration,b:declaration) = case String.compare(key(#identity a),key(#identity b)) of
      EQUAL=>compareSource(#source a,#source b)<>GREATER | LESS=>true | GREATER=>false
  fun canonical values =
    let fun split([],left,right)=(left,right)
          | split([x],left,right)=(x::left,right)
          | split(x::y::rest,left,right)=split(rest,x::left,y::right)
        fun merge([],ys)=ys | merge(xs,[])=xs
          | merge(x::xs,y::ys)=if beforeDeclaration(x,y) then x::merge(xs,y::ys) else y::merge(x::xs,ys)
        fun sort []=[] | sort [one]=[one]
          | sort xs=let val(left,right)=split(xs,[],[]) in merge(sort left,sort right) end
    in sort values end
  fun bucket name = CharVector.foldl(fn(c,n)=>(n*33+Char.ord c) mod 4093)0 name
  val scalarName = CType.canonical
  fun fromC input =
    let
      val buckets = Array.array(4093, [] : (string * declaration) list)
      val nowhere : source = {file = "", line = 0, column = 0}
      fun expr ({family, text, ...} : expression) = {family = family, text = text, source = nowhere} : expression
      fun semantic (Scalar scalar) = Scalar scalar
        | semantic (Named identity) = Named identity
        | semantic (Pointer {target, qualifiers}) = Pointer {target = semantic target, qualifiers = qualifiers}
        | semantic (Array {element, bound}) = Array {element = semantic element, bound = Option.map expr bound}
        | semantic (Callable {result, parameters, variadic, prototype}) = Callable {result = semantic result,
            parameters = List.map (fn Parameter {name, ty} => Parameter {name = NONE, ty = semantic ty}) parameters,
            variadic = variadic, prototype = prototype}
        | semantic (Aggregate {kind, tag, fields, packing}) = Aggregate {kind = kind, tag = tag, packing = packing,
            fields = Option.map (List.map (fn Field {name, ty, bits, ...} => Field
              {name = name, ty = semantic ty, bits = Option.map expr bits, source = nowhere})) fields}
        | semantic (Enumeration {tag, values}) = Enumeration {tag = tag,
            values = Option.map (List.map (fn (name, value) => (name, Option.map expr value))) values}
        | semantic (Attributed (base, attributes)) = Attributed (semantic base, List.map expr attributes)
        | semantic (Macro{parameters,variadic,body}) = Macro{parameters=parameters,variadic=variadic,body=expr body}
        | semantic (BackendType backend) = BackendType backend
      fun storage words = List.filter (fn word => word <> "extern") words
      fun add (d : declaration) =
        let val name=key(#identity d)
            val index=bucket name
            val entries=Array.sub(buckets,index)
            val value=semantic(#ty d)
            fun compatible (other,old:declaration)=other=name andalso value=semantic(#ty old)
              andalso storage(#storage old)=storage(#storage d)
        in case List.find compatible entries of
            NONE=>Array.update(buckets,index,(name,d)::entries)
          | SOME(_,old)=>if beforeDeclaration(d,old) then
              Array.update(buckets,index,(name,d)::List.filter(fn pair=>not(compatible pair))entries)
            else ()
        end
      fun tag namespace = Option.map (id namespace)
      fun ty source (CParse.Builtin name) = Scalar {family = "c", name = scalarName name}
        | ty _ (CParse.Named name) = Named (id "typedef" name)
        | ty source (CParse.Pointer {target, qualifiers}) = Pointer {target = ty source target, qualifiers = qualifiers}
        | ty source (CParse.Array {element, bound}) = Array {element = ty source element, bound = expression source bound}
        | ty source (CParse.Function {result, parameters, variadic, prototype}) =
            Callable {result = ty source result, parameters = List.map
              (fn CParse.Parameter {name, ctype} => Parameter {name = name, ty = ty source ctype}) parameters,
              variadic = variadic, prototype = prototype}
        | ty source (CParse.Record {kind, tag = name, fields, pack}) =
            let val kind = case kind of CParse.Struct => "struct" | CParse.Union => "union"
                val result = Aggregate {kind = kind, tag = tag kind name,
                  fields = Option.map (List.map (fn CParse.Field {name, ctype, bits, location} =>
                    Field {name = name, ty = ty location ctype, bits = expression location bits, source = location})) fields,
                  packing = pack}
                val () = case name of SOME name => if isSome fields then
                  add {identity = id kind name, ty = result, storage = [], source = source} else () | NONE => ()
            in result end
        | ty source (CParse.Enum {tag = name, values}) =
            let val result = Enumeration {tag = tag "enum" name, values = Option.map
                  (List.map (fn (name, tokens) => (name, expression source tokens))) values}
                val () = case name of SOME name => if isSome values then
                  add {identity = id "enum" name, ty = result, storage = [], source = source} else () | NONE => ()
            in result end
        | ty source (CParse.Attributed (base, attributes)) = Attributed (ty source base,
            List.mapPartial (expression source) attributes)
      fun callable (Attributed (base, _)) = callable base | callable (Callable _) = true | callable _ = false
      fun one (CParse.StaticAssert _) = ()
        | one (CParse.Declaration {name, ctype, storage, location, ...}) =
          let val value = ty location ctype
          in case name of NONE => () | SOME name =>
            add {identity = id (if List.exists (fn s => s = "typedef") storage then "typedef"
              else if callable value then "function" else "object") name,
              ty = value, storage = storage, source = location} end
      val () = List.app one input
    in canonical(Array.foldl(fn(entries,all)=>List.map #2 entries @ all)[]buckets) end
  fun fromCMacros macros = canonical(List.map(fn m:CPreprocess.macro=>
    {identity=id "macro" (#name m),ty=Macro{parameters= #parameters m,variadic= #variadic m,
      body={family="c",text=CLex.spelling(#body m),source= #location m}},storage=[],source= #location m})macros)
  type environment = (string * declaration) list Array.array
  fun index declarations =
    let val entries=Array.array(4093,[]: (string * declaration)list)
        val ()=List.app(fn declaration:declaration=>
          let val name=key(#identity declaration) val slot=bucket name
          in Array.update(entries,slot,(name,declaration)::Array.sub(entries,slot)) end)declarations
    in entries end
  fun lookup (environment : environment, identity : identity) =
    let val name=key identity
    in case List.filter(fn(other,_)=>name=other)(Array.sub(environment,bucket name)) of
      []=>NONE | [(_,one)]=>SOME one
    | (_,one)::_=>raise Error(#source one,"incompatible redeclarations of selected identity: " ^ #name identity)
    end
  fun find (declarations,identity) = lookup(index declarations,identity)
  fun reachable (declarations, selected) =
    let val environment=index declarations
        val seen=ref([]:string list)
        val result=ref([]:declaration list)
        fun visit source identity =
          let val name=key identity
          in if List.exists(fn old=>old=name)(!seen) then () else
            (seen:=name:: !seen;
             case lookup(environment,identity) of NONE=>raise Error(source,"unknown selected identity: " ^ #name identity)
             | SOME declaration=>(result:=declaration:: !result; walk (#source declaration) (#ty declaration))) end
        and walk source (Named identity)=visit source identity
          | walk source (Pointer{target,...})=walk source target
          | walk source (Array{element,...})=walk source element
          | walk source (Callable{result,parameters,...})=
              (walk source result;List.app(fn Parameter{ty,...}=>walk source ty)parameters)
          | walk source (Attributed(base,_))=walk source base
          | walk source (Aggregate{fields=SOME fields,...})=
              List.app(fn Field{ty,source,...}=>walk source ty)fields
          | walk source (Aggregate{tag=SOME identity,fields=NONE,...})=
              (case lookup(environment,identity) of NONE=>() | SOME _=>visit source identity)
          | walk source (Enumeration{tag=SOME identity,values=NONE})=
              (case lookup(environment,identity) of NONE=>() | SOME _=>visit source identity)
          | walk _ _=()
        val unknown={file="<selection>",line=1,column=1}
        val ()=List.app(visit unknown)selected
    in canonical(!result) end
  val libffi : capabilities = {backend = "libffi", families = ["c"], mechanisms = ["dynamic"],
    callbacks = ["owner-vm-thread"], unsupported = ["foreign-thread-entry", "variadic-callbacks", "c++", "java", "web-idl", "webassembly", "direct-linking"]}
end
