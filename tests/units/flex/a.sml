(* a flexible record that only a later file determines: a file ends a
   top-level declaration, which under the default --flex-records=topdec
   must determine it, so the program is refused whole as in units
   (--flex-records=program resolved it across files: tests/flexrec) *)
fun getX r = #x r
