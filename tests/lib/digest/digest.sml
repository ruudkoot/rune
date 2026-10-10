(* libraries: random *)
(* SHA-256 against FIPS 180-4's examples and a million a's, HMAC-SHA-256
   against RFC 4231's seven cases, both against Python's hashlib and hmac
   on messages of every length around a block's edges
   (tests/lib/digest/python.txt, which tests/lib/digest/gen-vectors.py
   wrote), a message read in random pieces, Hex
   both ways, and equal. *)
structure DigestTest =
struct
  val failures = ref 0
  fun check (name, ok) = if ok then () else (failures := !failures + 1; print ("FAIL " ^ name ^ "\n"))

  fun bytes h = valOf (Hex.toBytes h)
  fun sha s = Hex.fromBytes (Sha256.digest s)
  fun hmac (k, m) = Hex.fromBytes (HmacSha256.mac {key = k, message = m})
  fun times (n, s) = String.concat (List.tabulate (n, fn _ => s))

  fun fips () =
    (check ("empty", sha "" = "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855");
     check ("abc", sha "abc" = "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad");
     check ("448 bits", sha "abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq"
                        = "248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1");
     check ("896 bits", sha ("abcdefghbcdefghicdefghijdefghijkefghijklfghijklmghijklmnhijklmnoijklmnopjklmnopqklmnopqr"
                             ^ "lmnopqrsmnopqrstnopqrstu")
                        = "cf5b16a778af8380036ce59e7b0492370b249b11e8f07a51afac45037afee9d1");
     check ("a million a's", Hex.fromBytes (Sha256.finish (foldl (fn (p, c) => Sha256.update (c, p)) Sha256.empty
                                                                  (List.tabulate (1000, fn _ => times (1000, "a")))))
                             = "cdc76e5c9914fb9281a1c7e284d73e67f1809a48a497200e046d39ccc7112cd0"))

  fun rfc4231 () =
    let
      val long = "This is a test using a larger than block-size key and a larger than block-size data. "
                 ^ "The key needs to be hashed before being used by the HMAC algorithm."
    in
      check ("case 1", hmac (times (20, "\011"), "Hi There")
                       = "b0344c61d8db38535ca8afceaf0bf12b881dc200c9833da726e9376c2e32cff7");
      check ("case 2", hmac ("Jefe", "what do ya want for nothing?")
                       = "5bdcc146bf60754e6a042426089575c75a003f089d2739839dec58b964ec3843");
      check ("case 3", hmac (times (20, "\170"), times (50, "\221"))
                       = "773ea91e36800e46854db8ebd09181a72959098b3ef8c122d9635514ced565fe");
      check ("case 4", hmac (CharVector.tabulate (25, fn i => Char.chr (i + 1)), times (50, "\205"))
                       = "82558a389a443c0ea4cc819899f2083a85f0faa3e578f8077a2e3ff46729665b");
      check ("case 5, truncated", String.substring (hmac (times (20, "\012"), "Test With Truncation"), 0, 32)
                                  = "a3b6167473100ee06e0c796c2955552b");
      check ("case 6", hmac (times (131, "\170"), "Test Using Larger Than Block-Size Key - Hash Key First")
                       = "60e431591ee0b67f0d8a26aacbf5b77f8e0bc6213728c5140546040f0ee37f54");
      check ("case 7", hmac (times (131, "\170"), long)
                       = "9b09ffa71b942fcb27635fbcd5b0e944bfdc63644f0713938a7f51535c3a35e2")
    end

  fun python () =
    let
      val i = TextIO.openIn "tests/lib/digest/python.txt"
      fun field "-" = "" | field h = bytes h
      fun go n =
        case TextIO.inputLine i of
          NONE => n
        | SOME l =>
            (case String.tokens Char.isSpace l of
               [m, k, d, h] =>
                 (check ("SHA-256 of " ^ Int.toString (size (field m)) ^ " bytes", sha (field m) = d);
                  check ("HMAC of " ^ Int.toString (size (field m)) ^ " bytes, a key of "
                         ^ Int.toString (size (field k)), hmac (field k, field m) = h))
             | _ => check ("a line of python.txt: " ^ l, false);
             go (n + 1))
      val n = go 0
    in
      TextIO.closeIn i;
      check ("python.txt has its cases", n = 134)
    end

  (* a message read in random pieces, and HMAC's parts *)
  fun pieces () =
    let
      fun go (0, _) = true
        | go (n, g) =
            let
              val (len, g) = Random.int (0, 300) g
              val (cs, g) = List.foldl (fn (_, (acc, g)) => let val (b, g) = Random.int (0, 255) g in (Char.chr b :: acc, g) end)
                                       ([], g) (List.tabulate (len, fn i => i))
              val m = String.implode cs
              fun cut (s, g) =
                if s = "" then ([], g)
                else
                  let
                    val (k, g) = Random.int (1, Int.min (size s, 70)) g
                    val (rest, g) = cut (String.extract (s, k, NONE), g)
                  in
                    (String.substring (s, 0, k) :: rest, g)
                  end
              val (ps, g) = cut (m, g)
              val whole = Sha256.digest m
              val inParts = Sha256.finish (foldl (fn (p, c) => Sha256.update (c, p)) Sha256.empty ps)
            in
              whole = inParts andalso HmacSha256.macParts {key = "k", parts = ps} = HmacSha256.mac {key = "k", message = m}
              andalso go (n - 1, g)
            end
    in
      check ("in pieces", go (300, Random.fromSeed 0w180))
    end

  fun hexAndEqual () =
    (check ("Hex", Hex.fromBytes "\000\001\127\128\255" = "00017f80ff" andalso Hex.toBytes "00017F80ff" = SOME "\000\001\127\128\255");
     check ("Hex refuses", Hex.toBytes "abc" = NONE andalso Hex.toBytes "zz" = NONE);
     check ("equal", HmacSha256.equal ("", "") andalso HmacSha256.equal ("ab", "ab")
                     andalso not (HmacSha256.equal ("ab", "ac")) andalso not (HmacSha256.equal ("ab", "abc"))))

  fun main () =
    (fips (); rfc4231 (); python (); pieces (); hexAndEqual ();
     print ((if !failures = 0 then "PASS" else "FAIL") ^ " digest: " ^ Int.toString (!failures) ^ " failed\n"))
end

val () = DigestTest.main ()
