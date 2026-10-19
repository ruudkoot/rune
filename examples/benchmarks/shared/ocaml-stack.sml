(* Portable translation of selected OCaml Stack operations.
   Xavier Leroy, projet Cristal, INRIA Rocquencourt.
   Copyright 1996 Institut National de Recherche en Informatique et
   en Automatique. All rights reserved. Distributed under the GNU Lesser
   General Public License version 2.1 with the OCaml linking exception.
   Original source and complete notice: stack_fold/upstream/ocaml/ and
   stack_push_pop/upstream/ocaml/. *)
structure BenchOcamlStack =
struct
  exception Empty
  datatype 'a stack = Stack of {contents : 'a list ref, length : int ref}
  fun create () = Stack{contents=ref [],length=ref 0}
  fun push value (Stack{contents,length}) =
    (contents := value :: !contents;length := !length+1)
  fun pop (Stack{contents,length}) =
    case !contents of [] => raise Empty
    | first::rest => (contents := rest;length := !length-1;first)
  fun top (Stack{contents,...}) = case !contents of [] => raise Empty | first::_ => first
  fun length (Stack{length,...}) = !length
  fun fold f initial (Stack{contents,...}) = List.foldl(fn (x,acc) => f(acc,x))initial(!contents)
  fun integers size =
    let val stack = create()
        fun loop i = if i>size then stack else (push i stack;loop(i+1))
    in loop 1 end
  fun foldRun iterations =
    let val stack = integers 100
        fun loop 0 total = total
          | loop left total =
              let val actual = fold op + 0 stack
                  val _ = if actual=5050 andalso length stack=100 then () else raise Fail "stack fold differs"
              in loop(left-1)(IntInf.+(total,IntInf.fromInt actual))end
    in loop iterations 0 end
  fun pushPopRun iterations =
    let val stack = create()
        val _ = push () stack
        fun loop 0 completed = completed
          | loop left completed =
              let val _ = push () stack
                  val _ = pop stack
                  val _ = if length stack=1 then () else raise Fail "stack push/pop length differs"
              in loop(left-1)(IntInf.+(completed,1))end
    in loop iterations 0 end
end
