(* used by tests/repl/unicode.in: names in CJK and Greek, which the
   debugger shows, and a raise after them on its line, whose column :bt
   gives in characters *)
fun 面積 (半径 : int) =
  let val π = 3
  in π * 半径 * 半径 end
fun 割る (分子 : int, 分母 : int) = if 分母 = 0 then raise Div else 分子 div 分母
