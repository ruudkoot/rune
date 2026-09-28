# Draft: new issue on smlnj/legacy

Where: https://github.com/smlnj/legacy/issues/new?template=00_bug_report.yaml

**Title:** `Real.fromLargeInt` rounds twice, and rounds the magnitude of a negative number

| Field | Value |
|---|---|
| Version | 110.99.9 (Latest) |
| Operating System | Any |
| OS Version | Ubuntu 24.04 (WSL2) |
| Processor | x86 (32-bit), x86-64 (64-bit) |
| System Component | Basis Library |
| Severity | Minor |
| Also present in the "development" version? | Yes: `Target64Bit/intinf-to-real64.sml` of smlnj/smlnj `a5f3fa7` is the same (read, not run) |

### Description

`Real.fromLargeInt i` can be one ulp off the correctly rounded result.

* **64-bit:** `fromLargeInt (2^115 + 2^62 + 1)` is 2^115, not
  2^115 + 2^63.
* **32-bit:** `fromLargeInt (2^100 + 2^47 + 1)` is 2^100, not
  2^100 + 2^48.
* **Directed modes, both builds:** under `TO_NEGINF`,
  `fromLargeInt (~(2^53 + 1))` is -2^53, not -(2^53 + 2), because the
  magnitude is rounded and then negated.

### Transcript

The program below checks 148 known answers (four rounding modes; the exact
results were computed with Python's arbitrary-precision arithmetic, and
MLton 20241230 gets all of them right):

```
$ sml bug.sml
Standard ML of New Jersey [Version 110.99.9; 64-bit; November 4, 2025]
TO_NEAREST: fromLargeInt 41538374868278625639929989061148673 = 0x4720000000000000, expected 0x4720000000000001
TO_NEAREST: fromLargeInt ~41538374868278625639929989061148673 = 0xC720000000000000, expected 0xC720000000000001
TO_NEAREST: fromLargeInt 212274721979399028737 = 0x442703CE9DEBD1C4, expected 0x442703CE9DEBD1C5
TO_NEAREST: fromLargeInt 2460397548491222481185404434251777 = 0x46DE53A54FD23C68, expected 0x46DE53A54FD23C69
TO_NEAREST: fromLargeInt 248628903473537720366730992750092127105971815274712955287226791293362679002376962049 = 0x514061C08F1CC788, expected 0x514061C08F1CC789
TO_NEAREST: fromLargeInt ~585850352274734830560219908876353633764091552574237801 = 0xCB18775C4F7BBE1A, expected 0xCB18775C4F7BBE1B
TO_NEAREST: fromLargeInt ~1131538601701648368651302167811650542407398669559005185 = 0xCB27A0AC4238E19E, expected 0xCB27A0AC4238E19F
TO_NEGINF: fromLargeInt ~41538374868278625639929989061148673 = 0xC720000000000000, expected 0xC720000000000001
34 of 148 wrong
```

The 32-bit build gets 31 of them wrong.

### Expected Behavior

`0 of 148 wrong`: one rounding of `i` itself, in the current rounding mode.

### Steps to Reproduce

