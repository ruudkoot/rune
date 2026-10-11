(* libraries: random *)
(* Style: the escapes of styles, the styles of parameters, and the
   colours a terminal with fewer has instead. *)
structure StyleTest =
struct
  val failures = ref 0
  fun check (name, ok) = if ok then () else (failures := !failures + 1; print ("FAIL " ^ name ^ "\n"))

  open Style

  fun with' (f : style -> style) = f plain
  fun fg c ({bg, bold, faint, italic, underline, reverse, struck, ...} : style) =
    {fg = c, bg = bg, bold = bold, faint = faint, italic = italic, underline = underline, reverse = reverse,
     struck = struck}

  (* a random style *)
  fun draw g =
    let
      fun color g =
        let val (k, g) = Random.int (0, 3) g
        in
          case k of
            0 => (Default, g)
          | 1 => let val (n, g) = Random.int (0, 15) g in (Ansi n, g) end
          | 2 => let val (n, g) = Random.int (0, 255) g in (Indexed n, g) end
          | _ => let val (r, g) = Random.int (0, 255) g val (gr, g) = Random.int (0, 255) g
                     val (b, g) = Random.int (0, 255) g in (Rgb (r, gr, b), g) end
        end
      val (f, g) = color g
      val (b, g) = color g
      fun bit g = Random.bool g
      val (b1, g) = bit g val (b2, g) = bit g val (b3, g) = bit g
      val (b4, g) = bit g val (b5, g) = bit g val (b6, g) = bit g
    in
      ({fg = f, bg = b, bold = b1, faint = b2, italic = b3, underline = b4, reverse = b5, struck = b6}, g)
    end

  (* what sgr writes, read back by parameters *)
  fun body s = let val e = sgr s in String.substring (e, 2, size e - 3) end

  fun roundTrip () =
    let
      fun go (0, _) = true
        | go (k, g) = let val (s, g) = draw g in parameters (body s) = s andalso go (k - 1, g) end
    in
      check ("parameters reads what sgr writes", go (2000, Random.fromSeed 0w7))
    end

  fun escapes () =
    (check ("plain", sgr plain = "\027[0m");
     check ("bold red", sgr (parameters "1;31") = "\027[0;1;31m");
     check ("bright", sgr (with' (fg (Ansi 9))) = "\027[0;91m");
     check ("256 and 24 bits", sgr (parameters "38;5;203;48;2;1;2;3") = "\027[0;38;5;203;48;2;1;2;3m");
     check ("change", change (plain, plain) = "" andalso change (plain, parameters "4") = "\027[0;4m");
     check ("39 and 49", parameters "31;41;39;49" = plain);
     check ("a bad part ends it", parameters "1;x;31" = parameters "1");
     check ("out of range", parameters "38;5;300" = plain))

  fun downgrades () =
    (check ("rgb to 256", #fg (downgrade Colors256 (parameters "38;2;255;0;0")) = Indexed 196);
     check ("gray to 256", #fg (downgrade Colors256 (parameters "38;2;128;128;128")) = Indexed 244);
     check ("256 to 16", #fg (downgrade Colors16 (parameters "38;5;196")) = Ansi 9);
     check ("16 stay", #fg (downgrade Colors16 (parameters "31")) = Ansi 1);
     check ("mono keeps the attributes", downgrade Mono (parameters "1;4;31;42") = parameters "1;4");
     check ("true colour keeps", downgrade TrueColor (parameters "38;2;1;2;3") = parameters "38;2;1;2;3"))

  fun choices () =
    check ("always and never", enabled (Always, false) andalso not (enabled (Never, true)))

  fun main () =
    (roundTrip (); escapes (); downgrades (); choices ();
     print ((if !failures = 0 then "PASS" else "FAIL") ^ " style: " ^ Int.toString (!failures) ^ " failed\n"))
end

val () = StyleTest.main ()
