(* Stable formatting for captured report schemas. Presentation templates
   are data; every classification, statistic and comparison is typed SML. *)
structure MeasureFormat =
struct
  open MeasureCommon
  datatype value=Text of string | Integer of IntInf.int | Decimal of real
  fun string (Text s)=s | string (Integer n)=intText n | string (Decimal n)=minus (Real.toString n)
  fun floating (Decimal n)=n | floating (Integer n)=Real.fromLargeInt (IntInf.toLarge n) | floating _=raise Failed "numeric report value expected"
  fun integer (Integer n)=n | integer (Decimal n)=IntInf.fromLarge (Real.toLargeInt IEEEReal.TO_ZERO n) | integer _=raise Failed "integer report value expected"
  fun format template values =
    let val size=size template
        fun digits at=let fun loop i=if i<size andalso Char.isDigit (String.sub (template,i)) then loop (i+1) else i
                          val last=loop at
                      in (case Int.fromString (String.substring (template,at,last-at)) of SOME n => n | NONE => 0,last) end
        fun loop at values acc=if at=size then
              (need (null values,"too many report format values");String.concat (List.rev acc))
           else if String.sub (template,at)<> #"%" then loop (at+1) values (str (String.sub (template,at))::acc)
           else if at+1<size andalso String.sub (template,at+1) = #"%" then loop (at+2) values ("%"::acc)
           else
             let val left=at+1<size andalso String.sub (template,at+1) = #"-"
                 val plus=at+1<size andalso String.sub (template,at+1) = #"+"
                 val (width,next)=digits (at+(if left orelse plus then 2 else 1))
                 val (precision,next)=if next<size andalso String.sub (template,next) = #"." then digits (next+1) else (6,next)
                 val ()=need (next<size,"incomplete report format")
                 val (value,rest)=case values of value::rest => (value,rest) | [] => raise Failed "missing report format value"
                 val kind=String.sub (template,next)
                 val text=case kind of #"s" => string value | #"d" => intText (integer value)
                       | #"f" => fixed precision (floating value) | #"g" => general (floating value)
                       | #"x" => String.map Char.toLower (IntInf.fmt StringCvt.HEX (integer value))
                       | _ => raise Failed ("unsupported report format " ^ str kind)
                 val text=if plus andalso text<>"" andalso String.sub (text,0)<> #"-" then "+" ^ text else text
                 val padded=if left then StringCvt.padRight #" " width text else StringCvt.padLeft #" " width text
             in loop (next+1) rest (padded::acc) end
    in loop 0 values [] end
end
