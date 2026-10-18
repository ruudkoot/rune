module B=Bytes_observed
module S=String_observed
let seed=Int32.of_string"0x811C9DC5"
let mix h v=Int32.mul(Int32.logxor h v)16777619l
let hash_string input=String.fold_left(fun h c->mix h(Int32.of_int(Char.code c)))seed input
let hash_bytes input=Bytes.fold_left(fun h c->mix h(Int32.of_int(Char.code c)))seed input
let hash_parts words=List.fold_left(fun h word->
  mix(String.fold_left(fun h c->mix h(Int32.of_int(Char.code c)))h word)0l)seed words
let run name n=
 let state=ref seed and observed=ref 0 and copied=ref None in
 let record value=state:=mix !state value;incr observed in
 let consume obj=
  let value=if name="bytes_set"then 0l
    else if name="bytes_get"||name="string_get"then Int32.of_int(Char.code(Obj.obj obj))
    else if name="bytes_index"||name="string_index"||name="string_compare"||name="string_equal"then Int32.of_int(Obj.obj obj)
    else if name="bytes_contains"||name="string_contains"then if Obj.obj obj then 1l else 0l
    else if name="string_split_on_char"then hash_parts(Obj.obj obj)
    else if String.starts_with ~prefix:"bytes_" name then hash_bytes(Obj.obj obj)
    else hash_string(Obj.obj obj)
  in record value in
 B.hook:=consume;S.hook:=consume;
 B.copy_hook:=(fun bytes->copied:=Some bytes);
 B.blit_hook:=(fun bytes->record(hash_bytes bytes));S.blit_hook:=(fun bytes->record(hash_bytes bytes));
 B.iter_hook:=(fun count->record(Int32.of_int count));S.iter_hook:=(fun count->record(Int32.of_int count));
 (match name with
 |"bytes_get"->B.bytes_get n
 |"bytes_set"->B.bytes_set n
 |"bytes_cat"->B.bytes_cat n
 |"bytes_sub"->B.bytes_sub n
 |"bytes_blit"->B.bytes_blit n
 |"bytes_concat"->B.bytes_concat n
 |"bytes_iter"->B.bytes_iter n
 |"bytes_map"->B.bytes_map n
 |"bytes_trim"->B.bytes_trim n
 |"bytes_index"->B.bytes_index n
 |"bytes_contains"->B.bytes_contains n
 |"bytes_uppercase_ascii"->B.bytes_uppercase_ascii n
 |"string_get"->S.string_get n
 |"string_sub"->S.string_sub n
 |"string_blit"->S.string_blit n
 |"string_concat"->S.string_concat n
 |"string_iter"->S.string_iter n
 |"string_map"->S.string_map n
 |"string_trim"->S.string_trim n
 |"string_index"->S.string_index n
 |"string_contains"->S.string_contains n
 |"string_uppercase_ascii"->S.string_uppercase_ascii n
 |"string_split_on_char"->S.string_split_on_char n
 |"string_compare"->S.string_compare n
 |"string_equal"->S.string_equal n
 |_ -> failwith"selector");
 assert(!observed=n);
 if name="bytes_set"then(match !copied with None->failwith"copy not observed"|Some bytes->state:=mix !state(hash_bytes bytes));
 Printf.printf "%s %d:%lX\n" name n !state
let ()=List.iter(fun(name,n)->run name n)[("bytes_get",575);("bytes_get",200000);("bytes_set",575);("bytes_set",200000);("bytes_set",1000000);("bytes_cat",1);("bytes_cat",2000);("bytes_sub",575);("bytes_sub",20000);("bytes_blit",575);("bytes_blit",20000);("bytes_concat",1);("bytes_concat",20000);("bytes_iter",1);("bytes_iter",2000);("bytes_map",1);("bytes_map",2000);("bytes_map",100000);("bytes_trim",1);("bytes_trim",20000);("bytes_index",1);("bytes_index",200000);("bytes_contains",1);("bytes_contains",200000);("bytes_uppercase_ascii",1);("bytes_uppercase_ascii",2000);("string_get",575);("string_get",200000);("string_sub",575);("string_sub",20000);("string_blit",575);("string_blit",20000);("string_concat",1);("string_concat",20000);("string_iter",1);("string_iter",2000);("string_map",1);("string_map",2000);("string_map",100000);("string_trim",1);("string_trim",20000);("string_index",1);("string_index",200000);("string_contains",1);("string_contains",200000);("string_uppercase_ascii",1);("string_uppercase_ascii",2000);("string_split_on_char",1);("string_split_on_char",2000);("string_split_on_char",50000);("string_compare",1);("string_compare",100);("string_compare",10000);("string_equal",1);("string_equal",100)]
