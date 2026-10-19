(* nofib's polynomial hash, with explicit GHC 64-bit Int wrapping semantics. *)
structure BenchNofibHash =
struct
  fun hash text =
    let fun loop (i,w) = if i=String.size text then w else
          loop(i+1,Word64.+(Word64.fromInt(Char.ord(String.sub(text,i))),Word64.*(w,0w31)))
    in loop(0,0w0) end
  fun signed text = IntInf.toString(Word64.toLargeIntX(hash text))
end
