(* Host extension rewrites. Every transformation and table row is SML;
   no regular-expression or source-order policy remains in AWK. *)
structure GenerateRewrites =
struct
  open MeasureCommon
  structure T=GenerateText
  type settings={table:string option,typed:string list,consts:(string*string) list,ctypes:(string*string) list,ambiguous:string list}
  val empty={table=NONE,typed=[],consts=[],ctypes=[],ambiguous=[]}:settings
  fun emit (s:settings) line=case #table s of NONE => () | SOME file => append (file,line ^ "\n")
  fun mangle keepUnderscore source =
    let val s=T.replace (T.replace (T.replace source "->" " to ") "*" " x ") "'" "q"
        val s=if keepUnderscore then T.replace s "." "_" else s
        val s=T.substitute (if keepUnderscore then "[^A-Za-z0-9_]+" else "[^A-Za-z0-9]+") (fn _ => "_") s
    in T.substitute "_+$" (fn _ => "") (T.substitute "^_+" (fn _ => "") s) end
  fun mlkitIdent "="="EQ" | mlkitIdent "!"="DEREF" | mlkitIdent ":="="ASSIGN" | mlkitIdent source =
    let val s=if String.isPrefix "@" source then "AT_" ^ String.extract (source,1,NONE) else source
        val s=String.map (fn c => if Char.isAlphaNum c orelse c = #"_" then c else #"_") s
    in if size s>0 andalso Char.isAlpha (String.sub (s,0)) then s else "P" ^ s end
  fun mlkitTypes pre =
    case TerminalPattern.find (TerminalPattern.compile false "(\\([ \t]*\\)|\\([^():]*:[^()]*\\))[ \t]*:[^=]*=") pre 0 of NONE => "UNTYPED"
      | SOME (a,b) =>
        let val h=String.substring (pre,a,b-a) val close=valOf (T.splitAt ")" h)
            val result= #2 (valOf (T.splitAt ":" (#2 close)))
            val result=String.substring (result,0,size result-1)
            val input=if T.matches "^\\([ \t]*\\)" h then "unit" else
                    let val after= #2 (valOf (T.splitAt ":" (#1 close))) in hd (fields #"," after) end
        in mangle true input ^ "__" ^ mangle true result end
  fun mlkit (settings:settings) file =
    let val typed=["id","unsafe_cast"] @ #typed settings
        val prim=TerminalPattern.compile false "(^|[^A-Za-z0-9_'.])prim[ \t]*\\([ \t]*\"[^\"]*\"[ \t]*,"
        fun line source =
          let fun loop text acc =case TerminalPattern.find prim text 0 of NONE => String.concat (List.rev (T.replace (T.substitute "_export[ \t]*\\(" (fn _ => "XC2KPrim.export (") text) "_IntInf" "XC2_IntInf"::acc))
                | SOME (a,b) =>
                  let val pre=String.substring (text,0,a) val matched=String.substring (text,a,b-a)
                      val lead=if String.isPrefix "prim" matched then "" else String.substring (matched,0,1)
                      val name=List.nth (fields #"\"" matched,1)
                      val id=mlkitIdent name ^ (if List.exists (fn old => old=name) typed then "__" ^ mlkitTypes pre else "")
                      val ()=emit settings (id ^ "\t" ^ name ^ "\t" ^ file)
                  in loop (String.extract (text,b,NONE)) ((pre ^ lead ^ "XC2KPrim." ^ id ^ " (")::acc) end
          in loop source [] end
    in T.lineMap line (T.required file) end
  fun lookup key values=case List.find (fn (name,_) => name=key) values of SOME (_,v) => v | NONE => raise Failed ("missing extension constant/type " ^ key)
  fun literal (settings:settings) value ty =
    if ty="bool" then value else if ty="String8.string" then "\"" ^ value ^ "\"" else
     let val kind=if T.matches "^C_[A-Za-z0-9_]*\\.t$" ty then T.substitute "[0-9]+$" (fn _ => "") (lookup (hd (fields #"." ty)) (#ctypes settings))
             else if T.matches "^Int[0-9]+\\.int$" ty then "Int" else if T.matches "^Word[0-9]+\\.word$" ty then "Word" else raise Failed ("a constant of type " ^ ty)
     in if kind="Word" then (need (T.matches "^[0-9]+$" value,"word constant " ^ value);"0w" ^ value)
        else if kind="Int" then (need (T.matches "^-?[0-9]+$" value,"int constant " ^ value);if String.isPrefix "-" value then "~" ^ String.extract (value,1,NONE) else value)
        else raise Failed ("a constant of type " ^ ty) end
  fun mlton (settings:settings) file =
    let val expression=TerminalPattern.compile false "_(prim|import|const|build_const|command_line_const|symbol|address|export)[ \t\n]"
        val named=TerminalPattern.compile false "^[ \t\n]*(\"[^\"]*\"|\\*)"
        fun loop text acc=case TerminalPattern.find expression text 0 of NONE => String.concat (List.rev (text::acc))
          | SOME (a,b) =>
            let val pre=String.substring (text,0,a) val matched=String.substring (text,a,b-a)
                val rest=String.extract (text,b,NONE)
            in if size pre>0 andalso (let val c=String.sub (pre,size pre-1) in Char.isAlphaNum c orelse c = #"_" orelse c = #"'" end) then loop rest ((pre ^ matched)::acc) else
              let val kind=String.substring (matched,1,size matched-2)
                  val stop=case TerminalPattern.find named rest 0 of SOME (_,stop) => stop | _ => raise Failed ("no name after _" ^ kind)
                  val name=trim (String.substring (rest,0,stop)) val name=if String.isPrefix "\"" name then String.substring (name,1,size name-2) else name
                  val rest=String.extract (rest,stop,NONE)
                  val (attrs,rest)=case T.splitAt ":" rest of SOME p => p | _ => raise Failed ("no type after _" ^ kind ^ " " ^ name)
                  val (ty,rest)=case T.splitAt ";" rest of SOME p => p | _ => raise Failed ("no ; after _" ^ kind ^ " " ^ name)
                  val normalized=String.concatWith " " (String.tokens Char.isSpace ty)
                  val nl=String.translate (fn #"\n" => "\n" | _ => "") attrs
                  val replacement=if kind="command_line_const" then
                       (case T.splitAt "=" ty of SOME (ty,value) => "(" ^ value ^ " :" ^ nl ^ ty ^ ")" | _ => raise Failed "command line constant has no default")
                    else if kind="const" orelse kind="build_const" then "(" ^ literal settings (lookup name (#consts settings)) normalized ^ " :" ^ nl ^ ty ^ ")"
                    else let val ()=need (kind<>"export","_export " ^ name ^ " is not supported") val ()=need (name<>"*","_" ^ kind ^ " * is not supported")
                             val namespace=case kind of "prim" => "XC2Prim" | "import" => "XC2FFI" | "symbol" => "XC2Symbol" | _ => "XC2Address"
                             val id=name ^ (if List.exists (fn key => key=kind ^ "\t" ^ name) (#ambiguous settings) then "__" ^ mangle false normalized else "")
                             val ()=emit settings (kind ^ "\t" ^ name ^ "\t" ^ normalized)
                         in "(" ^ namespace ^ "." ^ id ^ " :" ^ nl ^ ty ^ ")" end
              in loop rest ((pre ^ replacement)::acc) end end
    in loop (T.required file) [] end
end
