(* Implements: FOREIGN_PROJECTION *)
structure ForeignProjection : FOREIGN_PROJECTION =
struct
  datatype tree = datatype ForeignPolicy.tree
  exception Error = ForeignModel.Error
  fun check {source, available, projection} =
    let fun fail s = raise Error (source, s)
        fun unique [] = () | unique (x :: xs) = if List.exists (fn y => x = y) xs then fail ("duplicate projection field: " ^ x) else unique xs
        val used = ref ([] : string list)
        fun visit Unit = ()
          | visit (Value name) =
              if List.exists (fn n => n = name) (!used) then fail ("duplicate projected value: " ^ name)
              else if List.exists (fn n => n = name) available then used := name :: !used
              else fail ("unknown projected value: " ^ name)
          | visit (Product values) = List.app visit values
          | visit (Fields fields) = (unique (List.map #1 fields); List.app (visit o #2) fields)
    in unique available; visit projection end
  fun typeOf {source, values, projection} =
    let val () = check {source = source, available = List.map #1 values, projection = projection}
        fun value name = case List.find (fn (n, _) => n = name) values of SOME (_, ty) => ty
          | NONE => raise Error (source, "unknown projected value: " ^ name)
        fun build Unit = ForeignPolicy.Scalar "unit"
          | build (Value name) = value name
          | build (Product values) = ForeignPolicy.Tuple (List.map build values)
          | build (Fields fields) = ForeignPolicy.Record (List.map (fn (label, tree) => (label, build tree)) fields)
    in build projection end
  fun callType {policy=p:ForeignPolicy.functionPolicy, inputs, result} =
    let fun annotation name = List.find(fn a:ForeignPolicy.valuePolicy=> #name a=SOME name)(#parameters p)
        fun projected (name,base) = (name,case annotation name of SOME a=>getOpt(#projection a,base) | NONE=>base)
        val values=List.map projected inputs
        val input=List.filter(fn(name,_)=>case annotation name of
          SOME a=> #direction a<>SOME ForeignPolicy.Out | NONE=>true)values
        val outputs=List.filter(fn(name,_)=>case annotation name of
          SOME a=> #direction a=SOME ForeignPolicy.Out orelse #direction a=SOME ForeignPolicy.InOut | NONE=>false)values
        val result=getOpt(#projection(#result p),result)
        fun tuple []=ForeignPolicy.Scalar "unit" | tuple[(_,ty)]=ty
          | tuple values=ForeignPolicy.Tuple(List.map #2 values)
        fun label (name,ty)=case annotation name of SOME a=>(getOpt(#output a,ForeignPolicy.rawName name),ty) | NONE=>(ForeignPolicy.rawName name,ty)
        val output=if null outputs then result else ForeignPolicy.Record
          ((if result=ForeignPolicy.Scalar "unit" then [] else [("result",result)]) @ List.map label outputs)
        val ()=case output of ForeignPolicy.Record fields=>check{source= #source p,
          available=List.map #1 fields,projection=Unit} | _=>()
    in {input=case #input p of NONE=>tuple input | SOME projection=>typeOf{source= #source p,values=input,projection=projection},
        output=case #returns p of NONE=>output | SOME projection=>typeOf{source= #source p,
          values=("$result",result)::outputs,projection=projection}} end
  fun renderType ty =
    let fun scalar name = case name of
            "unit" => "unit" | "bool" => "bool" | "int" => "int" | "int8" => "Int8.int" | "word8" => "Word8.word"
          | "int16" => "Int16.int" | "word16" => "Word16.word" | "int32" => "Int32.int" | "word32" => "Word32.word"
          | "int64" => "Int64.int" | "word64" => "Word64.word" | "real" => "real" | "string" => "string" | "bytes" => "Word8Vector.vector"
          | _ => raise Fail ("unknown SML scalar projection: " ^ name)
        fun checked name =
          if ForeignPolicy.rawName name = name then name else raise Fail ("unchecked SML projection name: " ^ name)
        fun atom (ForeignPolicy.Scalar name) = scalar name
          | atom (ForeignPolicy.Resource name) = checked name
          | atom other = "(" ^ render other ^ ")"
        and render (ForeignPolicy.Scalar name) = scalar name
          | render (ForeignPolicy.Resource name) = checked name
          | render (ForeignPolicy.Option item) = atom item ^ " option"
          | render (ForeignPolicy.Vector item) = atom item ^ " vector"
          | render (ForeignPolicy.Array item) = atom item ^ " array"
          | render (ForeignPolicy.Tuple []) = "unit"
          | render (ForeignPolicy.Tuple [item]) = render item
          | render (ForeignPolicy.Tuple items) = String.concatWith " * " (List.map atom items)
          | render (ForeignPolicy.Record fields) = "{" ^ String.concatWith ", "
              (List.map (fn (label, value) => checked label ^ " : " ^ render value) fields) ^ "}"
    in render ty end
end
