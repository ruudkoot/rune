structure Benchmark =
struct
  structure L = BenchLazy
  val name = "hamming"
  type number = IntInf.int * IntInf.int
  datatype node = Cons of number * node L.delay
  val digit : IntInf.int = 1000000000000000000
  val modulus : IntInf.int = 18446744073709551616
  val sign : IntInf.int = 9223372036854775808
  fun signed n = let val bits = IntInf.mod(n,modulus)
    in if bits >= sign then IntInf.-(bits,modulus) else bits end
  fun multiply (n : IntInf.int) (low,high) =
    let val product = signed(IntInf.*(n,low))
    in (IntInf.rem(product,digit),
        signed(IntInf.+(signed(IntInf.*(n,high)),IntInf.quot(product,digit)))) end
  fun compare ((low,high),(otherLow,otherHigh)) =
    case IntInf.compare(high,otherHigh) of EQUAL => IntInf.compare(low,otherLow) | order => order
  fun map f stream = L.delay(fn () =>
    let val Cons(head,tail) = L.force stream
    in Cons(f head,map f tail) end)
  fun merge a b = L.delay(fn () =>
    let val Cons(x,xs) = L.force a
        val Cons(y,ys) = L.force b
    in case compare(x,y) of
         EQUAL => Cons(x,merge xs ys)
       | LESS => Cons(x,merge xs b)
       | GREATER => Cons(y,merge a ys)
    end)
  fun stream () =
    let val root = ref NONE
        fun get () = valOf(!root)
        val twice = L.delay(fn () => L.force(map(multiply 2)(get())))
        val thrice = L.delay(fn () => L.force(map(multiply 3)(get())))
        val fifth = L.delay(fn () => L.force(map(multiply 5)(get())))
        val hamming = L.delay(fn () => Cons((1,0),merge twice (merge thrice fifth)))
        val _ = root := SOME hamming
    in hamming end
  fun decimal value = if value < 0 then "-" ^ IntInf.toString(IntInf.~ value) else IntInf.toString value
  fun render (low,high) = if high=0 then decimal low else
    let val raw = decimal low
        val pad = String.implode(List.tabulate(Int.max(0,18-String.size raw),fn _ => #"0"))
        val tail = if low<0 then "-" ^ pad ^ decimal(IntInf.~ low) else pad ^ raw
    in decimal high ^ tail end
  fun interval initial skip count =
    let fun loop stream start left reversed = if left=0 then List.rev reversed else
          let val Cons(value,tail) = L.force stream
          in loop tail (start-1) (left-1)
               (if start<=0 then render value::reversed else reversed) end
    in loop initial skip (skip+count) [] end
  fun file path = let val input = TextIO.openIn path
      val result = TextIO.inputAll input
      val _ = TextIO.closeIn input
    in result end
  fun run [start,size,path] =
    let val skip = BenchInput.between(0,88000)(BenchInput.integer start)
        val count = BenchInput.between(1,10000)(BenchInput.integer size)
        val expected = file path
        val values = interval(stream()) skip count
        val actual = String.concat(List.map(fn text => text ^ "\n")values)
        val _ = if actual=expected then () else raise Fail "Hamming output differs"
    in List.last values end
    | run _ = raise Fail "hamming expects skip count reference"
end
