(* The arbitraries of the data of the Basis Library that are neither numbers
   nor text (docs/plans/quickcheck.md, M6): datatypes, dates, times and
   decimal approximations, and readers. *)

(* The integers of the documented range [lo, hi] widened on each side by its
   own width: what P12 draws a field of a record from. *)
structure PropertyAround =
struct
  fun around (lo : int, hi : int) : int Gen.gen = Gen.intRange (lo - (hi - lo + 1), hi + (hi - lo + 1))
end

(* The arbitrary of `Time.time`: `Time.fromNanoseconds` of a number of
   nanoseconds drawn by the generator principle P1 over the range that the
   implementation's times hold, which the specification leaves to it and
   which is found by doubling a time until `Time` is raised (P12); by P2 where
   no such range is found below 2^200. *)
structure TimeArb : ARB_OF where type t = Time.time =
struct
  type t = Time.time

  fun ns (t : Time.time) : string = LargeInt.toString (Time.toNanoseconds t)

  fun fits (n : IntInf.int) : bool = (ignore (Time.fromNanoseconds (IntInf.toLarge n)); true) handle _ => false

  (* the most nanoseconds a time holds, either way *)
  val limit : IntInf.int option =
    let
      fun up (n, k) = if k > 200 then NONE else if fits (n * 2) andalso fits (~ (n * 2)) then up (n * 2, k + 1) else SOME n
      fun search (lo, hi) =
        if hi - lo <= 1 then lo
        else let val m = (lo + hi) div 2 in if fits m andalso fits (~m) then search (m, hi) else search (lo, m) end
    in
      Option.map (fn n => search (n, 2 * n)) (up (1, 0))
    end

  val arb : Time.time Arb.arb =
    {gen = Gen.map (fn i => Time.fromNanoseconds (IntInf.toLarge i))
                   (case limit of SOME m => Gen.intInfRange (~m, m) | NONE => Gen.intInf),
     show = fn t => "Time.fromNanoseconds " ^ Show.parens (ns t),
     co = fn t => Random.hashString (ns t), eq = SOME (op =)}
end

