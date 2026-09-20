(* Bool *)
structure Bool =
struct
  datatype bool = datatype bool
  val not = not
  fun toString true = "true"
    | toString false = "false"

  (* "Ignoring case and initial whitespace, the sequences "true" and "false"
     are converted"; what follows the word is left in the stream. *)
  fun scan (getc : (char, 'a) StringCvt.reader) src =
    let
      fun lower c = if #"A" <= c andalso c <= #"Z" then chr (ord c + 32) else c
      (* the stream after the characters of word, if they are next *)
      fun word ([], src) = SOME src
        | word (w :: ws, src) =
          (case getc src of
             SOME (c, rest) => if lower c = w then word (ws, rest) else NONE
           | NONE => NONE)
      val src = StringCvt.skipWS getc src
    in
      case word ([#"t", #"r", #"u", #"e"], src) of
        SOME rest => SOME (true, rest)
      | NONE =>
          (case word ([#"f", #"a", #"l", #"s", #"e"], src) of
             SOME rest => SOME (false, rest)
           | NONE => NONE)
    end

  fun fromString s = StringCvt.scanString scan s
end
