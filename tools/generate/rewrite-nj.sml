structure GenerateRewriteNJ =
struct
  open MeasureCommon
  structure T=GenerateText
  fun main (settings:GenerateRewrites.settings) file =
    let val libraries=ref [] : (string*string) list ref
        fun ident lib name =
          let val id=String.map (fn c => if Char.isAlphaNum c orelse c = #"_" then c else #"_") (lib ^ "_" ^ name)
              val ()=GenerateRewrites.emit settings (id ^ "\t" ^ lib ^ "\t" ^ name)
          in "XC2NC." ^ id end
        fun line line =
          let val line=T.replace line "#[" "XC2N.vector ["
              val line=T.substitute "(InLine|InlineT)\\.=" (fn _ => "op =") line
              val line=T.substitute "([A-Za-z_][A-Za-z0-9_]*\\.)*Assembly\\.vector0" (fn _ => "(XC2N.vector0 ())") line
              val binder=TerminalPattern.find (TerminalPattern.compile false "fun[ \t]+[A-Za-z_][A-Za-z0-9_']*[ \t]+x[ \t]*=[ \t]*(CInterface|CI)\\.c_function[ \t]+\"[^\"]*\"[ \t]+x") line 0
          in case binder of SOME (a,b) =>
                let val call=String.substring (line,a,b-a) val name=List.nth (String.tokens Char.isSpace call,1) val lib=List.nth (fields #"\"" call,1)
                in libraries:=(name,lib)::List.filter (fn (old,_) => old<>name) (!libraries);line end
            | NONE =>
              let val line=T.substitute "(CInterface|CI)\\.c_function[ \t]+\"[^\"]*\"[ \t]+\"[^\"]*\"" (fn call => let val quotes=fields #"\"" call in ident (List.nth (quotes,1)) (List.nth (quotes,3)) end) line
                  fun rewrite (name,lib) line=T.substitute ("(^|[^A-Za-z0-9_'.])" ^ name ^ "[ \t]+\"[^\"]*\"") (fn call =>
                       let val lead=if String.isPrefix name call then "" else String.substring (call,0,1)
                           val value=List.nth (fields #"\"" call,1)
                       in lead ^ ident lib value end) line
              in List.foldl (fn (entry,line) => rewrite entry line) line (!libraries) end end
    in T.lineMap line (T.required file) end
end
