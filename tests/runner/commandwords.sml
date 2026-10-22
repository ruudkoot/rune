(* Command option strings are parsed as words, without executing expansions.
   This preserves quotes, escaped spaces and empty arguments of shlex.split. *)
structure CommandWords =
struct
  exception Invalid of string
  datatype mode = Plain | Single | Double
  fun split text =
    let val n=size text
        fun done (word,started,words)=List.rev (if started then String.implode (List.rev word) :: words else words)
        fun loop (i,mode,word,started,words)=
          if i=n then (case mode of Plain => done (word,started,words) | _ => raise Invalid "unterminated command quote") else
          let val ch=String.sub (text,i)
          in case mode of
            Single => if ch = #"'" then loop (i+1,Plain,word,true,words) else loop (i+1,Single,ch :: word,true,words)
          | Double => if ch = #"\"" then loop (i+1,Plain,word,true,words)
              else if ch = #"\\" then if i+1=n then raise Invalid "unterminated command escape" else
                let val next=String.sub (text,i+1)
                in if next = #"\"" orelse next = #"\\" then loop (i+2,Double,next :: word,true,words)
                   else loop (i+1,Double,ch :: word,true,words) end
              else loop (i+1,Double,ch :: word,true,words)
          | Plain => if Char.isSpace ch then loop (i+1,Plain,[],false,if started then String.implode (List.rev word) :: words else words)
              else if ch = #"'" then loop (i+1,Single,word,true,words)
              else if ch = #"\"" then loop (i+1,Double,word,true,words)
              else if ch = #"\\" then if i+1=n then raise Invalid "unterminated command escape"
                   else loop (i+2,Plain,String.sub (text,i+1) :: word,true,words)
              else loop (i+1,Plain,ch :: word,true,words)
          end
    in loop (0,Plain,[],false,[]) end
end
