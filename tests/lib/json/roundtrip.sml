(* libraries: test/unit random *)
(* Json: random values written and read back, compactly and indented; the
   escapes the writer makes; what decode reports where a text breaks off;
   and the integers of toInt and int at the edges of int. *)
structure JsonRoundTrip =
struct
  val check = Expect.that

  (* a random value of depth at most d *)
  fun draw (d, g) =
    let
      val (k, g) = Random.int (0, if d = 0 then 4 else 6) g
      fun str g =
        let
          val (n, g) = Random.int (0, 6) g
          fun go (0, g, acc) = (Utf8.implode (rev acc), g)
            | go (m, g, acc) =
                let
                  val (which, g) = Random.int (0, 3) g
                  val (c, g) = case which of
                                 0 => Random.int (0, 0x7F) g
                               | 1 => Random.int (0x80, 0x7FF) g
                               | 2 => Random.int (0xE000, 0xFFFF) g
                               | _ => Random.int (0x10000, 0x10FFFF) g
                in
                  go (m - 1, g, c :: acc)
                end
        in
          go (n, g, [])
        end
      fun list (0, g, acc) = (rev acc, g)
        | list (m, g, acc) = let val (v, g) = draw (d - 1, g) in list (m - 1, g, v :: acc) end
    in
      case k of
        0 => (Json.Null, g)
      | 1 => let val (b, g) = Random.bool g in (Json.Bool b, g) end
      | 2 => let val (i, g) = Random.int (~1000000, 1000000) g in (Json.int i, g) end
      | 3 => let val (s, g) = str g in (Json.String s, g) end
      | 4 => (Json.Number "-1.25e-3", g)
      | 5 => let val (m, g) = Random.int (0, 4) g val (vs, g) = list (m, g, []) in (Json.Array vs, g) end
      | _ =>
          let
            val (m, g) = Random.int (0, 4) g
            val (vs, g) = list (m, g, [])
            fun names (_, [], g, acc) = (rev acc, g)
              | names (i, v :: vs, g, acc) = let val (s, g) = str g in names (i + 1, vs, g, (s, v) :: acc) end
            val (ms, g) = names (0, vs, g, [])
          in
            (Json.Object ms, g)
          end
    end

  fun roundTrips () =
    let
      fun go (0, _) = true
        | go (k, g) =
            let val (v, g) = draw (4, g)
            in
              Json.decode (Json.encode v) = v andalso Json.decode (Json.encodeIndented 2 v) = v
              andalso go (k - 1, g)
            end
    in
      check ("random values round-trip", go (3000, Random.fromSeed 0w2026))
    end

  fun escapes () =
    (check ("escapes", Json.encode (Json.String "a\"b\\c\n\t\001") = "\"a\\\"b\\\\c\\n\\t\\u0001\"");
     check ("UTF-8 kept", Json.encode (Json.String "\226\130\172") = "\"\226\130\172\"");
     check ("bad UTF-8 refused", (ignore (Json.encode (Json.String "\255")); false) handle Domain => true);
     check ("a bad number refused", (ignore (Json.encode (Json.Number "01")); false) handle Domain => true);
     check ("a surrogate pair read", Json.decode "\"\\ud83d\\ude00\"" = Json.String "\240\159\152\128"))

  fun errors () =
    let fun at s = (ignore (Json.decode s); ~1) handle Json.Syntax (i, _) => i
    in
      check ("where a text breaks", at "[1, 2" = 5 andalso at "{\"a\" 1}" = 5 andalso at "tru" = 0
                                    andalso at "[1,]" = 3 andalso at "1 2" = 2)
    end

  fun ints () =
    (check ("toInt", Json.toInt (Json.Number "-17") = SOME ~17 andalso Json.toInt (Json.Number "1e2") = NONE
                     andalso Json.toInt Json.Null = NONE);
     check ("int and toInt at the edges",
            case (Int.minInt, Int.maxInt) of
              (SOME lo, SOME hi) => Json.toInt (Json.int lo) = SOME lo andalso Json.toInt (Json.int hi) = SOME hi
            | _ => true))

  val tests =
    Test.describe "json/roundtrip"
      [Test.it "round-trips" roundTrips, Test.it "escapes" escapes, Test.it "errors" errors, Test.it "ints" ints]
end

structure JsonRoundTripMain = Main (struct val name = "json/roundtrip" val tests = JsonRoundTrip.tests end)
val () = JsonRoundTripMain.main ()
