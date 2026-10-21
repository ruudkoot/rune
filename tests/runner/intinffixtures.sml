(* Public corpus query for tools being migrated after the correctness suite.
   Finite accepted shapes retain their original independent Python answers. *)
structure IntInfFixtures =
struct
  open IntInfChecks
  fun workload spec =
    let val keys=["op","bits","other_bits","iterations"]
        fun matches row=List.all (fn key => field key row=field key spec) keys
        val root=fromRoot "tests/intinf/fixtures"
        val fixed=array (field "workloads" (Json.decode (read (root ^ "/manifest.json"))))
        val exploration=array (field "cases" (fixture "dispatch"))
        fun fixedSource row=let val name=string (field "name" row)
                            in (read (root ^ "/" ^ name ^ ".sml"),read (root ^ "/" ^ name ^ ".expected")) end
        val result=case List.find matches fixed of SOME row => fixedSource row | NONE =>
             (case List.find matches exploration of SOME row => (string (field "source" row),string (field "expected" row))
              | NONE => raise Failed "workload shape or iteration count has no preserved independent oracle")
    in say (Json.encode (Json.Array [Json.String (#1 result),Json.String (#2 result)]) ^ "\n") end
end
