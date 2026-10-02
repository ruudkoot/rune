structure Benchmark=struct val name="hanoi"
fun run [size]=let val n=BenchInput.between(1,20)(BenchInput.integer size)
val towers=Array.tabulate(3,fn i=>if i=0 then List.tabulate(n,fn j=>j+1)else[])
val moves=ref 0
fun observe(i,j)=case Array.sub(towers,i-1)of []=>raise Fail "empty Hanoi source" |disk::rest=>
let val target=Array.sub(towers,j-1) val _=case target of []=>()|head::_=>if disk<head then()else raise Fail "illegal Hanoi move"
in Array.update(towers,i-1,rest);Array.update(towers,j-1,disk::target);moves:= !moves+1 end
fun out_str s=BenchOutput.put s
fun printNum i=BenchOutput.put(Int.toString i)
val _=BenchOutput.reset()
  fun neq (x,y) = if x<y then false else if x>y then false else true

  fun show_move (i,j) =
    (out_str "move ";
     printNum i;
     out_str "to ";
     printNum j;
     out_str "\n "; observe(i,j))

  fun hanoi (n, from, to, via)=
    if neq(n,0) then ()
    else (hanoi(n-1, from, via, to);
          show_move(from,to);
          hanoi(n-1, via, to, from))

val _=out_str "Hello\n"
val _=hanoi(n,1,2,3)
val _=out_str "Hello again\n"
val _=if Array.sub(towers,1)=List.tabulate(n,fn i=>i+1) andalso List.null(Array.sub(towers,0)) andalso List.null(Array.sub(towers,2))then()else raise Fail "Hanoi final state"
in Int.toString(!moves)^" "^BenchOutput.summary()end |run _=raise Fail "hanoi expects disks"end
