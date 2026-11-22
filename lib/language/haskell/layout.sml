(* Implements: HS_LAYOUT *)
structure HsLayout :> HS_LAYOUT =
struct
  structure T = HsToken

  val empty : T.item vector = Vector.fromList []
  val file = ref ""
  val toks = ref empty
  (* the next written token to read *)
  val idx = ref 0
  (* the layout contexts, innermost first: 0 for explicit braces *)
  val ctx : int list ref = ref []
  val current = ref T.EOF
  (* the written token the current one is, or, for one of layout's, the
     next written one *)
  val curIdx = ref 0
  (* a {n} is owed before the next written token *)
  val pendOpen = ref false
  (* an <n> is owed before the next written token *)
  val pendBol = ref false
  (* the } of an empty block is owed *)
  val pendClose = ref false
  val stop = ref 0

  fun item k = Vector.sub (!toks, k)

  fun isVirtual t =
    case t of T.VLBRACE => true | T.VSEMI => true | T.VRBRACE => true | _ => false

  fun here () =
    let val {start, stop, ...} = item (!curIdx)
    in
      if isVirtual (!current) then {file = !file, start = start, stop = start}
      else {file = !file, start = start, stop = stop}
    end

  fun currentStart () = #start (item (!curIdx))

  fun trivia () = if isVirtual (!current) then [] else #trivia (item (!curIdx))
  fun lastStop () = !stop

  fun fail msg = raise HsSource.Error (here (), msg)

  fun peek k =
    let val v = !toks val j = !idx + k
    in if j < Vector.length v then #token (Vector.sub (v, j)) else T.EOF end

  fun setVirtual t = (current := t; curIdx := !idx)

  fun rawNext () =
    let val {token, ...} = item (!idx)
    in
      case token of
        T.EOF =>
          (curIdx := !idx;
           case !ctx of
             [] => current := T.EOF
           | 0 :: _ => (current := T.EOF; fail "the end of the input inside braces: a `{` is not closed")
           | _ :: ms => (ctx := ms; setVirtual T.VRBRACE))
      | _ =>
          (curIdx := !idx;
           idx := !idx + 1;
           current := token;
           let
             val {token = next, first, ...} = item (!idx)
             val brace = case next of T.LBRACE => true | _ => false
             fun opener () = if brace then pendBol := first else pendOpen := true
           in
             case token of
               T.LET => opener ()
             | T.WHERE => opener ()
             | T.OF => opener ()
             | T.DO => opener ()
             | _ => pendBol := first
           end)
    end

  fun fetch () =
    if !pendOpen then
      let
        val () = pendOpen := false
        val {token, column, ...} = item (!idx)
        val n = case token of T.EOF => 0 | _ => column
        fun openBlock () = (ctx := n :: !ctx; setVirtual T.VLBRACE)
        fun emptyBlock () = (pendClose := true; setVirtual T.VLBRACE)
      in
        case !ctx of
          m :: _ => if n > m then openBlock () else emptyBlock ()
        | [] => if n > 0 then openBlock () else emptyBlock ()
      end
    else if !pendClose then
      (pendClose := false;
       (case #token (item (!idx)) of T.EOF => () | _ => pendBol := true);
       setVirtual T.VRBRACE)
    else if !pendBol then
      (case !ctx of
         m :: ms =>
           let val n = #column (item (!idx))
           in
             if n = m then (pendBol := false; setVirtual T.VSEMI)
             else if n < m then (ctx := ms; setVirtual T.VRBRACE)
             else (pendBol := false; rawNext ())
           end
       | [] => (pendBol := false; rawNext ()))
    else rawNext ()

  fun advance () =
    let val t = !current
    in
      case t of
        T.LBRACE => ctx := 0 :: !ctx
      | T.RBRACE =>
          (case !ctx of
             0 :: ms => ctx := ms
           | _ => fail "a `}` that no `{` opened")
      | _ => ();
      if isVirtual t then () else stop := #stop (item (!curIdx));
      fetch ()
    end

  fun closeImplicit () =
    case !ctx of
      [] => false
    | 0 :: _ => false
    | _ :: ms => (ctx := ms; true)

  type mark =
    {idx : int, ctx : int list, current : T.token, curIdx : int, pendOpen : bool,
     pendBol : bool, pendClose : bool, stop : int}

  fun save () : mark =
    {idx = !idx, ctx = !ctx, current = !current, curIdx = !curIdx, pendOpen = !pendOpen,
     pendBol = !pendBol, pendClose = !pendClose, stop = !stop}

  fun restore (m : mark) =
    (idx := #idx m; ctx := #ctx m; current := #current m; curIdx := #curIdx m;
     pendOpen := #pendOpen m; pendBol := #pendBol m; pendClose := #pendClose m; stop := #stop m)

  fun start (f, v) =
    (file := f; toks := v;
     idx := 0; ctx := []; current := T.EOF; curIdx := 0;
     pendOpen := false; pendBol := false; pendClose := false; stop := 0;
     case #token (item 0) of
       T.LBRACE => ()
     | T.MODULE => ()
     | T.EOF => ()
     | _ => pendOpen := true;
     fetch ())
end
