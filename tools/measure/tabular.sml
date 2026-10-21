(* Quoted tabular records as used by CSV/TSV report producers. *)
structure MeasureTabular =
struct
  open MeasureCommon
  fun records separator source =
    let val n=size source
        fun field chars=String.implode (List.rev chars)
        fun loop i quoted chars row rows =
          if i=n then
             (need (not quoted,"unterminated quoted table field");List.rev (if null chars andalso null row then rows else List.rev (field chars::row)::rows))
          else let val c=String.sub (source,i)
          in if quoted then
                if c= #"\"" then if i+1<n andalso String.sub (source,i+1) = #"\"" then loop (i+2) true (#"\""::chars) row rows
                       else loop (i+1) false chars row rows
                else loop (i+1) true (c::chars) row rows
             else if c= #"\"" andalso null chars then loop (i+1) true chars row rows
             else if c=separator then loop (i+1) false [] (field chars::row) rows
             else if c= #"\n" orelse c= #"\r" then
                let val next=if c= #"\r" andalso i+1<n andalso String.sub (source,i+1) = #"\n" then i+2 else i+1
                in loop next false [] [] (if null chars andalso null row then rows else List.rev (field chars::row)::rows) end
             else loop (i+1) false (c::chars) row rows end
    in loop 0 false [] [] [] end
  fun readTable path=case records #"\t" (read path) of [] => [] | header::rows =>
       List.map (fn values => ListPair.zip (header,values)) rows
  fun get key row=case List.find (fn (name,_) => key=name) row of SOME (_,value) => value | NONE => raise Failed ("missing table column " ^ key)
  fun number key row=decimal (get key row)
end
