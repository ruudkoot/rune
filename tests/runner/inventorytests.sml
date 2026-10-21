(* Versioned upstream fixtures and the existing handwritten inventory
   assertions. Expressions only select/compare JSON data; classification
   policy is a production operation, never duplicated in this controller. *)
structure InventoryTests =
struct
  open Sh
  exception Failed of string
  fun need (ok, why) = if ok then () else raise Failed why
  fun field name (Json.Object fields) =
        (case List.filter (fn (key, _) => key = name) fields of [(_, value)] => value
          | _ => raise Failed ("missing or repeated inventory fixture field " ^ name))
    | field _ _ = raise Failed "inventory fixture object required"
  fun array (Json.Array values) = values | array _ = raise Failed "inventory fixture array required"
  fun string (Json.String value) = value | string _ = raise Failed "inventory fixture string required"
  fun integer value = case Json.toInt value of SOME value => value | NONE => raise Failed "inventory fixture integer required"
  fun object (Json.Object fields) = fields | object _ = raise Failed "inventory fixture object required"
  fun maybe name (Json.Object fields) = List.find (fn (key, _) => key = name) fields
    | maybe _ _ = NONE
  fun equal (Json.Object left, Json.Object right) =
        length left = length right andalso List.all (fn (key, value) =>
            case List.find (fn (name, _) => name = key) right of SOME (_, other) => equal (value, other) | NONE => false) left
    | equal (Json.Array left, Json.Array right) =
        length left = length right andalso ListPair.allEq equal (left, right)
    | equal (left, right) = left = right
  fun truth Json.Null = false | truth (Json.Bool value) = value
    | truth (Json.String value) = value <> "" | truth (Json.Array values) = not (null values)
    | truth (Json.Object values) = not (null values) | truth (Json.Number value) = value <> "0"
  fun replace text from into =
    let fun loop text =
          let val (prefix, suffix) = Substring.position from (Substring.full text)
          in if Substring.isEmpty suffix then text else Substring.string prefix ^ into
                   ^ loop (Substring.string (Substring.triml (size from) suffix)) end
    in loop text end
  fun resolve mappings text = List.foldl (fn ((from, into), text) => replace text from into) text mappings
  fun literals mappings (Json.String text) = Json.String (resolve mappings text)
    | literals mappings (Json.Array values) = Json.Array (List.map (literals mappings) values)
    | literals mappings (Json.Object fields) = Json.Object (List.map (fn (key, value) => (key, literals mappings value)) fields)
    | literals _ value = value
  fun split text separator =
    let val () = need (separator <> "", "empty fixture split separator")
        fun loop text = let val (prefix, suffix) = Substring.position separator (Substring.full text)
                        in if Substring.isEmpty suffix then [text] else Substring.string prefix
                             :: loop (Substring.string (Substring.triml (size separator) suffix)) end
    in loop text end
  fun evaluate results mappings expression =
    let fun eval item value =
      let fun go value = eval item value
      in case string (field "op" value) of
        "literal" => literals mappings (field "value" value)
      | "query" => field "value" (List.nth (!results, integer (field "index" value)))
      | "get" =>
          (case (go (field "value" value), field "key" value) of
             (Json.Array values, Json.Number index) => List.nth (values, valOf (Int.fromString index))
           | (row as Json.Object _, Json.String key) => field key row
           | _ => raise Failed "invalid fixture selection")
      | "item" => (case item of SOME value => value | NONE => raise Failed "fixture map item is unbound")
      | "map" => Json.Array (List.map (fn item => eval (SOME item) (field "body" value)) (array (go (field "value" value))))
      | "every" => Json.Bool (List.all truth (array (go (field "value" value))))
      | "asObject" => Json.Object (List.map (fn row => case array row of [key, value] => (string key, value)
                | _ => raise Failed "invalid mapped object entry") (array (go (field "value" value))))
      | "asSet" =>
          let val encoded = sort (List.map Json.encode (array (go (field "value" value))))
              fun unique (a :: (rest as b :: _)) = if a = b then unique rest else a :: unique rest
                | unique xs = xs
          in Json.Array (List.map Json.decode (unique encoded)) end
      | "array" => Json.Array (List.map go (array (field "items" value)))
      | "object" => Json.Object (List.map (fn (key, value) => (key, go value)) (object (field "fields" value)))
      | "update" =>
          let val base = object (go (field "value" value))
              val edits = List.map (fn (key, value) => (key, go value)) (object (field "fields" value))
          in Json.Object (List.filter (fn (key, _) => not (List.exists (fn (name, _) => name = key) edits)) base @ edits) end
      | "length" => Json.Number (Int.toString (case go (field "value" value) of
               Json.Array values => length values | Json.Object fields => length fields
             | Json.String text => size text | _ => raise Failed "invalid fixture length"))
      | "split" => Json.Array (List.map Json.String (split (string (go (field "value" value))) (string (field "separator" value))))
      | "equal" => Json.Bool (equal (go (field "left" value), go (field "right" value)))
      | "notEqual" => Json.Bool (not (equal (go (field "left" value), go (field "right" value))))
      | "all" => Json.Bool (List.all (truth o go) (array (field "items" value)))
      | "set" =>
          let val items = List.map go (array (field "items" value))
              val encoded = sort (List.map Json.encode items)
          in Json.Array (List.map Json.decode encoded) end
      | name => raise Failed ("unknown inventory assertion expression " ^ name)
      end
    in eval NONE expression end
  fun fixture directory mappings value =
    let val () = rmTree directory
        val () = mkdirs directory
        fun valid path = need (BenchCases.relative path, "invalid inventory fixture path " ^ path)
        val () = List.app (fn row => let val path = string row in valid path; mkdirs (directory ^ "/" ^ path) end)
                           (array (field "directories" value))
        val () = List.app (fn row =>
          let val path = string (field "path" row)
              val () = valid path
              val bytes = case Hex.toBytes (string (field "hex" row)) of SOME bytes => bytes
                            | NONE => raise Failed "invalid binary inventory fixture"
              val () = mkdirs (OS.Path.dir (directory ^ "/" ^ path))
          in write (directory ^ "/" ^ path, resolve mappings bytes) end) (array (field "files" value))
    in () end
  fun runCase row =
    let val name = string (field "name" row)
        val dir = run ^ "/inventory-tests/" ^ name
        val () = mkdirs dir
        val results = ref [] : Json.value list ref
        val mappings = ref [] : (string * string) list ref
        fun query (i, value) =
          let val data = field "fixture" value
              val outside = array (field "outside" data)
              val paths = List.tabulate (length outside, fn i => dir ^ "/outside-" ^ Int.toString i)
              val () = mappings := ("$ROOT", dir ^ "/pinned") :: List.map
                      (fn (i, path) => ("$OUT" ^ Int.toString i, path)) (ListPair.zip (List.tabulate (length paths, fn i => i), paths))
              val () = fixture (dir ^ "/pinned") (!mappings) (field "root" data)
              val () = List.app (fn (path, tree) => fixture path (!mappings) tree) (ListPair.zip (paths, outside))
              val fields = List.map (fn (key, value) => (key, evaluate results (!mappings) value)) (object (field "arguments" value))
              val request = Json.Object [("operation", field "operation" value), ("arguments", Json.Object fields)]
              val input = dir ^ "/query-" ^ Int.toString i ^ ".json"
              val output = dir ^ "/answer-" ^ Int.toString i ^ ".json"
              val () = write (input, Json.encode request)
              val tool = env ("RUNE_INVENTORY_TOOL", "")
              val command = if tool = "" then ["python3", fromRoot "scripts/benchmark-inventory.py", "--query"]
                            else [fromRoot tool, "--query"]
              val status = Children.exec {addressSpace = SOME (1024 * 1024 * 1024), cpuTime = SOME 60,
                                          fileSize = SOME (16 * 1024 * 1024), core = SOME 0} (fn e => e)
                {cmd = command, dir = SOME root, stdin = input,
                 stdout = output, stderr = output ^ ".err", timeout = 60}
              val () = need (status = 0, "inventory operation failed: " ^ firstNonEmpty (output ^ ".err"))
              val answer = Json.decode (read output)
              val () = need (isSome (maybe "value" answer) <> isSome (maybe "error" answer), "invalid inventory reply envelope")
          in results := !results @ [answer] end
        val queries = array (field "queries" row)
        val () = List.app query (ListPair.zip (List.tabulate (length queries, fn i => i), queries))
        fun contains (item, Json.String text) = String.isSubstring (string item) text
          | contains (item, Json.Array values) = List.exists (fn value => equal (item, value)) values
          | contains (Json.String key, Json.Object values) = List.exists (fn (name, _) => name = key) values
          | contains _ = raise Failed "invalid inventory containment assertion"
        fun assertion value =
          let val opName = string (field "op" value)
              val args = case maybe "arguments" value of SOME (_, values) => List.map (evaluate results (!mappings)) (array values) | NONE => []
              val valid = case (opName, args) of
                  ("equal", [left, right]) => equal (left, right)
                | ("notEqual", [left, right]) => not (equal (left, right))
                | ("contains", [item, container]) => contains (item, container)
                | ("notContains", [item, container]) => not (contains (item, container))
                | ("truth", [value]) => truth value
                | ("errorContains", []) => let val reply = List.nth (!results, integer (field "query" value))
                                          in String.isSubstring (string (field "text" value)) (string (field "error" reply)) end
                | _ => raise Failed "invalid inventory assertion"
          in need (valid, name ^ ": handwritten assertion failed: " ^ Json.encode value) end
        val assertions = array (field "assertions" row)
        val () = List.app assertion assertions
    in say ("PASS " ^ name ^ " (" ^ Int.toString (length assertions) ^ " assertions)\n") end
  fun cases () = array (field "cases" (Json.decode (read (fromRoot "tests/runner/inventory-cases.json"))))
  fun one name = case List.find (fn row => string (field "name" row) = name) (cases ()) of SOME row => runCase row
                                        | NONE => raise Failed ("unknown inventory test " ^ name)
  fun faults () =
    let val original = hd (cases ())
        val checks = array (field "assertions" original)
        val first = hd checks
        val changed = Json.Object (("op", Json.String (if string (field "op" first) = "notContains" then "contains" else "notContains"))
                                     :: List.filter (fn (key, _) => key <> "op") (object first))
        val planted = Json.Object (("name", Json.String "planted-wrong-expectation") :: ("assertions", Json.Array (changed :: tl checks))
                         :: List.filter (fn (key, _) => key <> "name" andalso key <> "assertions") (object original))
        val rejected = ((runCase planted; false) handle Failed _ => true)
        val () = need (rejected, "inventory controller accepted a wrong handwritten expectation")
        val dir = run ^ "/inventory-controller-faults"
        val () = mkdirs dir
        val fake = dir ^ "/inventory"
        fun script rows =
          let val reply = Json.encode (Json.Object [("value", Json.Array rows)])
          in write (fake, "#!/bin/sh\nprintf '%s\\n' " ^ quote reply ^ "\n");
             Posix.FileSys.chmod (fake, Posix.FileSys.S.flags [Posix.FileSys.S.irusr, Posix.FileSys.S.iwusr, Posix.FileSys.S.ixusr]) end
        val healthy = Json.Object [("path", Json.String "gc/hash"), ("disposition", Json.String "import")]
        val invented = Json.Object [("path", Json.String "gc/invented"), ("disposition", Json.String "import")]
        fun attempt name rows =
          let val () = script rows
              val status = Children.exec {addressSpace = NONE, cpuTime = SOME 60, fileSize = SOME (1024 * 1024), core = SOME 0}
                  (setEnv ("RUNE_INVENTORY_TOOL", fake) o setEnv ("RUNE_TEST_RUN", dir ^ "/" ^ name))
                {cmd = [fromRoot "bin/runevm", fromRoot (env ("RUNE_INVENTORY_PAYLOAD", "bin/rune-bench-check.rbc")),
                        "inventory-one", "test_haskell_main_need_not_be_named_Main"],
                 dir = SOME root, stdin = "", stdout = dir ^ "/" ^ name ^ ".out", stderr = dir ^ "/" ^ name ^ ".err", timeout = 60}
          in status end
        val () = need (attempt "healthy" [healthy] = 0, "healthy inventory reply was rejected")
    in need (attempt "invented-row" [healthy, invented] <> 0, "inventory controller truncated a comprehended result") end
  fun command ["inventory-one", name] = SOME (fn () => one name)
    | command ["inventory-faults"] = SOME faults
    | command _ = NONE
end
