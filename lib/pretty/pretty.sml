(* Pretty: documents laid out strictly (Lindig, "Strictly Pretty", 2000).

   Implements: PRETTY *)
structure Pretty :> PRETTY =
struct
  datatype 'a doc =
      Empty
    | Txt of string
    | Sized of string * int      (* text, and the columns it takes *)
    | Break of string * int      (* what it is when flat, and the offset of the newline *)
    | Hard
    | Cat of 'a doc list
    | Nest of int * 'a doc
    | Align of 'a doc            (* indented to the column it begins at *)
    | Group of 'a doc
    | Ann of 'a * 'a doc
    | Seq of {opening : string, closing : string, separator : string} * 'a doc list

  datatype 'a piece = Text of string | Newline of int | Begin of 'a | End

  val empty = Empty
  fun text s = Txt s
  val line = Break (" ", 0)
  val cut = Break ("", 0)
  val hardline = Hard
  fun break (blanks, offset) = Break (CharVector.tabulate (Int.max (0, blanks), fn _ => #" "), offset)
  fun sized (s, w) = Sized (s, w)
  fun concat ds = Cat ds
  fun nest n d = Nest (n, d)
  fun align d = Align d
  fun group d = Group d
  fun annotate (a, d) = Ann (a, d)
  fun sequence brackets ds = Seq (brackets, ds)
  val ellipsis = Txt "..."

  fun width s = DisplayWidth.columns s

  (* a sequence as the documents it is made of *)
  fun expand ({opening, closing, separator}, ds) =
    let
      fun items [] = []
        | items [d] = [d]
        | items (d :: rest) = d :: Txt separator :: Break (" ", 0) :: items rest
    in
      Group (Align (Cat [Txt opening, Nest (width opening, Cat (items ds)), Txt closing]))
    end

  fun bound {depth, length, nodes} d =
    let
      val count = ref 0
      fun over (SOME n, k) = k > n
        | over (NONE, _) = false
      fun go (level, d) =
        case d of
          Seq (b, ds) =>
            if over (depth, level + 1) then ellipsis
            else
              let
                fun items (_, []) = []
                  | items (k, x :: rest) =
                      if over (length, k + 1) then [ellipsis]
                      else (count := !count + 1;
                            if over (nodes, !count) then [ellipsis]
                            else go (level + 1, x) :: items (k + 1, rest))
              in
                Seq (b, items (0, ds))
              end
        | Cat ds => Cat (map (fn x => go (level, x)) ds)
        | Nest (n, x) => Nest (n, go (level, x))
        | Align x => Align (go (level, x))
        | Group x => Group (go (level, x))
        | Ann (a, x) => Ann (a, go (level, x))
        | other => other
    in
      go (0, d)
    end

  datatype mode = Flat | Broken

  (* what is left to lay out: documents, and the ends of annotations *)
  datatype 'a item = Doc of int * mode * 'a doc | Close

  (* whether the items fit in w columns: up to the first break of a group
     that is broken, which ends the line *)
  fun fits (w, items) =
    w >= 0 andalso
    (case items of
       [] => true
     | Close :: rest => fits (w, rest)
     | Doc (i, m, d) :: rest =>
         case d of
           Empty => fits (w, rest)
         | Txt s => fits (w - width s, rest)
         | Sized (_, k) => fits (w - k, rest)
         | Break (s, _) => (case m of Flat => fits (w - width s, rest) | Broken => true)
         | Hard => (case m of Flat => false | Broken => true)
         | Cat ds => fits (w, map (fn x => Doc (i, m, x)) ds @ rest)
         | Nest (n, x) => fits (w, Doc (i + n, m, x) :: rest)
         | Align x => fits (w, Doc (i, m, x) :: rest)
         | Group x => fits (w, Doc (i, m, x) :: rest)
         | Ann (_, x) => fits (w, Doc (i, m, x) :: rest)
         | Seq sq => fits (w, Doc (i, m, expand sq) :: rest))

  fun layout w d =
    let
      fun go (_, [], acc) = rev acc
        | go (col, Close :: rest, acc) = go (col, rest, End :: acc)
        | go (col, Doc (i, m, d) :: rest, acc) =
            case d of
              Empty => go (col, rest, acc)
            | Txt s => go (col + width s, rest, Text s :: acc)
            | Sized (s, k) => go (col + k, rest, Text s :: acc)
            | Break (s, off) =>
                (case m of
                   Flat => go (col + width s, rest, (if s = "" then acc else Text s :: acc))
                 | Broken => go (i + off, rest, Newline (i + off) :: acc))
            | Hard => go (i, rest, Newline i :: acc)
            | Cat ds => go (col, map (fn x => Doc (i, m, x)) ds @ rest, acc)
            | Nest (n, x) => go (col, Doc (i + n, m, x) :: rest, acc)
            | Align x => go (col, Doc (col, m, x) :: rest, acc)
            | Group x =>
                (case m of
                   Flat => go (col, Doc (i, Flat, x) :: rest, acc)
                 | Broken =>
                     let val m' = if fits (w - col, Doc (i, Flat, x) :: rest) then Flat else Broken
                     in go (col, Doc (i, m', x) :: rest, acc) end)
            | Ann (a, x) => go (col, Doc (i, m, x) :: Close :: rest, Begin a :: acc)
            | Seq sq => go (col, Doc (i, m, expand sq) :: rest, acc)
    in
      go (0, [Doc (0, Broken, d)], [])
    end

  fun renderWith {width = w, start, finish} d =
    let
      val opened = ref []
      fun piece (Text s) = s
        | piece (Newline i) = "\n" ^ CharVector.tabulate (i, fn _ => #" ")
        | piece (Begin a) = (opened := a :: !opened; start a)
        | piece End = (case !opened of a :: rest => (opened := rest; finish a) | [] => "")
    in
      String.concat (map piece (layout w d))
    end

  fun render w d = renderWith {width = w, start = fn _ => "", finish = fn _ => ""} d

  fun flat d =
    let
      fun go (Empty, acc) = acc
        | go (Txt s, acc) = s :: acc
        | go (Sized (s, _), acc) = s :: acc
        | go (Break (s, _), acc) = s :: acc
        | go (Hard, acc) = "\n" :: acc
        | go (Cat ds, acc) = foldl go acc ds
        | go (Nest (_, x), acc) = go (x, acc)
        | go (Align x, acc) = go (x, acc)
        | go (Group x, acc) = go (x, acc)
        | go (Ann (_, x), acc) = go (x, acc)
        | go (Seq sq, acc) = go (expand sq, acc)
    in
      String.concat (rev (go (d, [])))
    end
end
