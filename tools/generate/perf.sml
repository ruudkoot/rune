(* Module-language stress inputs. Text is deterministic across host Int widths. *)
structure GeneratePerf =
struct
  open MeasureCommon
  fun upto n=List.tabulate (Int.max (0,n),fn i => i+1)
  fun indices n=List.tabulate (Int.max (0,n),fn i => i)
  fun join lines=String.concatWith "\n" lines
  fun signatureText count =
    let val types=ref [] : string list ref
        fun one i=
          let val n=Int.toString i val a=case !types of first::_ => first | [] => "int"
              val b=case !types of _::second::_ => second | _ => "int"
          in case i mod 5 of
              0 => (types:=("t" ^ n):: !types;"  type t" ^ n)
            | 1 => (types:=("e" ^ n):: !types;"  eqtype e" ^ n)
            | 2 => "  val v" ^ n ^ " : " ^ a ^ " -> " ^ b ^ " * int list"
            | 3 => (types:=("d" ^ n):: !types;"  datatype d" ^ n ^ " = D" ^ n ^ " of " ^ a ^ " | E" ^ n ^ " of int * d" ^ n)
            | _ => "  structure S" ^ n ^ " : sig type u val w : u * " ^ a ^ " end" end
        val declarations=List.map one (indices count)
    in (join ("signature BIG = sig"::declarations @ ["end"]),List.rev (!types)) end
  fun implementation count =
    let val types=ref [] : string list ref val values=ref [("int","0")]
        fun value name=case List.find (fn (key,_) => key=name) (!values) of SOME (_,v) => v | NONE => raise Failed "missing stress type constructor"
        fun one i=
          let val n=Int.toString i val a=case !types of first::_ => first | [] => "int" val b=case !types of _::second::_ => second | _ => "int"
              fun bind name expression=(types:=name:: !types;values:=(name,expression):: !values)
          in case i mod 5 of
              0 => (bind ("t" ^ n) "0";"  type t" ^ n ^ " = int")
            | 1 => (bind ("e" ^ n) "0";"  type e" ^ n ^ " = int")
            | 2 => "  fun v" ^ n ^ " (x : " ^ a ^ ") : " ^ b ^ " * int list = v" ^ n ^ " x"
            | 3 => (bind ("d" ^ n) ("D" ^ n ^ " (" ^ value a ^ ")");"  datatype d" ^ n ^ " = D" ^ n ^ " of " ^ a ^ " | E" ^ n ^ " of int * d" ^ n)
            | _ => "  structure S" ^ n ^ " = struct type u = int val w : u * " ^ a ^ " = (0, " ^ value a ^ ") end" end
    in join ("structure Impl = struct"::List.map one (indices count) @ ["end"]) end
  val argument="signature ARG = sig type t val x : t val f : t -> t end"
  fun argumentValue i="struct type t = int val x = " ^ Int.toString i ^ " fun f (y : int) = y end"
  fun body count=List.map (fn j => let val n=Int.toString j val previous=Int.toString (j-1)
       in case j mod 4 of 0 => "  val a" ^ n ^ " = X.f X.x"
        | 1 => "  fun g" ^ n ^ " y = (X.f y, fn z => (z, y))"
        | 2 => "  datatype d" ^ n ^ " = D" ^ n ^ " of X.t | E" ^ n ^ " of int * d" ^ n
        | _ => "  fun h" ^ n ^ " (D" ^ previous ^ " v) = X.f v | h" ^ n ^ " (E" ^ previous ^ " (_, d)) = h" ^ n ^ " d" end) (indices count)
  val exports=["  type t = X.t","  val x = X.x","  val f = X.f"]
  (* the applications static interpretation elaborates, which a budget's
     scale line measures a compile's growth by (tests/runner/budgets.sml):
     funnest's 1 + M + M^2 + ... + M^D, as an IntInf, the same on every
     host *)
  fun applications n="(* " ^ IntInf.toString n ^ " applications *)"
  fun nested (d,m)=List.foldl (fn (_,acc) => acc * IntInf.fromInt m + 1) 1 (upto d)
  fun generate kind ns =
    let fun sigText n= #1 (signatureText n)
        fun inst s k flavour =join ([sigText s,"signature USE = sig"] @ List.map (fn i => "  structure A" ^ Int.toString i ^ " : BIG") (upto k) @
               (if flavour="chain" then List.map (fn i => "  sharing A" ^ Int.toString i ^ " = A1") (List.filter (fn i => i>=2) (upto k))
                else if flavour="all" andalso k>=2 then ["  sharing " ^ String.concatWith " = " (List.map (fn i => "A" ^ Int.toString i) (upto k))] else []) @ ["end"])
    in case (kind,ns) of
        ("sig",[s]) => sigText s
      | ("inst",[s,k]) => inst s k "" | ("share",[s,k]) => inst s k "chain" | ("shareall",[s,k]) => inst s k "all"
      | ("sharenest",[s,k]) => join ([sigText s,"signature USE = sig"] @ List.map (fn i => "  structure M" ^ Int.toString i ^ " : sig structure A : BIG end") (upto k) @ ["  structure X : BIG"] @ List.map (fn i => "  sharing X = M" ^ Int.toString i ^ ".A") (upto k) @ ["end"])
      | ("where",[s,w]) => let val (text,types)=signatureText s val flex=List.filter (fn name => String.isPrefix "t" name orelse String.isPrefix "e" name) types
             val ()=need (w<=length flex,"where: only " ^ Int.toString (length flex) ^ " non-datatype types in BIG of " ^ Int.toString s ^ " specs")
             in text ^ "\nsignature W = BIG where " ^ String.concatWith "\n  and " (List.map (fn name => "type " ^ name ^ " = int") (List.take (flex,if w>=0 then w else Int.max (0,length flex+w)))) end
      | ("funsig",[s,a]) => join ([sigText s,implementation s,"functor F (X : BIG) = struct val a = X.v2 type t = X.t0 end"] @ List.map (fn i => "structure R" ^ Int.toString i ^ " = F (Impl)") (upto a))
      | ("funapp",[b,a]) => join ([applications (IntInf.fromInt a),argument,"functor F (X : ARG) = struct"] @ body b @ ["end"] @ List.map (fn i => "structure S" ^ Int.toString i ^ " = F (" ^ argumentValue i ^ ")") (upto a))
      | ("funnest",[d,m,b]) => join ([applications (nested (d,m)),argument,"functor F0 (X : ARG) = struct"] @ body b @ exports @ ["end"] @
                List.concat (List.map (fn level => ["functor F" ^ Int.toString level ^ " (X : ARG) = struct"] @ List.map (fn i => "  structure N" ^ Int.toString i ^ " = F" ^ Int.toString (level-1) ^ " (X)") (upto m) @ body b @ exports @ ["end"]) (upto d)) @ ["structure R = F" ^ minus (Int.toString d) ^ " (" ^ argumentValue 1 ^ ")"])
      | ("expo",[n]) => "fun f x = x\nfun toy () =\n   let\n      fun g y = " ^ String.concatWith " " (List.map (fn _ => "f") (indices n)) ^ " y\n   in g 3; g 4\n   end\nval _ = toy ()"
      | _ => raise Usage "perf sig S | inst/share/shareall/sharenest S K | where S W | funapp/funsig B A | funnest D M B | expo N"
    end
  fun main (kind::args)=(say (generate kind (List.map integer args) ^ "\n");0)
    | main _=raise Usage "perf KIND PARAMS..."
end
