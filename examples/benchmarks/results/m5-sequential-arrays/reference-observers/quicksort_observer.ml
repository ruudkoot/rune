let n = try int_of_string Sys.argv.(1) with _ -> 2000

let swap arr i j =
	let temp = arr.(i) in
	arr.(i) <- arr.(j);
	arr.(j) <- temp

let partition arr low high =
	let x = arr.(high) and  i = ref (low-1) in
	if (high-low > 0) then
	begin
		for j= low to high - 1 do
			if arr.(j) <= x then
			begin
				i := !i+1;
				swap arr !i j
			end
		done
    end;
    swap arr (!i+1) high;
    !i+1

let rec quicksort_o arr low high =
	match (high - low) <= 0 with
	| true  -> ()
	| false ->
		let q = partition arr low high in
		quicksort_o arr low (q-1);
		quicksort_o arr (q+1) high

let quicksort arr low high =
	match (high - low) <= 0 with
	| true  -> ()
	| false   ->
    let q = partition arr low high in
    quicksort_o arr low (q-1);
    quicksort_o arr (q+1) high


let report a =
 let sum=ref 0L and hash=ref 0l in
 Array.iter (fun x -> sum:=Int64.add !sum(Int64.of_int x);hash:=Int32.add(Int32.mul !hash 131l)(Int32.of_int x)) a;
 Printf.printf "%d:%Ld:%lx\n" (Array.length a) !sum !hash

let () = let a=Array.init n (fun _ -> Random.int n) in
 if Array.length Sys.argv>2 then (let out=open_out Sys.argv.(2) in Array.iter(fun v -> Printf.fprintf out "%d\n" v)a;close_out out);
 quicksort a 0 (n-1);report a
