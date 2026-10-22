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

  exception Error of string

  (* the words of a build file: comments dropped, strings kept whole *)
  datatype word = W of string | S of string
  fun words (path : string, text : string) : word list =
    let
      val n = String.size text
      fun at i = if i < n then String.sub (text, i) else #"\000"
      fun pathChar c = Char.isAlphaNum c orelse Char.contains "/._-+~" c
      (* a path: its characters, and $(NAME) whole *)
      fun scan j =
        if j < n andalso pathChar (at j) then scan (j + 1)
        else if j < n andalso at j = #"$" andalso at (j + 1) = #"(" then
          let fun close k = if k >= n then raise Error (path ^ ": a path variable that does not end")
                            else if at k = #")" then k else close (k + 1)
          in scan (close (j + 2) + 1) end
        else j
      fun go (i, depth, acc) =
        if i >= n then (if depth > 0 then raise Error (path ^ ": a comment that does not end") else List.rev acc)
        else if at i = #"(" andalso at (i + 1) = #"*" then go (i + 2, depth + 1, acc)
        else if depth > 0 then (if at i = #"*" andalso at (i + 1) = #")" then go (i + 2, depth - 1, acc) else go (i + 1, depth, acc))
        else if Char.isSpace (at i) then go (i + 1, 0, acc)
        else if at i = #"\"" then
          let fun close j = if j >= n then raise Error (path ^ ": a string that does not end")
                            else if at j = #"\"" then j else close (j + 1)
              val j = close (i + 1)
          in go (j + 1, 0, S (String.substring (text, i + 1, j - i - 1)) :: acc) end
        else if Char.contains ",=()" (at i) then go (i + 1, 0, W (String.str (at i)) :: acc)
        else if pathChar (at i) orelse at i = #"$" then
          let val j = scan i in go (j, 0, W (String.substring (text, i, j - i)) :: acc) end
        else raise Error (path ^ ": unexpected '" ^ String.str (at i) ^ "'")
    in go (0, 0, []) end

  val keywords = ["files", "group", "local", "in", "end", "library", "use", "implements", "annotate", "cache",
                  "libraries"]

  fun parse (path : string, text : string) : dec list =
    let
      val ws = ref (words (path, text))
      fun peek () = case !ws of w :: _ => SOME w | [] => NONE
      fun next () = case !ws of w :: rest => (ws := rest; w) | [] => raise Error (path ^ ": unexpected end of the file")
      fun expect s = case next () of W s' => if s' = s then () else raise Error (path ^ ": expected " ^ s ^ ", found " ^ s')
                                   | S s' => raise Error (path ^ ": expected " ^ s ^ ", found \"" ^ s' ^ "\"")
      fun pathWord () = case next () of
                          W s => if List.exists (fn k => k = s) keywords then raise Error (path ^ ": expected a path, found " ^ s) else s
                        | S s => s
      fun paths () = case peek () of
                       SOME (W "end") => (ignore (next ()); [])
                     | SOME _ => let val p = pathWord () in p :: paths () end
                     | NONE => raise Error (path ^ ": a list of files that does not end")
      fun decsUntil stops =
        case peek () of
          NONE => []
        | SOME (W s) => if List.exists (fn t => t = s) stops then [] else let val d = dec () in d :: decsUntil stops end
        | SOME (S _) => let val d = dec () in d :: decsUntil stops end
      and dec () =
        case next () of
          W "files" => Files (paths ())
        | W "group" => Group (paths ())
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
                          | _ => raise Error (path ^ ": an export is structure, signature, functor or type NAME")
                  val n = case next () of W n => n | S n => n
                in
                  case next () of
                    W "," => (k, n) :: export ()
                  | W ")" => [(k, n)]
                  | _ => raise Error (path ^ ": expected , or ) in the exports")
                end
              val es = export ()
              val () = expect "="
              val ds = decsUntil ["end"]
              val () = expect "end"
            in Library (es, ds) end
        | W "use" => Use (pathWord ())
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
        | W "cache" => Cache (pathWord ())
        | W "libraries" => Libraries (paths ())
        | W s => if List.exists (fn k => k = s) keywords then raise Error (path ^ ": unexpected " ^ s) else File s
        | S s => File s
    in
      let val ds = decsUntil []
      in case peek () of NONE => ds | SOME (W w) => raise Error (path ^ ": unexpected " ^ w) | SOME (S s) => raise Error (path ^ ": unexpected \"" ^ s ^ "\"") end
    end

  (* ---- paths ---- *)

  (* the path variables (--path NAME=DIR) *)
  val variables : string StringMap.map ref = ref StringMap.empty
  val () = CompilerState.cellRoot ("BuildFile.variables", variables)

  (* a path of a build file in dir, its variables given *)
  fun expandWith isAbsolute (dir : string, p : string) : string =
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
      if isAbsolute q orelse dir = "" orelse dir = "." then q else OS.Path.concat (dir, q)
    end
  fun expand args = expandWith OS.Path.isAbsolute args
end
