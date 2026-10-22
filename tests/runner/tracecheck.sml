(* An independent reader of census format 2. Binary integers are unsigned
   little endian; allocation and field streams are walked once. The only
   per-object storage is nine packed bytes for clock, length and kind. *)
structure TraceCheck =
struct
  open Sh
  exception Invalid of string
  fun need (ok, message) = if ok then () else raise Invalid message
  fun integer s = case IntInf.scan StringCvt.DEC Substring.getc (Substring.full s) of
      SOME (n, rest) => if Substring.isEmpty rest then n else raise Invalid ("not an integer: " ^ s)
    | NONE => raise Invalid ("not an integer: " ^ s)
  fun natural s = let val n = integer s in need (n >= 0, "negative quantity: " ^ s); n end
  fun uint (s, offset, width) =
    let fun go (i, n) = if i < 0 then n else
              go (i - 1, Word64.orb (Word64.<< (n, 0w8), Word64.fromInt (Char.ord (String.sub (s, offset + i)))))
    in need (offset >= 0 andalso width >= 0 andalso width <= 8 andalso offset + width <= size s, "truncated binary field");
       IntInf.fromLarge (Word64.toLargeInt (go (width - 1, 0w0))) end
  fun byte (s, i) = Char.ord (String.sub (s, i))
  fun packed n = Word8Array.array (n * 4, 0w0)
  fun get (a, i) =
    IntInf.fromLarge (LargeWord.toLargeInt (PackWord32Little.subArr (a, i)))
  fun put (a, i, n) =
    (need (n >= 0 andalso n < 4294967296, "packed quantity exceeds 32 bits");
     PackWord32Little.update (a, i, LargeWord.fromLargeInt (IntInf.toLarge n)))
  fun records (path, width, count) =
    need (exists path andalso Position.toLarge (OS.FileSys.fileSize path) = IntInf.toLarge (count * IntInf.fromInt width),
          path ^ ": wrong or missing record count")
  fun inspect verbose dir =
    let
      val meta = List.map (fn line => case String.tokens Char.isSpace line of [k, v] => (k, v)
                                  | _ => raise Invalid "malformed meta.txt") (lines (read (dir ^ "/meta.txt")))
      val () = need (List.all (fn (key, _) => length (List.filter (fn (k, _) => k = key) meta) = 1) meta,
                     "meta.txt: duplicate key")
      fun value name = case List.find (fn (k, _) => k = name) meta of SOME (_, v) => v
                      | NONE => raise Invalid ("meta.txt: missing " ^ name)
      fun number name = natural (value name)
      fun optional name = case List.find (fn (k, _) => k = name) meta of SOME (_, v) => natural v | NONE => 0
      val () = need (value "format" = "2" andalso value "layout" = "W8", "meta.txt: expected format 2, layout W8")
      val n' = number "objects"
    in if optional "summary" <> 0 then (if verbose then say "summary trace: nothing to check but meta.txt\n" else ()) else let
      val ns' = number "samples"
      val n = IntInf.toInt n'
      val ns = IntInf.toInt ns'
      val stores = number "stores"
      val fields = number "fields" <> 0
      val graph = optional "graph" <> 0
      val pre = optional "pretrace_objects"
      val () = need (pre <= n', "pretrace_objects exceeds objects")
      val () = List.app records [(dir ^ "/alloc.bin", 16, n' + 1), (dir ^ "/death.bin", 4, n' + 1),
                                 (dir ^ "/samples.bin", 64, ns'), (dir ^ "/stores.bin", 24, stores)]
      val opened = ref [] : BinIO.instream list ref
      fun openFile name =
        let val stream = BinIO.openIn (dir ^ "/" ^ name)
            val () = opened := stream :: !opened
            val buffer = ref ""
            val at = ref 0
            fun take bytes =
              if bytes <= size (!buffer) - !at then
                let val text = String.substring (!buffer, !at, bytes)
                in at := !at + bytes; text end
              else
                let val tail = String.extract (!buffer, !at, NONE)
                    val chunk = Byte.bytesToString (BinIO.inputN (stream, 65536))
                    val () = need (chunk <> "", "truncated " ^ name ^ " record")
                    val () = buffer := chunk
                    val () = at := 0
                in if tail = "" then take bytes else tail ^ take (bytes - size tail) end
        in take end
      fun close () = List.app BinIO.closeIn (!opened)
      fun take (reader, bytes) = reader bytes
      fun work () =
        let
          val sampleInput = openFile "samples.bin"
          val samples = Vector.tabulate (ns, fn _ => take (sampleInput, 64))
          val sampleIds = Vector.map (fn s => uint (s, 32, 8)) samples
          fun sample (i, offset) = if offset = 32 then Vector.sub (sampleIds, i) else uint (Vector.sub (samples, i), offset, 8)
          val () = Vector.appi (fn (i, s) =>
            (need (uint (s, 32, 8) <= n', "sample last_id exceeds objects");
             need (uint (s, 48, 4) <= uint (s, 44, 4) andalso uint (s, 52, 4) <= uint (s, 40, 4)
                   andalso uint (s, 56, 4) <= uint (s, 40, 4), "sample frame or pointer bounds");
             need ((byte (s, 60) div 2 mod 2 = 1) = (i = ns - 1), "final flag must occur on the last sample alone");
             if i = 0 then () else List.app (fn offset => need (sample (i - 1, offset) <= sample (i, offset),
                                                          "sample clock, instructions or last_id decreases")) [0, 24, 32])) samples
          fun birth id =
            let fun search (lo, hi) = if lo = hi then lo + 1 else
                  let val mid = lo + (hi - lo) div 2
                  in if sample (mid, 32) < id then search (mid + 1, hi) else search (lo, mid) end
            in search (0, ns) end
          val clock = packed (n + 1)
          val lengths = packed (n + 1)
          val kinds = Word8Array.array (n + 1, 0w0)
          val liveBytes = Array.array (ns + 2, 0 : IntInf.int)
          val liveObjects = Array.array (ns + 2, 0 : IntInf.int)
          fun add (a, i, v) = Array.update (a, i, Array.sub (a, i) + v)
          val allocation = openFile "alloc.bin"
          val death = openFile "death.bin"
          val fstream = if fields then SOME (openFile "fields.bin") else NONE
          val gstream = if graph then SOME (openFile "graph.bin") else NONE
          val () = ignore (take (allocation, 16))
          val () = ignore (take (death, 4))
          val total = ref (0 : IntInf.int)
          val boxbytes = ref (0 : IntInf.int)
          val boxobjects = ref (0 : IntInf.int)
          val fieldCount = ref (0 : IntInf.int)
          val aliveAtExit = ref false
          fun object id =
            let
              val a = take (allocation, 16)
              val kind = byte (a, 0)
              val len = uint (a, 4, 4)
              val () = need (kind >= 1 andalso kind <= 13 andalso kind <> 9, "allocation kind out of range")
              val () = need ((byte (a, 1) = 3) = (IntInf.fromInt id <= pre), "site kind 3 differs from pretrace objects")
              val box = kind = 10 orelse kind = 11
              val raw = if kind = 4 orelse kind = 12 then len else if box then 8 else len * 8
              val bytes = 8 + IntInf.max (8, IntInf.div (raw + 7, 8) * 8)
              val () = put (clock, id, IntInf.div (!total, 8))
              val () = put (lengths, id, len)
              val () = Word8Array.update (kinds, id, Word8.fromInt kind)
              val () = total := !total + bytes
              val () = need (!total < 34359738368, "allocation clock passes 32 GiB")
              val () = if box then (boxbytes := !boxbytes + bytes; boxobjects := !boxobjects + 1) else ()
              val dd = uint (take (death, 4), 0, 4)
              val () = if dd = 4294967295 then aliveAtExit := true else ()
              val last = if dd = 4294967295 then ns' else dd
              val () = need (last <= ns', "death sample past the last sample")
              val first = birth (IntInf.fromInt id)
              val () = if last >= IntInf.fromInt first then
                  (add (liveBytes, first, bytes); add (liveBytes, IntInf.toInt last + 1, ~bytes);
                   add (liveObjects, first, 1); add (liveObjects, IntInf.toInt last + 1, ~1))
                else need (last = 0, "object alive at a sample before its birth")
              fun field () =
                let val f = case fstream of NONE => NONE | SOME s => SOME (take (s, 2))
                    val g = case gstream of NONE => NONE | SOME s => SOME (uint (take (s, 4), 0, 4))
                    val () = case f of NONE => () | SOME f =>
                        need (byte (f, 0) mod 4 <> 3 andalso byte (f, 0) < 64 andalso byte (f, 1) < 128,
                              "field has spare bits or word class 3")
                in case (f, g) of (SOME f, SOME g) =>
                    (need ((byte (f, 0) mod 4 = 1) = (g <> 0), "graph pointer class and id disagree");
                     need (g < IntInf.fromInt id, "graph pointer is not older than its owner");
                     if g = 0 then () else need (byte (f, 0) div 4 mod 16 = Word8.toInt (Word8Array.sub (kinds, IntInf.toInt g)),
                                                "graph pointee kind differs from fields"))
                   | _ => () end
              fun fieldsLoop 0 = () | fieldsLoop left = (field (); fieldsLoop (left - 1))
              val nf = if List.exists (fn k => k = kind) [4, 10, 11, 12, 13] then 0 else len
              val () = fieldCount := !fieldCount + nf
            in if fields orelse graph then fieldsLoop nf else () end
          fun objects id = if id > n then () else (object id; objects (id + 1))
          val () = objects 1
          val () = need (!total = number "bytes", "sum of sizes differs from meta bytes")
          val () = need (!total - !boxbytes = number "count_bytes" andalso n' - !boxobjects = number "count_objects",
                         "count totals without boxes differ from meta")
          val () = if fields then records (dir ^ "/fields.bin", 2, !fieldCount) else ()
          val () = if graph then records (dir ^ "/graph.bin", 4, !fieldCount) else ()
          val () = need (n = 0 orelse !aliveAtExit, "nothing alive at exit")
          fun liveness (i, bytes, objects) =
            if i > ns then () else
              let val s = Vector.sub (samples, i - 1)
                  val last = IntInf.toInt (uint (s, 32, 8))
                  val after = if last = n then !total else get (clock, last + 1) * 8
                  val bytes = bytes + Array.sub (liveBytes, i)
                  val objects = objects + Array.sub (liveObjects, i)
                  val () = need (uint (s, 0, 8) = after, "sample clock differs from allocation prefix sum")
                  val () = need (uint (s, 8, 8) = bytes andalso uint (s, 16, 8) = objects,
                                 "sample liveness differs from death records")
              in liveness (i + 1, bytes, objects) end
          val () = liveness (1, 0, 0)
          val storeInput = openFile "stores.bin"
          fun allocated boundary =
            let fun search (lo, hi) = if lo = hi then lo - 1 else
                  let val mid = lo + (hi - lo) div 2
                  in if get (clock, mid) < boundary then search (mid + 1, hi) else search (lo, mid) end
            in search (1, n + 1) end
          fun storeLoop (0, _) = ()
            | storeLoop (left, prev) =
              let val s = take (storeInput, 24)
                  val now = uint (s, 0, 4)
                  val last = allocated now
                  val () = need (now >= prev, "store clock decreases")
                  val () = need (now * 8 <= !total andalso (now * 8 = !total orelse
                               (last < n andalso get (clock, last + 1) = now)), "store clock is not an object boundary")
                  val src = uint (s, 4, 4)
                  val new = uint (s, 8, 4)
                  val old = uint (s, 12, 4)
                  val () = need (src <= IntInf.fromInt last andalso new <= IntInf.fromInt last andalso old <= IntInf.fromInt last,
                                 "store id not yet allocated")
                  val id = IntInf.toInt src
                  val () = need (Word8.toInt (Word8Array.sub (kinds, id)) = byte (s, 23), "store source kind differs from allocation")
                  val () = need ((byte (s, 21) mod 2 = 1) = (old <> 0) andalso (byte (s, 21) div 2 mod 2 = 1) = (new <> 0),
                                 "store pointer flags and ids disagree")
                  val () = need (uint (s, 16, 4) < get (lengths, id), "store field index exceeds object length")
              in storeLoop (left - 1, now) end
          val () = storeLoop (stores, 0)
        in if not verbose then () else say (dir ^ ": " ^ IntInf.toString n' ^ " objects, " ^ IntInf.toString (!total) ^ " bytes, "
                ^ Int.toString ns ^ " samples, " ^ IntInf.toString stores ^ " stores, "
                ^ IntInf.toString (!fieldCount) ^ " fields: ok\n") end
    in (work () before close ()) handle e => (close (); raise e) end end
  fun check dir = inspect true dir
  fun silent dir = inspect false dir
end
