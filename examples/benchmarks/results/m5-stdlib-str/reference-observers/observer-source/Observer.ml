module B=Observed
let seed=Int32.of_string"0x811C9DC5"
let mix h v=Int32.mul(Int32.logxor h v)16777619l
let digest text=String.fold_left(fun h c->mix h(Int32.of_int(Char.code c)))seed text
let parts words=List.fold_left(fun h text->mix(String.fold_left(fun h c->mix h(Int32.of_int(Char.code c)))h text)0l)seed words
let run name n=
 let state=ref seed and seen=ref 0 in
 B.compiled:=0;
 B.hook:=(fun obj->
  let value=match name with
  |"str_regexp"->let re=Obj.obj obj in assert(Str.string_match re B.test_regex 0);assert(not(Str.string_match re "Wrong" 0));digest B.test_regex
  |"str_string_match"|"str_string_partial_match"->if Obj.obj obj then 1l else 0l
  |"str_search_forward"->Int32.of_int(Obj.obj obj)
  |"str_global_replace"->digest(Obj.obj obj)
  |"str_split"->parts(Obj.obj obj)
  |_ ->failwith"selector"in state:=mix !state value;incr seen);
 (match name with
 |"str_regexp"->B.str_regexp n
 |"str_string_match"->B.str_string_match n
 |"str_search_forward"->B.str_search_forward n
 |"str_string_partial_match"->B.str_string_partial_match n
 |"str_global_replace"->B.str_global_replace n
 |"str_split"->B.str_split n
 |_ ->failwith"selector");
 assert(!seen=n);assert(!(B.compiled)=(if name="str_regexp"then n else 1));
 Printf.printf "%s %d:%lX\n" name n !state
let ()=List.iter(fun(name,n)->run name n)[("str_regexp",0);("str_regexp",1);("str_regexp",5);("str_string_match",0);("str_string_match",1);("str_string_match",5);("str_search_forward",0);("str_search_forward",1);("str_search_forward",5);("str_string_partial_match",0);("str_string_partial_match",1);("str_string_partial_match",5);("str_global_replace",0);("str_global_replace",1);("str_global_replace",5);("str_split",0);("str_split",1);("str_split",5);("str_regexp",1);("str_regexp",20000);("str_string_match",1);("str_string_match",200000);("str_search_forward",1);("str_search_forward",2000);("str_search_forward",100000);("str_string_partial_match",1);("str_string_partial_match",200000);("str_global_replace",1);("str_global_replace",2000);("str_global_replace",100000);("str_split",1);("str_split",2000)]
