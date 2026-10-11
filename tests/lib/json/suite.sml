(* Json.decode against JSONTestSuite's parsing tests (tests/lib/json/parsing,
   README there): a file named y_ must be read, one named n_ refused with
   Json.Syntax, and one named i_ either, but with no other exception. Run
   from the top of the tree. *)
structure JsonSuite =
struct
  val dir = "tests/lib/json/parsing"

  fun read path =
    let
      val f = BinIO.openIn path
      val s = Byte.bytesToString (BinIO.inputAll f)
    in
      BinIO.closeIn f; s
    end

  fun files () =
    let
      val d = OS.FileSys.openDir dir
      fun go acc =
        case OS.FileSys.readDir d of
          NONE => (OS.FileSys.closeDir d; acc)
        | SOME f => go (if String.isSuffix ".json" f then f :: acc else acc)
    in
      go []
    end

  datatype outcome = Accepted | Refused | Raised of string

  fun outcome text =
    (ignore (Json.decode text); Accepted)
    handle Json.Syntax _ => Refused
         | e => Raised (exnName e)

  fun main () =
    let
      val counts = ref (0, 0, 0)
      fun count f = let val (y, n, i) = !counts in counts := f (y, n, i) end
      val failures = ref 0
      fun judge name =
        let
          val got = outcome (read (dir ^ "/" ^ name))
          val ok =
            case (String.sub (name, 0), got) of
              (#"y", Accepted) => (count (fn (y, n, i) => (y + 1, n, i)); true)
            | (#"n", Refused) => (count (fn (y, n, i) => (y, n + 1, i)); true)
            | (#"i", Accepted) => (count (fn (y, n, i) => (y, n, i + 1)); true)
            | (#"i", Refused) => (count (fn (y, n, i) => (y, n, i + 1)); true)
            | _ => false
        in
          if ok then ()
          else (failures := !failures + 1;
                print ("FAIL " ^ name ^ ": " ^
                       (case got of Accepted => "accepted" | Refused => "refused"
                                  | Raised e => "raised " ^ e) ^ "\n"))
        end
      val names = files ()
      val () = List.app judge names
      val (y, n, i) = !counts
    in
      print ((if !failures = 0 then "PASS" else "FAIL") ^ " JSONTestSuite: " ^ Int.toString (length names)
             ^ " files, " ^ Int.toString y ^ " accepted, " ^ Int.toString n ^ " refused, "
             ^ Int.toString i ^ " either, " ^ Int.toString (!failures) ^ " wrong\n")
    end
end

val () = JsonSuite.main ()
