(* libraries: test/unit *)
(* Normalize, its laws as properties (lib/test/property): each form
   idempotent; NFC of NFD is NFC and NFD of NFC is NFD; NFC is in NFC;
   isNFC exactly when nfc changes nothing, and the quick check never
   contradicts it; the functions over UTF-8 agree with those over code
   points, through Utf8, segment by segment; marks of different classes
   commute under NFD. The strings are drawn from code points
   that normalisation treats differently -- ASCII, Latin and Greek
   composites, combining marks of many classes, Hangul syllables and jamo,
   singletons and exclusions, compatibility characters, starters that
   compose -- and any scalar value; some have ill-formed bytes. *)
structure NormalizeProps =
struct
  val ranges = Vector.fromList [
    (0x41, 0x5A), (0x61, 0x7A), (0x20, 0x7E),                (* ASCII *)
    (0xC0, 0x17F), (0x1E00, 0x1EFF), (0x1F00, 0x1FFF),       (* Latin, Greek composites *)
    (0x300, 0x36F), (0x323, 0x328), (0x345, 0x345), (0x591, 0x5C7), (0x93C, 0x94D),
    (0xE38, 0xE3A), (0x302A, 0x302F), (0x1D165, 0x1D172), (0x1DC0, 0x1DFF), (0x20D0, 0x20F0), (* marks *)
    (0xAC00, 0xD7A3), (0x1100, 0x1112), (0x1161, 0x1175), (0x11A7, 0x11C3), (* Hangul *)
    (0x212A, 0x212B), (0x2126, 0x2126), (0x340, 0x344), (0x374, 0x37E), (0x387, 0x387),
    (0x958, 0x95F), (0xFB1D, 0xFB4E), (0xF900, 0xFA0D), (0x2F800, 0x2F810),
    (0x1D15E, 0x1D164), (0xF71, 0xF81),                       (* singletons, exclusions *)
    (0xFB00, 0xFB06), (0xFF01, 0xFF5E), (0x2460, 0x24FF), (0xB2, 0xBE), (0x2150, 0x218B),
    (0x3300, 0x33FF), (0xFDFA, 0xFDFA), (0x1E9B, 0x1E9B), (0x3131, 0x318E), (* compatibility *)
    (0xB47, 0xB57), (0xBC6, 0xBD7), (0xCBF, 0xCD6), (0xD46, 0xD57), (0xDD9, 0xDDF),
    (0x1025, 0x102E), (0x1B05, 0x1B43), (0x11127, 0x11134), (0x3099, 0x309A), (* starters that compose *)
    (0, 0x10FFFF)]                                            (* anything *)

  val code =
    Gen.bind (Gen.intRange (0, Vector.length ranges - 1))
             (fn i => let val (lo, hi) = Vector.sub (ranges, i) in Gen.intRange (lo, hi) end)
  val scalar = Gen.map (fn c => if Utf8.isScalar c then c else 0xFFFD) code
  val codes = Gen.listOf (Gen.intRange (0, 12)) scalar
  fun showCodes cs = "[" ^ String.concatWith ", " (map (fn c => "0x" ^ Int.fmt StringCvt.HEX c) cs) ^ "]"

  (* UTF-8, with an ill-formed byte now and then *)
  val bytes =
    Gen.map (fn parts => String.concat parts)
            (Gen.listOf (Gen.intRange (0, 8))
                        (Gen.frequency [(9, Gen.map (fn c => Utf8.encode c) scalar),
                                        (1, Gen.map (fn b => String.str (Char.chr b)) (Gen.intRange (0x80, 0xFF)))]))
  fun showBytes s = String.toString s

  fun forCodes f () = Prop.forAllGen (codes, showCodes) (Prop.holds o f)
  fun forBytes f () = Prop.forAllGen (bytes, showBytes) (Prop.holds o f)

  open Normalize

  val tests =
    Test.describe "unicode/normalize-props"
      [Test.property "idempotent" (forCodes (fn cs =>
         nfcList (nfcList cs) = nfcList cs andalso nfdList (nfdList cs) = nfdList cs)),
       Test.property "nfc-of-nfd" (forCodes (fn cs => nfcList (nfdList cs) = nfcList cs)),
       Test.property "nfd-of-nfc" (forCodes (fn cs => nfdList (nfcList cs) = nfdList cs)),
       Test.property "nfc-is-nfc" (forCodes (fn cs => isNFCList (nfcList cs) andalso isNFC (nfc (Utf8.implode cs)))),
       Test.property "isNFC-is-fixed-point" (forCodes (fn cs => isNFCList cs = (nfcList cs = cs))),
       Test.property "quick-check-agrees" (forCodes (fn cs =>
         case quickCheckList cs of Yes => nfcList cs = cs | No => nfcList cs <> cs | Maybe => true)),
       Test.property "utf8-agrees" (forCodes (fn cs =>
         let val s = Utf8.implode cs
         in
           Utf8.explode (nfc s) = nfcList cs andalso Utf8.explode (nfd s) = nfdList cs
           andalso quickCheck s = quickCheckList cs andalso isNFC s = isNFCList cs
         end)),
       Test.property "bytes-by-segment" (forBytes (fn s =>
         nfc s = Utf8.implode (nfcList (Utf8.explode s))
         andalso nfd s = Utf8.implode (nfdList (Utf8.explode s))
         andalso isNFC s = (nfc s = s)
         andalso Utf8.isValid (nfc s)
         andalso (Utf8.isValid s orelse quickCheck s = No))),
       Test.property "marks-commute" (fn () =>
         Prop.forAllGen (Gen.triple (scalar, scalar, scalar),
                         fn (a, b, c) => showCodes [a, b, c])
           (fn (a, m1, m2) =>
              let val k1 = combiningClass m1 and k2 = combiningClass m2
              in
                Prop.holds (k1 = 0 orelse k2 = 0 orelse k1 = k2
                            orelse nfdList [a, m1, m2] = nfdList [a, m2, m1])
              end)),
       Test.property "round-trip" (forCodes (fn cs =>
         Utf8.explode (Utf8.implode (nfcList cs)) = nfcList cs))]
end

structure NormalizePropsMain = Main (struct val name = "unicode/normalize-props" val tests = NormalizeProps.tests end)
val () = NormalizePropsMain.main ()
