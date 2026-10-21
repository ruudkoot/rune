(* The independent consumer of the JIT's index, role lists, machine bytes
   and perf jitdump stream. All offsets are checked before a binary read. *)
structure JitDumpCheck =
struct
  open HeapChecks
  val roles = ["body", "count", "poll", "writeback", "args", "room", "frameroom", "frame", "jump",
               "fill", "land", "ret", "slow", "sync", "closure", "ptrload", "tag", "alloc"]
  val callRoles = ["count", "body", "writeback", "args", "room", "frame", "jump", "ret", "land", "slow"]
  type part = {offset : int, role : string}
  type function = {sequence : string, address : IntInf.int, bytes : string, tier : string, name : string, parts : part vector}
  fun binary path =
    let val input = BinIO.openIn path
    in (Byte.bytesToString (BinIO.inputAll input) before BinIO.closeIn input)
       handle e => (BinIO.closeIn input; raise e) end
  fun hex s = case StringCvt.scanString (IntInf.scan StringCvt.HEX) s of SOME n => n | NONE => raise Failed ("invalid hexadecimal address " ^ s)
  fun readIndex dir =
    let val seen = ref [] : string list ref
        fun one (i, line) =
          let val fields = String.fields (fn c => c = #"\t") line
              val () = need (length fields = 10, "JIT index row has the wrong width")
              val seq = hd fields
              val () = need (seq = StringCvt.padLeft #"0" 5 (Int.toString i), "JIT index sequence is out of order")
              val code = binary (dir ^ "/" ^ seq ^ ".bin")
              val () = need (IntInf.fromInt (size code) = number (List.nth (fields, 4)), "JIT byte count differs from index")
              val previous = ref ~1
              (* Keep the function row separate from each part's columns. *)
              val fib = List.nth (fields, 9) = "fib"
              fun readPart line =
                let val ps = String.fields (fn c => c = #"\t") line
                    val () = need (length ps >= 3, "JIT part row has the wrong width")
                    val off = IntInf.toInt (number (hd ps))
                    val role = List.nth (ps, 2)
                    val () = need (List.exists (fn r => r = role) roles, "unknown JIT role " ^ role)
                    val () = need (off > !previous andalso off < size code andalso (!previous >= 0 orelse off = 0), "JIT part offset outside code or out of order")
                    val () = previous := off
                    val () = if fib then seen := role :: !seen else ()
                in {offset = off, role = role} : part end
              val parts = Vector.fromList (List.map readPart (lines (read (dir ^ "/" ^ seq ^ ".lst"))))
              val () = need (Vector.length parts > 0, "JIT function has no role parts")
          in {sequence = seq, address = hex (List.nth (fields, 3)), bytes = code,
              tier = List.nth (fields, 2), name = List.nth (fields, 9), parts = parts} : function end
        val rows = lines (read (dir ^ "/index.tsv"))
        val () = need (not (null rows), "JIT index has no functions")
        val functions = Vector.fromList (List.map one (ListPair.zip (List.tabulate (length rows, fn i => i), rows)))
        val () = need (List.all (fn role => List.exists (fn r => r = role) (!seen)) callRoles, "fib is missing a JIT call role")
    in functions end
  fun check dir =
    let
      val functions = readIndex dir
      val dumps = List.filter (fn name => String.isPrefix "jit-" name andalso String.isSuffix ".dump" name) (entries dir)
      val file = case dumps of [file] => file | _ => raise Failed "expected exactly one perf jitdump"
      val data = binary (dir ^ "/" ^ file)
      fun u (at, width) = TraceCheck.uint (data, at, width)
      fun int (at, width) = IntInf.toInt (u (at, width))
      val () = need (size data >= 40, "truncated jitdump header")
      val () = need (u (0, 4) = 1248416836 andalso u (4, 4) = 1 andalso u (8, 4) = 40
                    andalso (u (12, 4) = 62 orelse u (12, 4) = 183), "invalid jitdump header")
      val () = need (file = "jit-" ^ IntInf.toString (u (20, 4)) ^ ".dump", "jitdump pid and filename disagree")
      fun string (at, limit) =
        let fun endAt i = if i >= limit then raise Failed "unterminated jitdump string"
                         else if String.sub (data, i) = #"\000" then i else endAt (i + 1)
            val end' = endAt at
        in (String.substring (data, at, end' - at), end' + 1) end
      fun loop (at, seq, debug) =
        if at = size data then
          need (seq = Vector.length functions andalso not (isSome debug), "jitdump and index function counts differ")
        else
          let
            val () = need (at + 16 <= size data, "truncated jitdump record")
            val rid = int (at, 4)
            val total = int (at + 4, 4)
            val limit = at + total
            val () = need (total >= 16 andalso total <= size data - at, "jitdump record length exceeds file")
          in
            if rid = 2 then
              let val () = need (total >= 32 andalso not (isSome debug), "bad or repeated JIT debug record")
                  val n = int (at + 24, 8)
                  val () = need (n <= (total - 32) div 17, "JIT debug entry count exceeds record")
                  fun entry (0, q, acc) = (List.rev acc, q)
                    | entry (left, q, acc) =
                      let val () = need (q + 16 < limit, "truncated JIT debug entry")
                          val address = u (q, 8)
                          val line = u (q + 8, 4)
                          val (file, next) = string (q + 16, limit)
                      in entry (left - 1, next, (address, line, file) :: acc) end
                  val (entries, ending) = entry (n, at + 32, [])
                  val () = need (ending <= limit, "JIT debug entries exceed record")
              in loop (limit, seq, SOME entries) end
            else if rid = 0 then
              let
                val () = need (total >= 57 andalso seq < Vector.length functions, "extra or truncated JIT code load")
                val f = Vector.sub (functions, seq)
                val (name, start) = string (at + 56, limit)
                val () = need (u (at + 24, 8) = #address f andalso u (at + 32, 8) = #address f
                      andalso u (at + 40, 8) = IntInf.fromInt (size (#bytes f)) andalso u (at + 48, 8) = IntInf.fromInt seq,
                      "JIT code load differs from index")
                val () = need (name = "jit" ^ #tier f ^ ":" ^ #name f, "JIT code name differs from index")
                val () = need (limit - start = size (#bytes f) andalso String.substring (data, start, limit - start) = #bytes f,
                               "jitdump machine bytes differ from function binary")
                val expected = Vector.foldri (fn (i, {offset, ...} : part, acc) =>
                      (#address f + IntInf.fromInt offset, IntInf.fromInt (i + 1), OS.FileSys.fullPath (dir ^ "/" ^ #sequence f ^ ".lst")) :: acc) [] (#parts f)
                val () = need (debug = SOME expected, "jitdump debug locations differ from part list")
              in loop (limit, seq + 1, NONE) end
            else raise Failed ("unexpected jitdump record kind " ^ Int.toString rid)
          end
      val () = loop (40, 0, NONE)
    in () end
  fun make dir =
    let
        val dump = dir ^ "/dump"
        val () = rmTree dump
        val () = mkdirs dump
        val rbc = dir ^ "/fib.rbc"
        val () = ignore (command dir "compile" ["bin/rune", "tests/perf/fib.sml", "-o", rbc])
        val () = ignore (command dir "run" ["bin/runevm", "--jit=all", "--jit-tier=2", "--jit-dump=" ^ dump, rbc])
    in dump end
  fun produce () = check (make (directory "jitdump"))
  fun faults () =
    let
      val dump = make (directory "jitdump-faults")
      val () = check dump
      val originals = List.map (fn name => (name, binary (dump ^ "/" ^ name))) (entries dump)
      fun original name = valOf (Option.map #2 (List.find (fn (n, _) => name = n) originals))
      fun writeBinary (name, value) =
        let val output = BinIO.openOut (dump ^ "/" ^ name)
        in (BinIO.output (output, Byte.stringToBytes value); BinIO.closeOut output)
           handle e => (BinIO.closeOut output; raise e) end
      fun restore () = List.app writeBinary originals
      fun bad name changes =
        let val () = List.app writeBinary changes
            val refused = ((check dump; false) handle Failed _ => true | TraceCheck.Invalid _ => true)
            val () = restore ()
        in need (refused, "JIT dump reader accepted " ^ name) end
      val rows = lines (original "index.tsv")
      val first = String.fields (fn c => c = #"\t") (hd rows)
      val seq = hd first
      val code = original (seq ^ ".bin")
      val lst = original (seq ^ ".lst")
      val partRows = lines lst
      val part = String.fields (fn c => c = #"\t") (hd partRows)
      val perfName = #1 (valOf (List.find (fn (name, _) => String.isSuffix ".dump" name) originals))
      val perf = original perfName
      fun partLine (offset, role) = String.concatWith "\t" (offset :: List.nth (part, 1) :: role :: List.drop (part, 3))
      val () = bad "empty index" [("index.tsv", "")]
      val () = bad "index sequence" [("index.tsv", "9" ^ String.extract (original "index.tsv", 1, NONE))]
      val () = bad "machine byte count" [(seq ^ ".bin", String.substring (code, 0, size code - 1))]
      val () = bad "empty part list" [(seq ^ ".lst", "")]
      val () = bad "unknown part role" [(seq ^ ".lst", String.concatWith "\n" (partLine (hd part, "planted-role") :: tl partRows) ^ "\n")]
      val () = bad "part outside code" [(seq ^ ".lst", partLine (Int.toString (size code), List.nth (part, 2)) ^ "\n")]
      val () = bad "bad perf magic" [(perfName, "!" ^ String.extract (perf, 1, NONE))]
      val () = bad "truncated perf record" [(perfName, String.substring (perf, 0, size perf - 1))]
      val () = bad "zero perf record length" [(perfName, String.substring (perf, 0, 44) ^ "\000\000\000\000" ^ String.extract (perf, 48, NONE))]
      val () = bad "wrong perf machine bytes" [(perfName, String.substring (perf, 0, size perf - 1) ^
                                     (if String.sub (perf, size perf - 1) = #"\000" then "\001" else "\000"))]
    in () end
  (* The production analysis tool remains owned by P2.14. This assertion
     keeps its current CLI covered while its implementation is still Python. *)
  fun analysis () =
    let val dir = directory "jitdump"
        val output = command dir "analysis" ["python3", "scripts/jit-dump.py", dir ^ "/dump", "fib"]
        val rows = List.filter (fn line => not (String.isPrefix "#" line)) (lines output)
    in need (not (null rows) andalso List.all (fn line => case String.tokens Char.isSpace line of
             _ :: _ :: role :: _ :: _ => List.exists (fn r => role = r) roles | _ => false) rows,
             "analysis tool left an instruction without a role") end
end
