(* Source ANSI interaction combinators, with memoized or eager output spines. *)
functor BenchAnsiFn(D : BENCH_SUSPEND) =
struct
  structure Q = BenchCellSequenceFn(D)
  type text = char Q.sequence
  type interact = text -> text
  fun value x = D.delay(fn()=>x)
  fun prepend [] finish = finish
    | prepend(c::cs)finish = D.delay(fn()=>Q.Cons(value c,prepend cs finish))
  fun writeString chars program input = prepend chars(D.delay(fn()=>D.force(program input)))
  fun writeChar c = writeString[c]
  fun readChar eof use input = D.delay(fn()=>case D.force input of Q.Nil=>D.force(eof input)
    | Q.Cons(c,rest)=>D.force(use(D.force c)rest))
  fun finish _ = Q.empty()
  fun pressAnyKey program = readChar program(fn _=>program)
  fun unreadChar c program input = program(D.delay(fn()=>Q.Cons(value c,input)))
  fun goto x y = "\027["^Int.toString y^";"^Int.toString x^"H"
  fun writeAt(x,y) text = writeString(String.explode(goto x y^text))
  fun moveTo(x,y) = writeString(String.explode(goto x y))
  fun readAt(x,y) limit use =
    let fun loop n reverse = readChar(fn input=>use(List.rev reverse)input)(fn c =>
          if c= #"\008" orelse c= #"\127" then delete n reverse
          else if c= #"\n" then use(List.rev reverse)
          else if n<limit then writeChar c(loop(n+1)(c::reverse))
          else writeChar #"\007" (loop n reverse))
        and delete n reverse = if n>0 then
          writeString[ #"\008", #"_", #"\008"](loop(n-1)(tl reverse))
          else writeChar #"\007"(loop 0 [])
    in writeAt(x,y)(String.implode(List.tabulate(limit,fn _=> #"_")))(moveTo(x,y)(loop 0 []))end
  fun promptReadAt(x,y) limit prompt use =
    writeAt(x,y)prompt(readAt(x+String.size prompt,y)limit use)
  fun at(x,y)s = goto x y^s
  fun highlight s = "\027[7m"^s^"\027[0m"
  val opening = String.explode(String.concat[
    "\012",at(17,5)(highlight "Demonstration program"),at(48,5)"Version 1.0",
    at(17,7)"This program illustrates a simple approach",
    at(17,8)"to screen-based interactive programs using",
    at(17,9)"the Hugs functional programming system.",
    at(17,11)"Please press any key to continue ..."])
  val program : interact = writeString opening(pressAnyKey
    (promptReadAt(17,15)18 "Please enter your name: "(fn name=>
      let val reply="Hello "^String.implode name^"!"
      in writeAt(40-String.size reply div 2,18)reply(moveTo(1,23)
        (writeString(String.explode "I'm waiting...\n")(pressAnyKey finish)))end)))
  fun run count input = if count=0 then input else
    program(D.delay(fn()=>D.force(run(count-1)input)))
end
