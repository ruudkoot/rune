(* Build files (docs/build.md; the incremental roadmap's M10, D16): their
   syntax, read into declarations, and their elaboration to what a build
   compiles -- each unit with the basis it is compiled in, given as a plan
   of steps that the units driver (Main) follows, a unit's basis being what
   the steps before it leave. The semantics is MLB's: a basis is a value, a
   file adds what it declares to the basis before it, `local` and export
   lists say what the files after see. *)
structure BuildFile =
struct
  (* ---- syntax ---- *)

  datatype kind = Str | Sig | Fun | Ty
  datatype dec =
      File of string                              (* a path, relative to the build file's directory *)
    | Files of string list
    | Group of string list
    | Local of dec list * dec list
    | Library of (kind * string) list * dec list
    | Use of string
    | Implements of string * dec list
    | Annotate of string list * dec list
    | Cache of string
    | Libraries of string list                   (* the libraries a library is written on *)
    | Inline of string list                      (* functors to inline across units (M6b) *)

  exception Error of string
  exception LocatedError of Source.span * string

  (* the words of a build file: comments dropped, strings kept whole *)
  datatype word = W of string | S of string
  type lexeme={word:word,start:int,stop:int}
  fun lexemes (path : string, text : string, recover : bool) : lexeme list =
    let
      val n = String.size text
      fun at i = if i < n then String.sub (text, i) else #"\000"
      fun error (start,stop,message)=raise LocatedError ({file=path,start=start,stop=stop},message)
      fun pathChar c = Char.isAlphaNum c orelse Char.contains "/._-+~" c
      (* a path: its characters, and $(NAME) whole *)
      fun scan j =
        if j < n andalso (pathChar (at j) orelse recover andalso Char.ord (at j)>=128) then scan (j + 1)
        else if j < n andalso at j = #"$" andalso at (j + 1) = #"(" then
          let fun close k = if k >= n then if recover then n else error (j,n,"a path variable that does not end")
                            else if at k = #")" then k else close (k + 1)
              val stop=close (j+2)
          in if stop=n then n else scan (stop+1) end
        else j
      fun go (i, depth, acc) =
        if i >= n then (if depth > 0 andalso not recover then error (n,n,"a comment that does not end") else List.rev acc)
        else if at i = #"(" andalso at (i + 1) = #"*" then go (i + 2, depth + 1, acc)
        else if depth > 0 then (if at i = #"*" andalso at (i + 1) = #")" then go (i + 2, depth - 1, acc) else go (i + 1, depth, acc))
        else if Char.isSpace (at i) then go (i + 1, 0, acc)
        else if at i = #"\"" then
          let fun close j = if j >= n then if recover then n else error (i,n,"a string that does not end")
                            else if at j = #"\"" then j else close (j + 1)
              val j = close (i + 1)
              val stop=if j=n then n else j+1
          in go (stop,0,{word=S (String.substring (text,i+1,j-i-1)),start=i,stop=stop} :: acc) end
        else if Char.contains ",=()" (at i) then go (i+1,0,{word=W (String.str (at i)),start=i,stop=i+1} :: acc)
        else if pathChar (at i) orelse at i = #"$" orelse recover andalso Char.ord (at i)>=128 then
          let val j=scan i
          in if j=i then if recover then go (i+1,0,{word=W (String.str (at i)),start=i,stop=i+1} :: acc)
                         else error (i,i+1,"unexpected '" ^ String.str (at i) ^ "'")
             else go (j,0,{word=W (String.substring (text,i,j-i)),start=i,stop=j} :: acc) end
        else if recover then go (i+1,0,{word=W (String.str (at i)),start=i,stop=i+1} :: acc)
        else error (i,i+1,"unexpected '" ^ String.str (at i) ^ "'")
    in go (0, 0, []) end
  fun words (path,text)=List.map #word (lexemes (path,text,false))
    handle LocatedError (_,message) => raise Error (path ^ ": " ^ message)

  val keywords = ["files", "group", "local", "in", "end", "library", "use", "implements", "annotate", "cache",
                  "libraries", "inline"]

  fun parseUsing {path,text,recover,pathAt,wanted} : dec list =
    let
      val ws = ref (lexemes (path,text,recover))
      val last=ref {file=path,start=0,stop=0}:Source.span ref
      fun peek () = case !ws of w :: _ => SOME (#word w) | [] => NONE
      fun next () = case !ws of w :: rest =>
            (ws:=rest;last:={file=path,start= #start w,stop= #stop w};#word w)
        | [] => raise LocatedError ({file=path,start=size text,stop=size text},"unexpected end of the file")
      fun error message=raise LocatedError (!last,message)
      fun expect s = case next () of W s' => if s' = s then () else error ("expected " ^ s ^ ", found " ^ s')
                                   | S s' => error ("expected " ^ s ^ ", found \"" ^ s' ^ "\"")
      fun want role=wanted (role,{file=path,start= #stop (!last),stop=case !ws of [] => size text | w::_ => #start w})
      fun reference (role,word)=
        (pathAt (role,word,!last);case word of W s => s | S s => s)
      fun pathWord role =
        (want role;case next () of word as W s =>
           if List.exists (fn k => k=s) keywords then error ("expected a path, found " ^ s) else reference (role,word)
         | word as S _ => reference (role,word))
      fun paths role = case peek () of
                       SOME (W "end") => (ignore (next ()); [])
                     | SOME _ => let val p = pathWord role in p :: paths role end
                     | NONE => (want role;raise LocatedError
                         ({file=path,start=size text,stop=size text},"a list of files that does not end"))
      fun decsUntil stops =
        case peek () of
          NONE => (want "source";[])
        | SOME (W s) => if List.exists (fn t => t = s) stops then [] else let val d = dec () in d :: decsUntil stops end
        | SOME (S _) => let val d = dec () in d :: decsUntil stops end
      and dec () =
        case next () of
          W "files" => Files (paths "source")
        | W "group" => Group (paths "source")
        | W "local" =>
            let val a = decsUntil ["in"] val () = expect "in" val b = decsUntil ["end"] val () = expect "end"
            in Local (a, b) end
        | W "library" =>
            let
              val () = expect "("
              fun export () =
                let
                  val k = case next () of
                            W "structure" => Str | W "signature" => Sig | W "functor" => Fun | W "type" => Ty
                          | _ => error "an export is structure, signature, functor or type NAME"
                  val n = case next () of W n => n | S n => n
                in
                  case next () of
                    W "," => (k, n) :: export ()
                  | W ")" => [(k, n)]
                  | _ => error "expected , or ) in the exports"
                end
              val es = export ()
              val () = expect "="
              val ds = decsUntil ["end"]
              val () = expect "end"
            in Library (es, ds) end
        | W "use" => Use (pathWord "build")
        | W "implements" =>
            let val n = case next () of W n => n | S n => n
                val () = expect "="
                val ds = decsUntil ["end"]
                val () = expect "end"
            in Implements (n, ds) end
        | W "annotate" =>
            let
              fun anns () = case peek () of SOME (S a) => (ignore (next ()); a :: anns ()) | _ => []
              val a = anns ()
              val () = expect "in"
              val ds = decsUntil ["end"]
              val () = expect "end"
            in Annotate (a, ds) end
        | W "cache" => Cache (pathWord "directory")
        | W "libraries" => Libraries (paths "library")
        | W "inline" =>
            let
              val () = expect "functor"
              fun names () = case next () of
                               W "end" => []
                             | W n => n :: names ()
                             | S n => n :: names ()
            in Inline (names ()) end
        | word as W s => if List.exists (fn k => k = s) keywords then error ("unexpected " ^ s) else File (reference ("source",word))
        | word as S _ => File (reference ("source",word))
    in
      let val ds = decsUntil []
      in case peek () of NONE => ds | SOME (W w) => error ("unexpected " ^ w) | SOME (S s) => error ("unexpected \"" ^ s ^ "\"") end
    end
  fun parse (path,text)=parseUsing {path=path,text=text,recover=false,pathAt=fn _ => (),wanted=fn _ => ()}
    handle LocatedError (_,message) => raise Error (path ^ ": " ^ message)

  (* ---- paths ---- *)

  (* the path variables (--path NAME=DIR) *)
  val variables : string StringMap.map ref = ref StringMap.empty
  val () = CompilerState.cellRoot ("BuildFile.variables", variables)

  (* a path of a build file in dir, its variables given *)
  fun expandUsing {isAbsolute,concat} (dir : string, p : string) : string =
    let
      val n = String.size p
      fun scan (i, acc) =
        if i >= n then String.concat (List.rev acc)
        else if String.sub (p, i) = #"$" andalso i + 1 < n andalso String.sub (p, i + 1) = #"(" then
          let
            fun close j = if j >= n then raise Error ("a path variable that does not end: " ^ p)
                          else if String.sub (p, j) = #")" then j else close (j + 1)
            val j = close (i + 2)
            val name = String.substring (p, i + 2, j - i - 2)
            val v = case StringMap.find (!variables, name) of
                      SOME v => v
                    | NONE => raise Error ("no path variable " ^ name ^ " (--path " ^ name ^ "=DIR)")
          in scan (j + 1, v :: acc) end
        else scan (i + 1, String.str (String.sub (p, i)) :: acc)
      val q = scan (0, [])
    in
      if isAbsolute q orelse dir = "" orelse dir = "." then q else concat (dir, q)
    end
  fun expandWith isAbsolute args=expandUsing {isAbsolute=isAbsolute,concat=OS.Path.concat} args
  fun expand args = expandWith OS.Path.isAbsolute args
end
