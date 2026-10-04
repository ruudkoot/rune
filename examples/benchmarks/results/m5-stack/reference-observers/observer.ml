let create_stack size =
  let stack = Stack.create () in
  for i = 1 to size do Stack.push i stack done;
  stack
let fold iterations =
  let stack = create_stack 100 in
  let total = ref 0 in
  for _ = 1 to iterations do
    total := !total + Sys.opaque_identity (Stack.fold ( + ) 0 stack)
  done;
  Printf.printf "%d:%d:%d\n" !total (Stack.length stack) (Stack.top stack)
let push_pop iterations =
  let stack = Stack.create () in
  Stack.push () stack;
  let completed = ref 0 in
  for _ = 1 to iterations do
    Stack.push () stack; Stack.pop stack; incr completed
  done;
  Printf.printf "%d:%d\n" !completed (Stack.length stack)
let () = fold 100; fold 2500000; push_pop 100; push_pop 100000000