(* Implements: DATE_ARB *)
structure DateArb :> DATE_ARB =
struct
  type t = Date.date

  val months = [(Date.Jan, "Date.Jan"), (Date.Feb, "Date.Feb"), (Date.Mar, "Date.Mar"), (Date.Apr, "Date.Apr"),
                (Date.May, "Date.May"), (Date.Jun, "Date.Jun"), (Date.Jul, "Date.Jul"), (Date.Aug, "Date.Aug"),
                (Date.Sep, "Date.Sep"), (Date.Oct, "Date.Oct"), (Date.Nov, "Date.Nov"), (Date.Dec, "Date.Dec")]
  val month = Arb.enum months
  val weekday = Arb.enum [(Date.Mon, "Date.Mon"), (Date.Tue, "Date.Tue"), (Date.Wed, "Date.Wed"), (Date.Thu, "Date.Thu"),
                          (Date.Fri, "Date.Fri"), (Date.Sat, "Date.Sat"), (Date.Sun, "Date.Sun")]

  type fields = {year : int, month : Date.month, day : int, hour : int, minute : int, second : int,
                 offset : Time.time option}

  fun offsetIn (seconds : int) : Time.time option Gen.gen =
    Gen.option (Gen.map (fn s => Time.fromSeconds (LargeInt.fromInt s)) (Gen.intRange (~seconds, seconds)))

  fun make (year, day, hour, minute, second) (m, offset) : fields =
    {year = year, month = m, day = day, hour = hour, minute = minute, second = second, offset = offset}

  fun fieldsGen (year, day, hour, minute, second, offset) : fields Gen.gen =
    Gen.map2 (fn ((y, d, h), (mi, s, (m, off))) => make (y, d, h, mi, s) (m, off))
             (Gen.triple (year, day, hour), Gen.triple (minute, second, Gen.pair (#gen month, offset)))

  fun showTime (t : Time.time) : string = #show TimeArb.arb t
  fun showFields ({year, month = m, day, hour, minute, second, offset} : fields) : string =
    "{year = " ^ Int.toString year ^ ", month = " ^ #show month m ^ ", day = " ^ Int.toString day
    ^ ", hour = " ^ Int.toString hour ^ ", minute = " ^ Int.toString minute ^ ", second = " ^ Int.toString second
    ^ ", offset = " ^ Show.option showTime offset ^ "}"
  fun coFields ({year, month = m, day, hour, minute, second, offset} : fields) : Word64.word =
    Co.triple (Co.triple (Co.int, #co month, Co.int), Co.triple (Co.int, Co.int, Co.int), Co.option (#co TimeArb.arb))
              ((year, m, day), (hour, minute, second), offset)

  val fields : fields Arb.arb =
    {gen = fieldsGen (Gen.int, PropertyAround.around (1, 31), PropertyAround.around (0, 23),
                      PropertyAround.around (0, 59), PropertyAround.around (0, 59), offsetIn (2 * 86400)),
     show = showFields, co = coFields, eq = SOME (op =)}

  fun fieldsOf (d : Date.date) : fields =
    {year = Date.year d, month = Date.month d, day = Date.day d, hour = Date.hour d, minute = Date.minute d,
     second = Date.second d, offset = Date.offset d}

  val arb : Date.date Arb.arb =
    {gen = Gen.map Date.date (fieldsGen (Gen.intRange (1900, 2200), Gen.intRange (1, 31), Gen.intRange (0, 23),
                                         Gen.intRange (0, 59), Gen.intRange (0, 59), offsetIn 86400)),
     show = fn d => "Date.date " ^ showFields (fieldsOf d),
     co = fn d => coFields (fieldsOf d),
     eq = SOME (fn (d, e) => Date.compare (d, e) = EQUAL andalso Date.offset d = Date.offset e)}
end

(* Implements: IEEE_REAL_ARB *)
structure IEEERealArb :> IEEE_REAL_ARB =
struct
  val roundingMode = Arb.enum [(IEEEReal.TO_NEAREST, "IEEEReal.TO_NEAREST"), (IEEEReal.TO_NEGINF, "IEEEReal.TO_NEGINF"),
                               (IEEEReal.TO_POSINF, "IEEEReal.TO_POSINF"), (IEEEReal.TO_ZERO, "IEEEReal.TO_ZERO")]
  val floatClass = Arb.enum [(IEEEReal.NAN, "IEEEReal.NAN"), (IEEEReal.INF, "IEEEReal.INF"), (IEEEReal.ZERO, "IEEEReal.ZERO"),
                             (IEEEReal.NORMAL, "IEEEReal.NORMAL"), (IEEEReal.SUBNORMAL, "IEEEReal.SUBNORMAL")]

  val decimalApprox : IEEEReal.decimal_approx Arb.arb =
    {gen = Gen.map2 (fn ((class, sign), (digits, exp)) => {class = class, sign = sign, digits = digits, exp = exp})
                    (Gen.pair (#gen floatClass, Gen.bool), Gen.pair (Gen.list (PropertyAround.around (0, 9)), Gen.int)),
     show = fn {class, sign, digits, exp} =>
              "{class = " ^ #show floatClass class ^ ", sign = " ^ Bool.toString sign ^ ", digits = "
              ^ Show.list Show.int digits ^ ", exp = " ^ Int.toString exp ^ "}",
     co = fn {class, sign, digits, exp} =>
            Co.pair (Co.pair (#co floatClass, Co.bool), Co.pair (Co.list Co.int, Co.int)) ((class, sign), (digits, exp)),
     eq = SOME (op =)}
end

(* Implements: BASIS_DATA_ARB *)
structure BasisDataArb :> BASIS_DATA_ARB =
struct
  val bufferMode = Arb.enum [(IO.NO_BUF, "IO.NO_BUF"), (IO.LINE_BUF, "IO.LINE_BUF"), (IO.BLOCK_BUF, "IO.BLOCK_BUF")]
  val radix = Arb.enum [(StringCvt.BIN, "StringCvt.BIN"), (StringCvt.OCT, "StringCvt.OCT"),
                        (StringCvt.DEC, "StringCvt.DEC"), (StringCvt.HEX, "StringCvt.HEX")]
  val traversal = Arb.enum [(Array2.RowMajor, "Array2.RowMajor"), (Array2.ColMajor, "Array2.ColMajor")]

  fun readerOf (s : string) : (char, int) StringCvt.reader =
    fn i => if i >= 0 andalso i < String.size s then SOME (String.sub (s, i), i + 1) else NONE

  (* a reader has no equality; the one of the string it was drawn from is
     not kept with it, so the printer shows the characters it reads from 0 *)
  fun contents (r : (char, int) StringCvt.reader) : string =
    let fun go (i, acc) = case r i of SOME (c, j) => if j > i then go (j, c :: acc) else String.implode (List.rev (c :: acc))
                                    | NONE => String.implode (List.rev acc)
    in go (0, []) end

  val reader : (char, int) StringCvt.reader Arb.arb =
    {gen = Gen.map readerOf Gen.string,
     show = fn r => let val s = contents r
                    in "(fn i => if i >= 0 andalso i < " ^ Int.toString (String.size s) ^ " then SOME (String.sub ("
                       ^ Show.string s ^ ", i), i + 1) else NONE)"
                    end,
     co = fn r => Random.hashString (contents r), eq = NONE}
end
