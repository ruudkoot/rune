open GraphTypes
let () =
 let edges=GenerateSeq.from_file Sys.argv.(1) in
 let graph=Kernel1Seq.kernel1 edges in
 let count=ref 0 and hash=ref 0L in
 let add n=hash:=Int64.add(Int64.mul !hash 31L)(Int64.of_int n) in
 for vertex=0 to SparseGraphSeq.max_vertex_label graph do
  let row=SparseGraphSeq.from vertex graph in
  add vertex;add(List.length row);
  List.iter(fun(target,weight)->add target;add(int_of_float(weight*.100000000.));incr count)row
 done;
 Printf.printf "%d %d %d %Lx\n" (Array.length edges) (SparseGraphSeq.max_vertex_label graph+1) !count !hash
