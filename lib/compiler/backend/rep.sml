(* The representation of the values of a datatype (docs/ir.md, Low;
   docs/plans/middle-end.md, M11): how a constructor with an argument is
   made. One whose declared argument is a tuple of two or more -- a record
   too -- is one object of those fields, its tag in the object's header
   (Low's Con of the fields, and Field; CONN and FIELD); any other boxes its
   argument, a constructor object of one field (Con of one, and Decon; CON
   and DECON). The choice is the datatype's, whatever types it is used at,
   so that every use of a constructor agrees; a list's :: is of two fields,
   which is what the C of the VM makes and walks (vm_cons, list_head,
   list_tail). Under --functors=functions an instance of a datatype a
   functor's body declares keeps the layout the body gave it (Ty.layoutOf,
   pinned). *)
structure Rep =
struct
  (* the number of fields of each constructor of a datatype, by its stamp:
     NONE for one that boxes its argument or has none *)
  val known : (int * int option) list IntTable.table = IntTable.table 64
  val () = CompilerState.tableRoot ("Rep.known", known)

  fun ofDatatype (stamp : int) : (int * int option) list =
    case IntTable.find (known, stamp) of
      SOME cs => cs
    | NONE =>
        let val cs = Ty.layoutOf stamp
        in IntTable.insert (known, stamp, cs); cs end

  (* SOME n where the constructor with the tag of the datatype t is made of
     the n fields of its argument; NONE where it boxes it. *)
  fun fields (t : Ty.ty, tag : int) : int option =
    case Ty.view t of
      Ty.Con (stamp, _, _) =>
        (case List.find (fn (tag', _) => tag' = tag) (ofDatatype stamp) of
           SOME (_, n) => n
         | NONE => NONE)
    | _ => NONE
end
