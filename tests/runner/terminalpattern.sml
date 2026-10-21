(* The regular-expression subset used by versioned terminal scenarios:
   alternatives, groups, character classes, anchors and ?/*/+ repetition.
   Matching retains byte offsets and line anchors; raw traces enable dot-all.
   Unknown syntax is rejected, rather than silently weakening an assertion. *)
structure TerminalPattern =
struct
  exception Pattern of string
  datatype expression = Empty | Byte of (char -> bool) | Start | End
                      | Sequence of expression list | Alternative of expression list
                      | Repeat of expression | Optional of expression
  fun compile dotAll source =
    let val at=ref 0
        val length=size source
        fun peek ()=if !at=length then NONE else SOME (String.sub (source,!at))
        fun take ()=case peek () of NONE => raise Pattern "unexpected end of pattern" | SOME c => (at:= !at+1;c)
        fun hex c=
             if Char.isDigit c then Char.ord c-Char.ord #"0" else if c>= #"a" andalso c<= #"f" then Char.ord c-Char.ord #"a"+10
             else if c>= #"A" andalso c<= #"F" then Char.ord c-Char.ord #"A"+10 else raise Pattern "invalid hex escape"
        fun escaped ()=case take () of #"n" => #"\n" | #"r" => #"\r" | #"t" => #"\t" | #"e" => #"\027"
              | #"x" => let val high=hex (take ()) val low=hex (take ()) in Char.chr (16*high+low) end
              | c => if Char.isAlphaNum c then raise Pattern ("unsupported escape: " ^ str c) else c
        fun alternative ()=
          let val first=sequence ()
              fun more acc=case peek () of SOME #"|" => (ignore (take ());more (sequence () :: acc)) | _ =>
                    if null acc then first else Alternative (first :: List.rev acc)
          in more [] end
        and sequence ()=
          let fun loop acc=case peek () of NONE => Sequence (List.rev acc) | SOME #")" => Sequence (List.rev acc)
                    | SOME #"|" => Sequence (List.rev acc) | _ => loop (repeated () :: acc)
          in loop [] end
        and repeated ()=
          let val atom=atom ()
          in case peek () of SOME #"*" => (ignore (take ());Repeat atom)
             | SOME #"+" => (ignore (take ());Sequence [atom,Repeat atom])
             | SOME #"?" => (ignore (take ());Optional atom) | _ => atom end
        and atom ()=case take () of
             #"(" => let val value=alternative () in if take () = #")" then value else raise Pattern "unclosed group" end
           | #"[" => characterClass ()
           | #"." => Byte (fn c => dotAll orelse c<> #"\n")
           | #"^" => Start | #"$" => End
           | #"\\" => (case peek () of SOME #"d" => (ignore (take ());Byte Char.isDigit)
                 | SOME #"s" => (ignore (take ());Byte Char.isSpace)
                 | _ => let val c=escaped () in Byte (fn value => value=c) end)
           | #"*" => raise Pattern "unbound repetition" | #"+" => raise Pattern "unbound repetition"
           | #"?" => raise Pattern "unbound repetition" | #"{" => raise Pattern "bounded repetition is unsupported"
           | c => Byte (fn value => value=c)
        and characterClass ()=
          let val negative=peek ()=SOME #"^"
              val ()=if negative then ignore (take ()) else ()
              fun byte ()=case take () of #"\\" => escaped () | c => c
              fun members acc=case peek () of NONE => raise Pattern "unclosed character class" | SOME #"]" =>
                   (ignore (take ());if null acc then raise Pattern "empty character class" else acc)
                 | _ => let val lo=byte ()
                            val range=peek ()=SOME #"-" andalso !at+1<length andalso String.sub (source,!at+1)<> #"]"
                            val hi=if range then (ignore (take ());byte ()) else lo
                        in if lo>hi then raise Pattern "reversed character range" else members ((lo,hi)::acc) end
              val members=members []
          in Byte (fn c => List.exists (fn (lo,hi) => lo<=c andalso c<=hi) members <> negative) end
        val value=alternative ()
    in if !at=length then value else raise Pattern "unexpected closing group" end
  fun unique values =
    let fun loop [] _ acc=List.rev acc
          | loop (n::ns) seen acc=if List.exists (fn x => x=n) seen then loop ns seen acc else loop ns (n::seen) (n::acc)
    in loop values [] [] end
  fun descending []=[] | descending [n]=[n] | descending values=
    let val count=length values div 2
        fun merge ([],ys)=ys | merge (xs,[])=xs | merge (xs as x::xr,ys as y::yr)=if x>=y then x::merge (xr,ys) else y::merge (xs,yr)
    in merge (descending (List.take (values,count)),descending (List.drop (values,count))) end
  fun find expression text from =
    let val length=size text
        fun ends Empty i=[i]
          | ends (Byte accepts) i=if i<length andalso accepts (String.sub (text,i)) then [i+1] else []
          | ends Start i=if i=0 orelse String.sub (text,i-1) = #"\n" then [i] else []
          | ends End i=if i=length orelse String.sub (text,i) = #"\n" then [i] else []
          | ends (Sequence xs) i=List.foldl (fn (x,positions) => unique (List.concat (List.map (ends x) positions))) [i] xs
          | ends (Alternative xs) i=unique (List.concat (List.map (fn x => ends x i) xs))
          | ends (Optional x) i=unique (ends x i @ [i])
          | ends (Repeat x) i=
              let fun loop [] seen=seen
                    | loop (p::queue) seen=
                        let val next=List.filter (fn n => not (List.exists (fn old => old=n) seen)) (ends x p)
                        in loop (queue @ next) (next @ seen) end
              in descending (loop [i] [i]) end
        fun search i=if i>length then NONE else
              case ends expression i of [] => search (i+1) | last::_ => SOME (i,last)
    in search (Int.max (0,from)) end
end