```sml
(* Real.fromLargeInt against correctly rounded results (computed with Python's
   exact arithmetic), in every rounding mode, for numbers chosen to catch a
   second rounding: 2^115 + 2^62 + 1, 2^100 + 2^47 + 1, ties and random
   numbers of 54 to 300 bits, and their negations. Run: sml bug.sml *)
fun hex r = StringCvt.padLeft #"0" 16 (Word64.fmt StringCvt.HEX (Unsafe.Real64.castToWord r))
val cases = [
  (IEEEReal.TO_NEAREST, "41538374868278625639929989061148673", "4720000000000001"),
  (IEEEReal.TO_NEAREST, "~41538374868278625639929989061148673", "C720000000000001"),
  (IEEEReal.TO_NEAREST, "1267650600228229542234191560705", "4630000000000001"),
  (IEEEReal.TO_NEAREST, "~1267650600228229542234191560705", "C630000000000001"),
  (IEEEReal.TO_NEAREST, "1267650600228229542234191560704", "4630000000000000"),
  (IEEEReal.TO_NEAREST, "~1267650600228229542234191560704", "C630000000000000"),
  (IEEEReal.TO_NEAREST, "9007199254740993", "4340000000000000"),
  (IEEEReal.TO_NEAREST, "~9007199254740993", "C340000000000000"),
  (IEEEReal.TO_NEAREST, "9007199254740995", "4340000000000002"),
  (IEEEReal.TO_NEAREST, "~9007199254740995", "C340000000000002"),
  (IEEEReal.TO_NEAREST, "1152921504606847105", "43B0000000000001"),
  (IEEEReal.TO_NEAREST, "~1152921504606847105", "C3B0000000000001"),
  (IEEEReal.TO_NEAREST, "21267647932558653376165102605779861505", "47B0000000000000"),
  (IEEEReal.TO_NEAREST, "~21267647932558653376165102605779861505", "C7B0000000000000"),
  (IEEEReal.TO_NEAREST, "269653970229347386159395778618353710042696546841345985910145121736599013708251444699062715983611304031680170819807090036488184653221624933739271145959211186566651840137298227914453329401869141179179624428127508653257226023513694322210869665811240855745025766026879447359920868907719574457253034494436336205824", "7FF0000000000000"),
  (IEEEReal.TO_NEAREST, "~269653970229347386159395778618353710042696546841345985910145121736599013708251444699062715983611304031680170819807090036488184653221624933739271145959211186566651840137298227914453329401869141179179624428127508653257226023513694322210869665811240855745025766026879447359920868907719574457253034494436336205824", "FFF0000000000000"),
  (IEEEReal.TO_NEAREST, "179769313486231590772930519078902473361797697894230657273430081157732675805500963132708477322407536021120113879871393357658789768814416622492847430639474124377767893424865485276302219601246094119453082952085005768838150682342462881473913110540827237163350510684586298239947245938479716304835356329624224137216", "7FF0000000000000"),
  (IEEEReal.TO_NEAREST, "~179769313486231590772930519078902473361797697894230657273430081157732675805500963132708477322407536021120113879871393357658789768814416622492847430639474124377767893424865485276302219601246094119453082952085005768838150682342462881473913110540827237163350510684586298239947245938479716304835356329624224137216", "FFF0000000000000"),
  (IEEEReal.TO_NEAREST, "123456789012345678901234567890", "45F8EE90FF6C373E"),
  (IEEEReal.TO_NEAREST, "~123456789012345678901234567890", "C5F8EE90FF6C373E"),
  (IEEEReal.TO_NEAREST, "47861032893304332261201372162713173622784", "486194D4748A0CA2"),
  (IEEEReal.TO_NEAREST, "212274721979399028737", "442703CE9DEBD1C5"),
  (IEEEReal.TO_NEAREST, "23224501824331756095779001930938329", "4711E439B2B5289A"),
  (IEEEReal.TO_NEAREST, "2460397548491222481185404434251777", "46DE53A54FD23C69"),
  (IEEEReal.TO_NEAREST, "821901744639185458608557611024384", "46C442EDE24B65C8"),
  (IEEEReal.TO_NEAREST, "929657948004636759523523693924175294244139054282793452874296", "4C62834C3B7C45C9"),
  (IEEEReal.TO_NEAREST, "170092116484652231359273", "44C2025B26721146"),
  (IEEEReal.TO_NEAREST, "2959560274242967878408765461356449001499423679015989588", "4B3EE635506BF2F0"),
  (IEEEReal.TO_NEAREST, "1258702580758577820618022636526334115841", "480D978A64A1702A"),
  (IEEEReal.TO_NEAREST, "248628903473537720366730992750092127105971815274712955287226791293362679002376962049", "514061C08F1CC789"),
  (IEEEReal.TO_NEAREST, "~585850352274734830560219908876353633764091552574237801", "CB18775C4F7BBE1B"),
  (IEEEReal.TO_NEAREST, "~14218908674133307648415612765040333595264148189050431615881333654774091823972352", "D05EB3004737651E"),
  (IEEEReal.TO_NEAREST, "33595145226250346185890903876280300620927023645196289", "4AD672AECB5083C4"),
  (IEEEReal.TO_NEAREST, "5370153931075345702870326020048197203175407616", "496E19CB00B8D5E0"),
  (IEEEReal.TO_NEAREST, "~1131538601701648368651302167811650542407398669559005185", "CB27A0AC4238E19F"),
  (IEEEReal.TO_NEAREST, "~2384069502896815786733824642169995015995865777181882855", "CB38E40E8CA81811"),
  (IEEEReal.TO_NEAREST, "53450193942836679995392164552501515725666442472494944950702147959825475337816059999", "511C2C938969D817"),
  (IEEEReal.TO_NEAREST, "448313878905401041522717097984", "4616A2523224ED86"),
  (IEEEReal.TO_NEAREST, "33108533415971918", "435D68024952C314"),
  (IEEEReal.TO_NEAREST, "22410725122973512083663905238252445907392", "485076FD2A2CAC31"),
  (IEEEReal.TO_NEGINF, "41538374868278625639929989061148673", "4720000000000000"),
  (IEEEReal.TO_NEGINF, "~41538374868278625639929989061148673", "C720000000000001"),
  (IEEEReal.TO_NEGINF, "1267650600228229542234191560705", "4630000000000000"),
  (IEEEReal.TO_NEGINF, "~1267650600228229542234191560705", "C630000000000001"),
  (IEEEReal.TO_NEGINF, "1267650600228229542234191560704", "4630000000000000"),
  (IEEEReal.TO_NEGINF, "~1267650600228229542234191560704", "C630000000000001"),
  (IEEEReal.TO_NEGINF, "9007199254740993", "4340000000000000"),
  (IEEEReal.TO_NEGINF, "~9007199254740993", "C340000000000001"),
  (IEEEReal.TO_NEGINF, "9007199254740995", "4340000000000001"),
  (IEEEReal.TO_NEGINF, "~9007199254740995", "C340000000000002"),
  (IEEEReal.TO_NEGINF, "1152921504606847105", "43B0000000000000"),
  (IEEEReal.TO_NEGINF, "~1152921504606847105", "C3B0000000000001"),
  (IEEEReal.TO_NEGINF, "21267647932558653376165102605779861505", "47AFFFFFFFFFFFFF"),
  (IEEEReal.TO_NEGINF, "~21267647932558653376165102605779861505", "C7B0000000000000"),
  (IEEEReal.TO_NEGINF, "123456789012345678901234567890", "45F8EE90FF6C373E"),
  (IEEEReal.TO_NEGINF, "~123456789012345678901234567890", "C5F8EE90FF6C373F"),
  (IEEEReal.TO_NEGINF, "47861032893304332261201372162713173622784", "486194D4748A0CA2"),
  (IEEEReal.TO_NEGINF, "212274721979399028737", "442703CE9DEBD1C4"),
  (IEEEReal.TO_NEGINF, "23224501824331756095779001930938329", "4711E439B2B5289A"),
  (IEEEReal.TO_NEGINF, "2460397548491222481185404434251777", "46DE53A54FD23C68"),
  (IEEEReal.TO_NEGINF, "821901744639185458608557611024384", "46C442EDE24B65C7"),
  (IEEEReal.TO_NEGINF, "929657948004636759523523693924175294244139054282793452874296", "4C62834C3B7C45C8"),
  (IEEEReal.TO_NEGINF, "170092116484652231359273", "44C2025B26721146"),
  (IEEEReal.TO_NEGINF, "2959560274242967878408765461356449001499423679015989588", "4B3EE635506BF2EF"),
  (IEEEReal.TO_NEGINF, "1258702580758577820618022636526334115841", "480D978A64A17029"),
  (IEEEReal.TO_NEGINF, "248628903473537720366730992750092127105971815274712955287226791293362679002376962049", "514061C08F1CC788"),
  (IEEEReal.TO_NEGINF, "~585850352274734830560219908876353633764091552574237801", "CB18775C4F7BBE1B"),
  (IEEEReal.TO_NEGINF, "~14218908674133307648415612765040333595264148189050431615881333654774091823972352", "D05EB3004737651E"),
  (IEEEReal.TO_NEGINF, "33595145226250346185890903876280300620927023645196289", "4AD672AECB5083C3"),
  (IEEEReal.TO_NEGINF, "5370153931075345702870326020048197203175407616", "496E19CB00B8D5E0"),
  (IEEEReal.TO_NEGINF, "~1131538601701648368651302167811650542407398669559005185", "CB27A0AC4238E19F"),
  (IEEEReal.TO_NEGINF, "~2384069502896815786733824642169995015995865777181882855", "CB38E40E8CA81812"),
  (IEEEReal.TO_NEGINF, "53450193942836679995392164552501515725666442472494944950702147959825475337816059999", "511C2C938969D816"),
  (IEEEReal.TO_NEGINF, "448313878905401041522717097984", "4616A2523224ED86"),
  (IEEEReal.TO_NEGINF, "33108533415971918", "435D68024952C313"),
  (IEEEReal.TO_NEGINF, "22410725122973512083663905238252445907392", "485076FD2A2CAC31"),
  (IEEEReal.TO_POSINF, "41538374868278625639929989061148673", "4720000000000001"),
  (IEEEReal.TO_POSINF, "~41538374868278625639929989061148673", "C720000000000000"),
  (IEEEReal.TO_POSINF, "1267650600228229542234191560705", "4630000000000001"),
  (IEEEReal.TO_POSINF, "~1267650600228229542234191560705", "C630000000000000"),
  (IEEEReal.TO_POSINF, "1267650600228229542234191560704", "4630000000000001"),
  (IEEEReal.TO_POSINF, "~1267650600228229542234191560704", "C630000000000000"),
  (IEEEReal.TO_POSINF, "9007199254740993", "4340000000000001"),
  (IEEEReal.TO_POSINF, "~9007199254740993", "C340000000000000"),
  (IEEEReal.TO_POSINF, "9007199254740995", "4340000000000002"),
  (IEEEReal.TO_POSINF, "~9007199254740995", "C340000000000001"),
  (IEEEReal.TO_POSINF, "1152921504606847105", "43B0000000000001"),
  (IEEEReal.TO_POSINF, "~1152921504606847105", "C3B0000000000000"),
  (IEEEReal.TO_POSINF, "21267647932558653376165102605779861505", "47B0000000000000"),
  (IEEEReal.TO_POSINF, "~21267647932558653376165102605779861505", "C7AFFFFFFFFFFFFF"),
  (IEEEReal.TO_POSINF, "123456789012345678901234567890", "45F8EE90FF6C373F"),
  (IEEEReal.TO_POSINF, "~123456789012345678901234567890", "C5F8EE90FF6C373E"),
  (IEEEReal.TO_POSINF, "47861032893304332261201372162713173622784", "486194D4748A0CA3"),
  (IEEEReal.TO_POSINF, "212274721979399028737", "442703CE9DEBD1C5"),
  (IEEEReal.TO_POSINF, "23224501824331756095779001930938329", "4711E439B2B5289B"),
  (IEEEReal.TO_POSINF, "2460397548491222481185404434251777", "46DE53A54FD23C69"),
  (IEEEReal.TO_POSINF, "821901744639185458608557611024384", "46C442EDE24B65C8"),
  (IEEEReal.TO_POSINF, "929657948004636759523523693924175294244139054282793452874296", "4C62834C3B7C45C9"),
  (IEEEReal.TO_POSINF, "170092116484652231359273", "44C2025B26721147"),
  (IEEEReal.TO_POSINF, "2959560274242967878408765461356449001499423679015989588", "4B3EE635506BF2F0"),
  (IEEEReal.TO_POSINF, "1258702580758577820618022636526334115841", "480D978A64A1702A"),
  (IEEEReal.TO_POSINF, "248628903473537720366730992750092127105971815274712955287226791293362679002376962049", "514061C08F1CC789"),
  (IEEEReal.TO_POSINF, "~585850352274734830560219908876353633764091552574237801", "CB18775C4F7BBE1A"),
  (IEEEReal.TO_POSINF, "~14218908674133307648415612765040333595264148189050431615881333654774091823972352", "D05EB3004737651D"),
  (IEEEReal.TO_POSINF, "33595145226250346185890903876280300620927023645196289", "4AD672AECB5083C4"),
  (IEEEReal.TO_POSINF, "5370153931075345702870326020048197203175407616", "496E19CB00B8D5E1"),
  (IEEEReal.TO_POSINF, "~1131538601701648368651302167811650542407398669559005185", "CB27A0AC4238E19E"),
  (IEEEReal.TO_POSINF, "~2384069502896815786733824642169995015995865777181882855", "CB38E40E8CA81811"),
  (IEEEReal.TO_POSINF, "53450193942836679995392164552501515725666442472494944950702147959825475337816059999", "511C2C938969D817"),
  (IEEEReal.TO_POSINF, "448313878905401041522717097984", "4616A2523224ED87"),
  (IEEEReal.TO_POSINF, "33108533415971918", "435D68024952C314"),
  (IEEEReal.TO_POSINF, "22410725122973512083663905238252445907392", "485076FD2A2CAC32"),
  (IEEEReal.TO_ZERO, "41538374868278625639929989061148673", "4720000000000000"),
  (IEEEReal.TO_ZERO, "~41538374868278625639929989061148673", "C720000000000000"),
  (IEEEReal.TO_ZERO, "1267650600228229542234191560705", "4630000000000000"),
  (IEEEReal.TO_ZERO, "~1267650600228229542234191560705", "C630000000000000"),
  (IEEEReal.TO_ZERO, "1267650600228229542234191560704", "4630000000000000"),
  (IEEEReal.TO_ZERO, "~1267650600228229542234191560704", "C630000000000000"),
  (IEEEReal.TO_ZERO, "9007199254740993", "4340000000000000"),
  (IEEEReal.TO_ZERO, "~9007199254740993", "C340000000000000"),
  (IEEEReal.TO_ZERO, "9007199254740995", "4340000000000001"),
  (IEEEReal.TO_ZERO, "~9007199254740995", "C340000000000001"),
  (IEEEReal.TO_ZERO, "1152921504606847105", "43B0000000000000"),
  (IEEEReal.TO_ZERO, "~1152921504606847105", "C3B0000000000000"),
  (IEEEReal.TO_ZERO, "21267647932558653376165102605779861505", "47AFFFFFFFFFFFFF"),
  (IEEEReal.TO_ZERO, "~21267647932558653376165102605779861505", "C7AFFFFFFFFFFFFF"),
  (IEEEReal.TO_ZERO, "123456789012345678901234567890", "45F8EE90FF6C373E"),
  (IEEEReal.TO_ZERO, "~123456789012345678901234567890", "C5F8EE90FF6C373E"),
  (IEEEReal.TO_ZERO, "47861032893304332261201372162713173622784", "486194D4748A0CA2"),
  (IEEEReal.TO_ZERO, "212274721979399028737", "442703CE9DEBD1C4"),
  (IEEEReal.TO_ZERO, "23224501824331756095779001930938329", "4711E439B2B5289A"),
  (IEEEReal.TO_ZERO, "2460397548491222481185404434251777", "46DE53A54FD23C68"),
  (IEEEReal.TO_ZERO, "821901744639185458608557611024384", "46C442EDE24B65C7"),
  (IEEEReal.TO_ZERO, "929657948004636759523523693924175294244139054282793452874296", "4C62834C3B7C45C8"),
  (IEEEReal.TO_ZERO, "170092116484652231359273", "44C2025B26721146"),
  (IEEEReal.TO_ZERO, "2959560274242967878408765461356449001499423679015989588", "4B3EE635506BF2EF"),
  (IEEEReal.TO_ZERO, "1258702580758577820618022636526334115841", "480D978A64A17029"),
  (IEEEReal.TO_ZERO, "248628903473537720366730992750092127105971815274712955287226791293362679002376962049", "514061C08F1CC788"),
  (IEEEReal.TO_ZERO, "~585850352274734830560219908876353633764091552574237801", "CB18775C4F7BBE1A"),
  (IEEEReal.TO_ZERO, "~14218908674133307648415612765040333595264148189050431615881333654774091823972352", "D05EB3004737651D"),
  (IEEEReal.TO_ZERO, "33595145226250346185890903876280300620927023645196289", "4AD672AECB5083C3"),
  (IEEEReal.TO_ZERO, "5370153931075345702870326020048197203175407616", "496E19CB00B8D5E0"),
  (IEEEReal.TO_ZERO, "~1131538601701648368651302167811650542407398669559005185", "CB27A0AC4238E19E"),
  (IEEEReal.TO_ZERO, "~2384069502896815786733824642169995015995865777181882855", "CB38E40E8CA81811"),
  (IEEEReal.TO_ZERO, "53450193942836679995392164552501515725666442472494944950702147959825475337816059999", "511C2C938969D816"),
  (IEEEReal.TO_ZERO, "448313878905401041522717097984", "4616A2523224ED86"),
  (IEEEReal.TO_ZERO, "33108533415971918", "435D68024952C313"),
  (IEEEReal.TO_ZERO, "22410725122973512083663905238252445907392", "485076FD2A2CAC31")
]
fun modeName IEEEReal.TO_NEAREST = "TO_NEAREST" | modeName IEEEReal.TO_NEGINF = "TO_NEGINF"
  | modeName IEEEReal.TO_POSINF = "TO_POSINF" | modeName IEEEReal.TO_ZERO = "TO_ZERO"
val bad = ref 0
val () = List.app (fn (mode, n, expected) =>
  let val () = IEEEReal.setRoundingMode mode
      val got = hex (Real.fromLargeInt (valOf (IntInf.fromString n)))
      val () = IEEEReal.setRoundingMode IEEEReal.TO_NEAREST
  in if got = expected then () else
       (bad := !bad + 1;
        if !bad <= 8 then print (concat [modeName mode, ": fromLargeInt ", n, " = 0x", got, ", expected 0x", expected, "\n"]) else ())
  end) cases
val () = print (Int.toString (!bad) ^ " of " ^ Int.toString (length cases) ^ " wrong\n")
val () = OS.Process.exit OS.Process.success
```

