module H=Reference
let show action=
 let table=H.create ~random:false 1 in for i=0 to 31 do H.add table i i done;
 let first=ref true and visits=ref [] in
 let callback key value=
  visits:=(key,value):: !visits;
  if !first then(begin first:=false;for i=32 to 95 do H.add table i i done end)in
 (if action="iter"then H.iter callback table
  else ignore(H.fold(fun key value n->callback key value;n+1)table 0));
 Printf.printf "%s %d %d %s\n"action(H.length table)(Array.length table.H.data)
 (String.concat ","(List.map(fun(k,v)->string_of_int k^":"^string_of_int v)(List.rev !visits)))
let ()=show "iter";show "fold"
