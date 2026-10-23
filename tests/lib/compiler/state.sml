structure CompilerStateTests =
struct
  structure S = CompilerState
  val counter = ref 0
  val () = S.cellRoot ("Test.counter", counter)
  val arrayRef = ref (Array.array (2, 0))
  val () = S.refRoot ("Test.arrayRef", arrayRef, S.copyArray)
  val array = Array.array (2, 0)
  val () = S.arrayRoot ("Test.array", array)
  val table = IntTable.table 16 : int IntTable.table
  val () = S.tableRoot ("Test.table", table)
  val tables = Vector.tabulate (2, fn _ => IntTable.table 16) : int IntTable.table vector
  val () = S.tableVectorRoot ("Test.tables", tables)
  exception CopyFailed
  val failCopy = ref false
  val copyProbe = ref 0
  val () = S.refRoot ("Test.copyProbe",copyProbe,fn x => if !failCopy then raise CopyFailed else x)
  fun need (ok, message) = Expect.that (message,ok)
  fun fresh () = !counter = 17 andalso Array.sub (!arrayRef,0) = 0 andalso
    Array.sub (array,0) = 0 andalso IntTable.find (table,1) = NONE andalso
    IntTable.find (Vector.sub (tables,0),1) = NONE
  fun set n = (counter := n; Array.update (!arrayRef,0,n); Array.update (array,0,n);
    IntTable.insert (table,1,n); IntTable.insert (Vector.sub (tables,0),1,n))
  fun is n = !counter = n andalso Array.sub (!arrayRef,0) = n andalso
    Array.sub (array,0) = n andalso IntTable.find (table,1) = SOME n andalso
    IntTable.find (Vector.sub (tables,0),1) = SOME n
  exception Probe
  fun main () =
    let
      val () = counter := 17
      val () = S.seal ()
      val a = S.session ()
      val b = S.session ()
      val () = S.withSession (a, fn () => (need (fresh (), "late baseline"); set 23))
      val () = need (fresh (), "host restore")
      val () = S.withSession (b, fn () => (need (fresh (), "B shares mutable baseline"); set 42))
      val () = S.withSession (a, fn () =>
        let val alias = !arrayRef
        in (need (is 23, "A contaminated");
         S.withSession (a, fn () => (counter := 24; need (!counter = 24, "same-session nesting")));
         counter := 23;
         S.withSession (b, fn () =>
           (need (is 42, "nested B contaminated");
            need (((S.close a; false) handle S.Active => true), "closed a paused caller");
            S.withSession (a, fn () => (need (is 23, "reentered A lost current state"); set 24));
            need (is 42, "reentered A contaminated B"); set 43));
         need (is 24, "reentered A update lost on B return");
         need (alias = !arrayRef, "switching owners changed a live array alias");
         IntTable.update (table,1,fn _ =>
           (S.withSession (b,fn () => need (is 43,"table callback sees wrong owner")); 24));
         need (IntTable.find (table,1) = SOME 24, "table callback lost its live binding cell")) end)
      val () = ((S.withSession (a, fn () => (set 25; raise Probe)); raise Fail "exception lost") handle Probe => ())
      val () = need (fresh (), "host restore on exception")
      val () = S.withSession (a, fn () => need (is 25, "exception state not retained"))
      val () = S.withSession (b, fn () => need (is 43, "B lost update"))
      val c = S.session ()
      val () = S.withSession (c, fn () => need (fresh (), "baseline mutated"))
      val () = S.withSession (c, fn () => need (((S.close c; false) handle S.Active => true), "closed active session"))
      val () = S.close a
      val () = need (((S.withSession (a, fn () => ()); false) handle S.Closed => true), "used closed session")
      val () = need (((S.cellRoot ("late", ref 1); false) handle Fail _ => true), "late registration")
      val () = counter := 61
      val () = failCopy := true
      val () = need (((ignore (S.session ()); false) handle CopyFailed => true), "copy exception lost")
      val () = failCopy := false
      val () = need (!counter = 61, "failed owner creation changed caller roots")
      val () = counter := 17
    in () end
end
structure CompilerStateTestMain = Main (struct
  val name = "compiler-state"
  val tests = Test.describe "compiler-state" [Test.it "ownership" CompilerStateTests.main]
end)
val () = CompilerStateTestMain.main ()