### Additional Information

`IntInfToReal64.cvt` has three faults:
* on 64 bits it computes `w2r d1 + rbase * w2r d2` from the top two 62-bit
  digits; `w2r d2` rounds a digit of up to 62 bits, and the sum rounds
  again;
* it drops the digits below the top two without a sticky bit;
* `dosign` negates after rounding.

For 2^115 + 2^62 + 1, `d2` is 2^53 + 1, whose conversion ties to 2^53, and
the `+ 1` can no longer move the sum above the midpoint. The 32-bit version
does the same with three 30-bit digits.

The patch takes the 55 bits of the magnitude below its top, ORs a sticky
bit into the lowest for any 1 below them, applies the sign, and converts
with one rounding. On 32 bits that is two exact parts, `hi * 2^30 + lo`,
added once. Then `scalb` scales exactly. It is against legacy `main`
(`6ed5a0a`) and also applies to 110.99.9:

```diff
diff --git a/base/system/Basis/Implementation/Target32Bit/intinf-to-real64.sml b/base/system/Basis/Implementation/Target32Bit/intinf-to-real64.sml
index 644d631..5807326 100644
--- a/base/system/Basis/Implementation/Target32Bit/intinf-to-real64.sml
+++ b/base/system/Basis/Implementation/Target32Bit/intinf-to-real64.sml
@@ -13,6 +13,8 @@ structure IntInfToReal64 : sig
 
   end = struct
 
+    structure W = InlineT.Word
+
     val fromInt32 : Int32.int -> real = InlineT.Real64.from_int32
     fun w2r w = fromInt32(InlineT.Int32.fromLarge(InlineT.Word.toLargeInt w))
     val baseBits = InlineT.Word.toIntX CoreIntInf.baseBits
@@ -20,27 +22,66 @@ structure IntInfToReal64 : sig
     val rbase = w2r CoreIntInf.base
 
   (* some protection against insanity... *)
-    val _ = if baseBits < 18  (* i.e., 3 * baseBits < 53 *)
-	  then raise Fail "big digits in intinf implementation do not have enough bits"
+    val _ = if baseBits <> 30
+	  then raise Fail "unexpected baseBits in intinf implementation"
 	  else ()
 
+  (* the number of bits of a digit *)
+    fun bitLen w = let
+	  fun lp (0w0, n) = n
+	    | lp (w, n) = lp (W.rshiftl (w, 0w1), n + 1)
+	  in
+	    lp (w, 0)
+	  end
+
+  (* the i'th digit, least significant first, or 0 *)
+    fun digit (d :: _, 0) = d
+      | digit (_ :: ds, i) = digit (ds, i - 1)
+      | digit ([], _) = 0w0
+
+  (* are all the digits before the i'th 0? *)
+    fun zeroBelow (_, 0) = true
+      | zeroBelow (d :: ds, i) = (d = 0w0) andalso zeroBelow (ds, i - 1)
+      | zeroBelow ([], _) = true
+
+  (* the w (<= 30) bits of the magnitude from bit p up *)
+    fun bitsAt (digits, p, w) = let
+	  val i = p div baseBits
+	  val off = W.fromInt (p mod baseBits)
+	  val lo = W.rshiftl (digit (digits, i), off)
+	  val bits = if off = 0w0 then lo
+		else W.orb (lo, W.lshift (digit (digits, i + 1), 0w30 - off))
+	  in
+	    W.andb (bits, W.lshift (0w1, W.fromInt w) - 0w1)
+	  end
+
+  (* The result is rounded once, in the current rounding mode, from the number with
+   * its sign: from at most 60 bits, which are exact as two reals, or from 55 bits of
+   * the magnitude below its top and a sticky bit for the bits under them, which
+   * rounds as the whole number does.
+   *)
     fun cvt (x : IntInf.int) = let
 	  val CoreIntInf.BI{ negative, digits } = CoreIntInf.concrete x
-	  fun dosign (x : real) = if negative then ~x else x
-	(* We need at most three "big digits" to get 53 bits of precision...
-	 * (See insanity insurance above.)
-	 *)
-	  fun calc (k, d1, d2, d3, []) =
-		dosign (Assembly.A.scalb (w2r d1 +
-					  rbase * (w2r d2 + rbase * w2r d3),
-					  k))
-	    | calc (k, _, d1, d2, d3 :: r) = calc (k + baseBits, d1, d2, d3, r)
+	  fun signed w = if negative then ~(w2r w) else w2r w
 	  in
 	    case digits
 	     of [] => 0.0
-	      | [d] => dosign (w2r d)
-	      | [d1, d2] => dosign (rbase * w2r d2 + w2r d1)
-	      | d1 :: d2 :: d3 :: r => calc (0, d1, d2, d3, r)
+	      | [d] => signed d
+	      | [d0, d1] => rbase * signed d1 + signed d0
+	      | _ => let
+		  fun last [d] = d
+		    | last (_ :: ds) = last ds
+		    | last [] = 0w0
+		  val k = baseBits * (length digits - 1) + bitLen (last digits) - 55
+		  val lo = bitsAt (digits, k, 30)
+		  val hi = bitsAt (digits, k + 30, 25)
+		  val sticky = not (zeroBelow (digits, k div baseBits)
+			andalso W.andb (digit (digits, k div baseBits),
+			      W.lshift (0w1, W.fromInt (k mod baseBits)) - 0w1) = 0w0)
+		  val lo = if sticky then W.orb (lo, 0w1) else lo
+		  in
+		    Assembly.A.scalb (rbase * signed hi + signed lo, k)
+		  end
 	    (* end case *)
 	  end
 
diff --git a/base/system/Basis/Implementation/Target64Bit/intinf-to-real64.sml b/base/system/Basis/Implementation/Target64Bit/intinf-to-real64.sml
index 715a4ff..cf9f705 100644
--- a/base/system/Basis/Implementation/Target64Bit/intinf-to-real64.sml
+++ b/base/system/Basis/Implementation/Target64Bit/intinf-to-real64.sml
@@ -13,32 +13,70 @@ structure IntInfToReal64 : sig
 
   end = struct
 
+    structure W = InlineT.Word
+
     val fromInt64 : Int64.int -> real = InlineT.Real64.from_int64
-    fun w2r w = fromInt64(InlineT.Int64.fromLarge(InlineT.Word.toLargeInt w))
+    fun w2i w = InlineT.Int64.fromLarge(InlineT.Word.toLargeInt w)
     val baseBits = InlineT.Word.toIntX CoreIntInf.baseBits
 
-    val rbase = w2r CoreIntInf.base
-
   (* some protection against insanity... *)
     val _ = if baseBits <> 62
 	  then raise Fail "unexpected baseBits in intinf implementation"
 	  else ()
 
+  (* the number of bits of a digit *)
+    fun bitLen w = let
+	  fun lp (0w0, n) = n
+	    | lp (w, n) = lp (W.rshiftl (w, 0w1), n + 1)
+	  in
+	    lp (w, 0)
+	  end
+
+  (* the i'th digit, least significant first, or 0 *)
+    fun digit (d :: _, 0) = d
+      | digit (_ :: ds, i) = digit (ds, i - 1)
+      | digit ([], _) = 0w0
+
+  (* are all the digits before the i'th 0? *)
+    fun zeroBelow (_, 0) = true
+      | zeroBelow (d :: ds, i) = (d = 0w0) andalso zeroBelow (ds, i - 1)
+      | zeroBelow ([], _) = true
+
+  (* the w (<= 62) bits of the magnitude from bit p up *)
+    fun bitsAt (digits, p, w) = let
+	  val i = p div baseBits
+	  val off = W.fromInt (p mod baseBits)
+	  val lo = W.rshiftl (digit (digits, i), off)
+	  val bits = if off = 0w0 then lo
+		else W.orb (lo, W.lshift (digit (digits, i + 1), 0w62 - off))
+	  in
+	    W.andb (bits, W.lshift (0w1, W.fromInt w) - 0w1)
+	  end
+
+  (* The result is rounded once, in the current rounding mode, from the number with
+   * its sign: from a single digit, or from 55 bits of the magnitude below its top and
+   * a sticky bit for the bits under them, which rounds as the whole number does.
+   *)
     fun cvt (x : IntInf.int) = let
 	  val CoreIntInf.BI{ negative, digits } = CoreIntInf.concrete x
-	  fun dosign (x : real) = if negative then ~x else x
-	(* We need at most two "big digits" to get 53 bits of precision...
-	 * (See insanity insurance above.)
-	 *)
-	  fun calc (k, d1, d2, []) =
-		dosign (Assembly.A.scalb (w2r d1 + rbase * w2r d2, k))
-	    | calc (k, _, d1, d2 :: r) = calc (k + baseBits, d1, d2, r)
+	  fun signed w = if negative then fromInt64 (InlineT.Int64.~ (w2i w)) else fromInt64 (w2i w)
 	  in
 	    case digits
 	     of [] => 0.0
-	      | [d] => dosign (w2r d)
-	      | [d1, d2] => dosign (w2r d1 + rbase * w2r d2)
-	      | d1 :: d2 :: r => calc (0, d1, d2, r)
+	      | [d] => signed d
+	      | _ => let
+		  fun last [d] = d
+		    | last (_ :: ds) = last ds
+		    | last [] = 0w0
+		  val k = baseBits * (length digits - 1) + bitLen (last digits) - 55
+		  val m = bitsAt (digits, k, 55)
+		  val sticky = not (zeroBelow (digits, k div baseBits)
+			andalso W.andb (digit (digits, k div baseBits),
+			      W.lshift (0w1, W.fromInt (k mod baseBits)) - 0w1) = 0w0)
+		  val m = if sticky then W.orb (m, 0w1) else m
+		  in
+		    Assembly.A.scalb (signed m, k)
+		  end
 	    (* end case *)
 	  end
 
```

Tested with a fixed point for 32 and 64 bits: 0 of 148 wrong on both.
(Separately: on Windows, `IEEEReal.setRoundingMode` seems to have no
effect: `1.0 / 3.0` is the same under `TO_POSINF` and `TO_NEGINF`.)
