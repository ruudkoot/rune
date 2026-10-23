(* Implements: C_PREPROCESS *)
structure CPreprocess : C_PREPROCESS =
struct
  type resolver = {from : string, name : string, system : bool, next : bool} -> {file : string, text : string} option
  type macro = {name : string, parameters : string list option, variadic : bool,
                body : CLex.token list, location : CLex.location}
  exception Error of CLex.location * string
  type marked = {token : CLex.token, hide : string list}
  fun run {source, predefined, resolve, width, maxDepth, maxExpansions} =
    let
      (* Headers contain thousands of names. Lookup must not scan every
         previously defined macro for each identifier. Bucket arithmetic
         stays below a 31-bit SML int on every host. Definition order is
         retained separately from the table's traversal order. *)
      val table = Array.array (4093, [] : (string * macro * int) list)
      val definitions = ref ([] : (macro * int) list)
      val serial = ref 0
      fun hash name = CharVector.foldl (fn (c, n) => (n * 33 + Char.ord c) mod 4093) 0 name
      fun entry name = List.find (fn (n, _, _) => n = name) (Array.sub (table, hash name))
      val dependencies = ref ([] : string list)
      val once = ref ([] : string list)
      val expansions = ref 0
      val counter = ref 0
      fun contains xs x = List.exists (fn y => x = y) xs
      fun union (a, b) = List.foldl (fn (x, xs) => if contains xs x then xs else x :: xs) b a
      fun error (t : CLex.token) message = raise Error (CLex.diagnostic (t, message))
      fun origins (invocation : CLex.token) (body : CLex.token) =
        (if null (#origins invocation) then [#location invocation]
         else #origins invocation @ [#location invocation]) @ #origins body
      fun fallback file : CLex.token = {kind = CLex.Punctuation, text = "", space = true,
        location = {file = file, line = 1, column = 1}, origins = []}
      fun text ({token, ...} : marked) = #text token
      fun mark t : marked = {token = t, hide = []}
      fun fresh (t : CLex.token) kind spelling : CLex.token =
        {kind = kind, text = spelling, space = #space t, location = #location t, origins = #origins t}
      fun find name = case entry name of SOME (_, m, _) => SOME m | NONE => NONE
      fun builtin name = contains ["__LINE__", "__FILE__", "__COUNTER__", "__has_include"] name
      fun defined name = builtin name orelse isSome (find name)
      fun remove name = let val i = hash name
        in Array.update (table, i, List.filter (fn (n, _, _) => n <> name) (Array.sub (table, i))) end
      fun significant tokens = List.filter (fn (t : CLex.token) => #kind t <> CLex.Newline) tokens
      fun stringLiteral s = "\"" ^ String.translate (fn #"\\" => "\\\\" | #"\"" => "\\\"" | #"\n" => "\\n" | c => str c) s ^ "\""
      fun unquote (t : CLex.token) =
        if #kind t = CLex.StringLiteral andalso String.isPrefix "\"" (#text t) then
          String.substring (#text t, 1, size (#text t) - 2) else error t "expected quoted header name"
      fun add (m : macro) =
        let fun equal (a : CLex.token list, b : CLex.token list) = List.map #text a = List.map #text b
        in case find (#name m) of NONE =>
            let val i = hash (#name m) val id = !serial val () = serial := id + 1
            in Array.update (table, i, (#name m, m, id) :: Array.sub (table, i));
               definitions := (m, id) :: !definitions end
          | SOME old => if #parameters old = #parameters m andalso #variadic old = #variadic m andalso equal (#body old, #body m)
                        then () else raise Error (#location m, "incompatible macro redefinition: " ^ #name m) end
      val savedMacros = ref ([] : (string * macro option) list)
      fun pragmaEffect first tokens =
        case tokens of operation :: openToken :: literal :: close :: [] =>
          if (#text operation = "push_macro" orelse #text operation = "pop_macro") andalso
             #text openToken = "(" andalso #text close = ")" then
            let val name = unquote literal
            in if #text operation = "push_macro" then savedMacros := (name, find name) :: !savedMacros
               else
                 let fun restore ([], _) = error first ("unmatched pop_macro: " ^ name)
                       | restore ((key, value) :: rest, prefix) =
                         if key = name then
                           (savedMacros := rev prefix @ rest; remove name;
                            case value of NONE => () | SOME m => add m)
                         else restore (rest, (key, value) :: prefix)
                 in restore (!savedMacros, []) end;
               true end
          else false
        | _ => false
      fun arguments first input =
        let fun loop ([], _, _, _) = error first "unterminated macro arguments"
              | loop ((m : marked) :: rest, depth, current, args) =
                if text m = ")" andalso depth = 0 then (rev (rev current :: args), rest, m)
                else if text m = "," andalso depth = 0 then loop (rest, depth, [], rev current :: args)
                else loop (rest, if text m = "(" then depth + 1 else if text m = ")" then depth - 1 else depth,
                           m :: current, args)
        in loop (input, 0, [], []) end
      fun header (first : CLex.token) tokens =
        case tokens of
          [t] => (unquote t, false)
        | t :: rest => if #text t = "<" then
            let fun go ([], _) = error first "unterminated angle header name"
                  | go ([last], acc) = if #text last = ">" then (String.concat (rev acc), true) else error last "invalid header name"
                  | go (t :: tail, acc) = go (tail, #text t :: acc)
            in go (rest, []) end
          else error first "invalid include operand"
        | [] => error first "missing include operand"
      fun expand input =
        let
          fun go ([], result) = rev result
            | go ((m as {token = t, hide} : marked) :: rest, result) =
              let val name = #text t
                  fun output () = go (rest, m :: result)
                  fun invocation () = case #origins t of p :: _ => p | [] => #location t
                  fun use tokens after =
                    let val () = expansions := !expansions + 1
                        val () = if !expansions <= maxExpansions then () else error t "macro expansion limit exceeded"
                    in go (tokens @ after, result) end
                  fun inherit ({token = b, hide = h} : marked) : marked =
                    {token = {kind = #kind b, text = #text b, space = #space b,
                      location = #location b, origins = origins t b}, hide = union (name :: hide, h)}
              in if #kind t <> CLex.Identifier orelse contains hide name then output ()
                else if name = "__LINE__" then use [mark (fresh t CLex.Number (Int.toString (#line (invocation ()))))] rest
                else if name = "__FILE__" then use [mark (fresh t CLex.StringLiteral (stringLiteral (#file (invocation ()))))] rest
                else if name = "__COUNTER__" then
                  let val n = !counter val () = counter := n + 1
                  in use [mark (fresh t CLex.Number (Int.toString n))] rest end
                else if name = "_Pragma" orelse name = "__pragma" then
                  (case rest of openToken :: tail => if text openToken = "(" then
                    let val (args, after, _) = arguments t tail
                        val body = List.map #token (expand (List.concat args))
                        fun destring s =
                          let fun go [] = []
                                | go (#"\\" :: c :: cs) = if c = #"\\" orelse c = #"\"" then c :: go cs else #"\\" :: c :: go cs
                                | go (c :: cs) = c :: go cs
                          in String.implode (go (String.explode s)) end
                        val body = if name = "__pragma" then body else
                          case body of [literal] => CLex.scan {file = #file (invocation ()), text = destring (unquote literal)}
                            | _ => error t "_Pragma requires one string literal"
                        val directive = [mark (fresh t CLex.Newline "\n"), mark (fresh t CLex.Punctuation "#"), mark (fresh t CLex.Identifier "pragma")]
                          @ List.map mark body @ [mark (fresh t CLex.Newline "\n")]
                    in use (if pragmaEffect t body then [] else directive) after end else error t "expected pragma parentheses"
                   | [] => error t "expected pragma parentheses")
                else if name = "__has_include" then
                  (case rest of openToken :: tail => if text openToken = "(" then
                    let val (args, after, _) = arguments t tail
                        val raw = List.concat args
                        val operand = case raw of first :: _ =>
                          if #kind (#token first) = CLex.StringLiteral orelse text first = "<" then raw else expand raw
                          | [] => []
                        val (path, system) = header t (List.map #token operand)
                        val found = isSome (resolve {from = #file (invocation ()), name = path, system = system, next = false})
                    in use [mark (fresh t CLex.Number (if found then "1" else "0"))] after end
                    else error t "expected __has_include(...)" | [] => error t "expected __has_include(...)" )
                else case find name of NONE => output ()
                  | SOME macro => case #parameters macro of
                      NONE => use (List.map (inherit o mark) (#body macro)) rest
                    | SOME parameters =>
                      (case rest of openToken :: tail => if text openToken <> "(" then output () else
                        let val (args0, after, close) = arguments t tail
                            val args = if null parameters andalso not (#variadic macro) andalso
                              length args0 = 1 andalso null (hd args0) then [] else args0
                            val fixed = length parameters
                            val () = if (not (#variadic macro) andalso length args = fixed) orelse
                              (#variadic macro andalso length args >= fixed) then () else error t "macro argument count mismatch"
                            val bindings = ListPair.zip (parameters, List.take (args, fixed))
                            val comma = mark (fresh t CLex.Punctuation ",")
                            fun join [] = [] | join [x] = x | join (x :: xs) = x @ (comma :: join xs)
                            val bindings = if #variadic macro then bindings @ [("__VA_ARGS__", join (List.drop (args, fixed)))] else bindings
                            fun lookup s = case List.find (fn (n, _) => n = s) bindings of SOME (_, a) => SOME a | NONE => NONE
                            fun raw s = getOpt (lookup s, [])
                            fun placeholder () = mark (fresh t CLex.Punctuation "")
                            fun pastedArg s = case raw s of [] => [placeholder ()] | xs => xs
                            fun stringify arg =
                              let fun collect ([], _) = ""
                                    | collect (m :: ms, first) =
                                      (if first orelse not (#space (#token m)) then "" else " ") ^ text m ^ collect (ms, false)
                              in mark (fresh t CLex.StringLiteral (stringLiteral (collect (arg, true)))) end
                            fun substitute ([], _) = []
                              | substitute (b :: body, previousPaste) =
                                if #text b = "#" then
                                  (case body of param :: more => if isSome (lookup (#text param)) then stringify (raw (#text param)) :: substitute (more, false)
                                    else error b "stringification operand is not a parameter"
                                   | [] => error b "missing stringification operand")
                                else if #text b = "##" then mark b :: substitute (body, true)
                                else case lookup (#text b) of
                                  NONE => mark b :: substitute (body, false)
                                | SOME arg => (if previousPaste orelse (case body of next :: _ => #text next = "##" | _ => false)
                                    then pastedArg (#text b) else expand arg) @ substitute (body, false)
                            fun paste ([], acc) = rev acc
                              | paste (m :: ms, acc) = if text m <> "##" then paste (ms, m :: acc) else
                                  (case (acc, ms) of (left :: prefix, right :: tail) =>
                                    let val combined = text left ^ text right
                                        val lexed = if combined = "" then [placeholder ()] else
                                          (List.map mark (significant (CLex.scan {file = #file (#location t), text = combined}))
                                            handle CLex.Error _ => error (#token m) "token paste does not form one token")
                                        val token = case lexed of [one] => one | _ => error (#token m) "token paste does not form one token"
                                        val pasted = {token = fresh (#token left) (#kind (#token token)) combined,
                                                      hide = union (#hide left, #hide right)}
                                    in paste (tail, pasted :: prefix) end
                                   | _ => error (#token m) "token paste at replacement boundary")
                            val replaced = List.filter (fn m => text m <> "") (paste (substitute (#body macro, false), []))
                            (* C's function invocation hide set is the intersection
                               at the opening name and closing parenthesis. *)
                            val shared = List.filter (contains (#hide close)) hide
                            fun inheritFunction ({token = b, hide = h} : marked) : marked =
                              {token = {kind = #kind b, text = #text b, space = #space b,
                                location = #location b, origins = origins t b},
                               hide = union (name :: shared, h)}
                        in use (List.map inheritFunction replaced) after end
                       | [] => output ())
              end
        in go (input, []) end
      fun expandTokens ts = List.map #token (expand (List.map mark (significant ts)))
      fun define first tokens =
        case tokens of
          [] => error first "missing macro name"
        | (name : CLex.token) :: rest =>
          if #kind name <> CLex.Identifier orelse builtin (#text name) then error name "invalid macro name" else
          let fun params ([], _) = error name "unterminated macro parameter list"
                | params (t :: tail, acc) =
                  if #text t = ")" then (rev acc, false, tail)
                  else if #text t = "..." then (case tail of close :: more => if #text close = ")" then (rev acc, true, more)
                    else error close "expected ')' after ellipsis" | [] => error t "expected ')' after ellipsis")
                  else if #kind t <> CLex.Identifier orelse contains acc (#text t) then error t "invalid or duplicate macro parameter"
                  else case tail of separator :: more =>
                    if #text separator = "," then
                      (case more of close :: _ => if #text close = ")" then error close "trailing comma in macro parameters"
                        else params (more, #text t :: acc) | [] => error separator "unterminated macro parameters")
                    else if #text separator = ")" then (rev (#text t :: acc), false, more)
                    else error separator "expected ',' or ')' in macro parameters"
                   | [] => error t "unterminated macro parameters"
              val (parameters, variadic, body) = case rest of openToken :: tail =>
                if #text openToken = "(" andalso not (#space openToken) then
                  let val (ps, v, b) = params (tail, []) in (SOME ps, v, b) end else (NONE, false, rest)
               | [] => (NONE, false, [])
              val () = if List.exists (fn t => #text t = "##") (case body of [] => [] | x :: _ => [x]) orelse
                (case rev body of t :: _ => #text t = "##" | [] => false) then error name "token paste at replacement boundary" else ()
          in add {name = #text name, parameters = parameters, variadic = variadic, body = body, location = #location name} end
      val () = List.app (fn (name, replacement) => define (fallback "<predefined>")
        (significant (CLex.scan {file = "<predefined>", text = name ^ " " ^ replacement}))) predefined
      fun condition first tokens =
        let fun replace [] = []
              | replace ((t : CLex.token) :: ts) =
                if #text t <> "defined" then t :: replace ts else
                  let val (name, after) = case ts of openToken :: name :: close :: tail =>
                        if #text openToken = "(" andalso #text close = ")" then (name, tail)
                        else (case ts of name :: tail => (name, tail) | [] => error t "expected defined identifier")
                      | name :: tail => (name, tail) | [] => error t "expected defined identifier"
                      val () = if #kind name = CLex.Identifier then () else error name "invalid defined operand"
                  in fresh t CLex.Number (if defined (#text name) then "1" else "0") :: replace after end
            val value = CConst.evaluate {width = width, lookup = fn _ => SOME {integer = 0, unsigned = false},
                                        tokens = expandTokens (replace tokens)}
        in #integer value <> 0 end
      fun file depth {file = path, text = bytes} =
        if contains (!once) path then []
        else if depth > maxDepth then raise Error (#location (fallback path), "include nesting limit exceeded")
        else
        let
          val () = if contains (!dependencies) path then () else dependencies := !dependencies @ [path]
          val scanned = CLex.scan {file = path, text = bytes}
          fun lines ([], [], acc) = rev acc
            | lines ([], line, acc) = rev (rev line :: acc)
            | lines ((t : CLex.token) :: ts, line, acc) = if #kind t = CLex.Newline then lines (ts, [], rev line :: acc)
              else lines (ts, t :: line, acc)
          val conditions = ref ([] : {parent : bool, taken : bool, active : bool, otherwise : bool} list)
          fun active () = case !conditions of [] => true | c :: _ => #active c
          fun enter test = let val parent = active () val value = parent andalso test ()
            in conditions := {parent = parent, taken = value, active = value, otherwise = false} :: !conditions end
          fun branch first test isElse = case !conditions of [] => error first "unmatched conditional directive"
            | c :: rest => if #otherwise c then error first "conditional after #else" else
              let val value = #parent c andalso not (#taken c) andalso test ()
              in conditions := {parent = #parent c, taken = #taken c orelse value, active = value, otherwise = isElse} :: rest end
          fun flush (pending, result) = rev (expandTokens (rev pending)) @ result
          fun process ([], pending, result) =
                if null (!conditions) then rev (flush (pending, result)) else error (fallback path) "unterminated conditional directive"
            | process (line :: rest, pending, result) =
              case line of
                hash :: directive :: args => if #text hash = "#" orelse #text hash = "%:" then
                  let val result = flush (pending, result)
                      val name = #text directive
                      fun singleName () = case args of [t] => if #kind t = CLex.Identifier then #text t
                        else error t "expected identifier" | _ => error directive "expected one identifier"
                      val output =
                        if name = "if" then (enter (fn () => condition directive args); [])
                        else if name = "ifdef" then (enter (fn () => defined (singleName ())); [])
                        else if name = "ifndef" then (enter (fn () => not (defined (singleName ()))); [])
                        else if name = "elif" then (branch directive (fn () => condition directive args) false; [])
                        else if name = "else" then (if null args then () else error directive "tokens after #else";
                          branch directive (fn () => true) true; [])
                        else if name = "endif" then (if null args then () else error directive "tokens after #endif";
                          case !conditions of [] => error directive "unmatched #endif" | _ :: tail => conditions := tail; [])
                        else if not (active ()) then []
                        else if name = "define" then (define directive args; [])
                        else if name = "undef" then (remove (singleName ()); [])
                        else if name = "include" orelse name = "include_next" then
                          let val operand = case args of first :: _ =>
                                if #kind first = CLex.StringLiteral orelse #text first = "<" then args else expandTokens args
                                | [] => []
                              val (name, system) = header directive operand
                          in case resolve {from = path, name = name, system = system, next = #text directive = "include_next"} of
                            SOME source => file (depth + 1) source | NONE => error directive ("include not found: " ^ name) end
                        else if name = "error" then error directive ("#error " ^ CLex.spelling args)
                        else if name = "pragma" then
                          if (case args of [t] => #text t = "once" | _ => false) then (once := path :: !once; [])
                          else let val body = expandTokens args
                               in if pragmaEffect directive body then []
                                  else fresh directive CLex.Newline "\n" :: hash :: directive :: body @ [fresh directive CLex.Newline "\n"] end
                        else error directive ("unsupported preprocessing directive: " ^ name)
                  in process (rest, [], rev output @ result) end
                  else if active () then process (rest, rev line @ pending, result) else process (rest, pending, result)
              | [hash] => if #text hash = "#" orelse #text hash = "%:" then process (rest, [], flush (pending, result))
                         else if active () then process (rest, hash :: pending, result) else process (rest, pending, result)
              | [] => process (rest, pending, result)
        in process (lines (scanned, [], []), [], []) end
      val tokens = file 0 source
      val macros = List.mapPartial (fn (m : macro, id) => case entry (#name m) of
        SOME (_, _, current) => if current = id then SOME m else NONE | NONE => NONE) (rev (!definitions))
    in {tokens = tokens, dependencies = !dependencies, macros = macros} end
    handle CLex.Error p => raise Error p | CConst.Error p => raise Error p
end
