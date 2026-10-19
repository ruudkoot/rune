(* nofib's exhaustive backwards bridge search; preserve history pruning/order. *)
functor BenchPuzzleFn(D : BENCH_SUSPEND) =
struct
  structure Q = BenchCellSequenceFn(D)
  datatype item = Bono | Edge | Larry | Adam
  datatype bank = LeftBank | RightBank
  datatype state = State of bank * bank * bank * bank
  fun value x = D.delay(fn () => x)
  val initial = State(LeftBank,LeftBank,LeftBank,LeftBank)
  val final = State(RightBank,RightBank,RightBank,RightBank)
  fun position Bono (State(a,_,_,_)) = a
    | position Edge (State(_,b,_,_)) = b
    | position Larry (State(_,_,c,_)) = c
    | position Adam (State(_,_,_,d)) = d
  fun update (State(a,b,c,d)) item bank = case item of
      Bono => State(bank,b,c,d) | Edge => State(a,bank,c,d)
    | Larry => State(a,b,bank,d) | Adam => State(a,b,c,bank)
  fun opposite LeftBank = RightBank | opposite RightBank = LeftBank
  fun next Bono = Edge | next Edge = Larry | next Larry = Adam
    | next Adam = raise Fail "puzzle successor outside enumeration"
  fun range first last = D.delay(fn () => Q.Cons(value first,
    if first=last then Q.empty() else range(next first)last))
  fun crossing Bono = 10 | crossing Edge = 5 | crossing Larry = 2 | crossing Adam = 1
  fun notSeen state history = case D.force history of Q.Nil => true
    | Q.Cons(step,rest) => let val (_,old) = D.force step
        in state<>old andalso notSeen state rest end
  fun concatMap f xs = D.delay(fn () => case D.force xs of Q.Nil => Q.Nil
    | Q.Cons(x,rest) => D.force(Q.append(f x)(concatMap f rest)))
  fun transfer source dest location countdown history = D.delay(fn () =>
    if source=dest then Q.Cons(value(Q.cons(value(countdown,dest))history),Q.empty())
    else let
      val newHistory = Q.cons(value(countdown,dest))history
      val newLocation = opposite location
      fun one itemCell = D.delay(fn () =>
        let val item = D.force itemCell
        in if position item dest<>location then Q.Nil
           else let val newDest = update dest item newLocation
             in if notSeen newDest history then
               D.force(transfer source newDest newLocation
                 (D.delay(fn () => D.force countdown+crossing item))newHistory)
               else Q.Nil end end)
      fun two firstCell = D.delay(fn () =>
        let val i = D.force firstCell
            fun partner secondCell = D.delay(fn () =>
              let val j = D.force secondCell
              in if position i dest=location andalso position j dest=location
                 then let val newDest = update(update dest i newLocation)j newLocation
                   in if notSeen newDest history then
                     D.force(transfer source newDest newLocation
                       (D.delay(fn () => D.force countdown+crossing i))newHistory)
                     else Q.Nil end
                 else Q.Nil end)
        in D.force(concatMap partner (range(next i)Adam)) end)
      val moveOne = concatMap one (range Bono Adam)
      val moveTwo = concatMap two (range Bono Larry)
    in D.force(Q.append moveOne moveTwo) end)
  fun totalTime history = case D.force history of Q.Nil => raise Fail "empty puzzle history"
    | Q.Cons(step,_) => let val (time,_) = D.force step in D.force time end
  fun reverse xs =
    let fun loop xs acc = case D.force xs of Q.Nil => acc
          | Q.Cons(x,rest) => loop rest (Q.cons x acc)
    in loop xs (Q.empty()) end
  fun minimum solutions = D.delay(fn () => case D.force solutions of Q.Nil => Q.Nil
    | Q.Cons(history,rest) =>
      let fun loop best mins xs = case D.force xs of Q.Nil => reverse mins
            | Q.Cons(h,hs) => let val total = totalTime(D.force h)
                in case Int.compare(best,total) of
                    LESS => loop best mins hs
                  | EQUAL => loop best (Q.cons h mins)hs
                  | GREATER => loop total (Q.cons h (Q.empty()))hs end
      in D.force(loop(totalTime(D.force history))(Q.cons history(Q.empty()))rest) end)
  fun chars text = Q.fromList(String.explode text)
  val line0 = chars "    Bono |                    |\n"
  val line1 = chars "The Edge |                    |\n"
  val line2 = chars "   Larry |                    |\n"
  val line3 = chars "    Adam |                    |\n"
  val line4 = chars "         |                    | Bono\n"
  val line5 = chars "         |                    | The Edge\n"
  val line6 = chars "         |                    | Larry\n"
  val line7 = chars "         |                    | Adam\n"
  fun itemText item bank = case (item,bank) of
      (Bono,LeftBank) => line0
    | (Edge,LeftBank) => line1
    | (Larry,LeftBank) => line2
    | (Adam,LeftBank) => line3
    | (Bono,RightBank) => line4
    | (Edge,RightBank) => line5
    | (Larry,RightBank) => line6
    | (Adam,RightBank) => line7
  val border = chars "----------------------------------------\n"
  fun showState state = Q.append border
    (Q.append(itemText Bono(position Bono state))
      (Q.append(itemText Edge(position Edge state))
        (Q.append(itemText Larry(position Larry state))
          (Q.append(itemText Adam(position Adam state))border))))
  fun showHistory history = D.delay(fn () =>
    let val total = totalTime history
        fun steps xs = D.delay(fn () => case D.force xs of Q.Nil => Q.Nil
          | Q.Cons(step,rest) => let val (time,state) = D.force step
              in D.force(Q.append(chars("Time: "^Int.toString(total-D.force time)^"\n"))
                (Q.append(showState state)(steps rest))) end)
    in D.force(steps history) end)
  fun showSolutions solutions count = D.delay(fn () => case D.force solutions of Q.Nil => Q.Nil
    | Q.Cons(history,rest) => D.force(Q.append(chars("Solution "^Int.toString count^"\n"))
      (Q.append(showHistory(D.force history))(showSolutions rest(count+1)))))
  fun all () = transfer initial final RightBank (value 0)(Q.empty())
  fun result () = showSolutions(minimum(all()))1
  fun text xs = String.implode(Q.toList xs)
  fun checked expected =
    let val length = String.size expected
        fun loop xs i = case D.force xs of
            Q.Nil => if i=length then i else raise Fail "short puzzle result"
          | Q.Cons(c,rest) => if i<length andalso D.force c=String.sub(expected,i)
              then loop rest(i+1) else raise Fail "puzzle result differs"
    in loop(result())0 end
end
