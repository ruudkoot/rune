(* The legacy AWK generator uses binary64 arithmetic for its LCG, and prints
   recursive children before their enclosing element. Preserve both details. *)
structure GenerateFXP =
struct
  open MeasureCommon
  fun main [] =
    let val seed=ref 12345.0
        val words=Vector.fromList (String.tokens Char.isSpace "alpha beta gamma delta epsilon zeta eta theta iota kappa lambda mu nu xi omicron pi rho sigma tau upsilon phi chi psi omega")
        val tags=Vector.fromList ["section","para","list","item","note","em","code","ref"]
        val attrs=Vector.fromList ["href","id","class","rel","n"]
        fun random n=(seed:=Real.rem (!seed*1103515245.0+12345.0,2147483648.0);Real.trunc (!seed/65536.0) mod n)
        fun word ()=Vector.sub (words,random 24)
        fun text count=let val s=String.concatWith " " (List.tabulate (count,fn _ => word ()))
                       in if random 4=0 then s ^ " &amp; " ^ word () ^ " &lt;x&gt; (c)" else s end
        fun attributes ()=String.concat (List.tabulate (random 4,fn _ => let val name=Vector.sub (attrs,random 5) val w=word () val n=random 1000 in " " ^ name ^ "=\"" ^ w ^ Int.toString n ^ "\"" end))
        fun element depth =
          let val tag=Vector.sub (tags,random 8) val tag=if depth=1 andalso random 3=0 then "section" else tag
              val attrs=attributes () val count=random 3+1
              fun part _=let val n=random 12+1 val text=text n
                         in text ^ "\n" ^ (if depth<3 andalso random 3=0 then Int.toString (element (depth+1)) else "") end
              val body="<" ^ tag ^ attrs ^ ">\n" ^ String.concat (List.tabulate (count,part))
              val body=if tag="section" then "<title" ^ attributes () ^ ">\n" ^ text 4 ^ "\n</title>\n" ^ body else body
              val out=body ^ "</" ^ tag ^ ">\n"
          in say out;size out end
        fun loop n=if n>=1200000 then () else loop (n+element 1)
    in say "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<doc>\n";loop 0;say "</doc>\n";0 end
    | main _=raise Usage "fxp (writes the fixed XML benchmark input to stdout)"
end
