let dates=["1980-01-01";"1980-02-29";"2000-02-29";"2012-01-01";"2012-01-31";"2100-02-28";"2299-12-31"]
let ()=List.iter(fun text->
 let date=Date_source.of_string text in
 Printf.printf "date %s %d\n"text date;
 List.iter(fun months->let changed=Date_source.add_months date months in let g=Date_source.gregorian_of_date changed in
 Printf.printf "month %s %d %d %d %d %d\n"text months changed g.Date_source.year g.Date_source.month g.Date_source.day)[-13;-1;0;1;13])dates
let ()=List.iter(fun x->Printf.printf "cdf %.17g %.17g\n"x(Math.ugaussian_P x))[-8.;-3.;-1.;0.;1.;3.;8.]
let ()=let calls=ref[]in let root=Math.Rootfinder.brent 0. 2.(fun x->calls:=x:: !calls;x*.x-.2.)1e-10 in
 Printf.printf "root %.17g\n"root;
 print_endline("order "^String.concat ","(List.map(Printf.sprintf "%.17g")(List.rev !calls)))
let ()=let calls=ref[]in let left()=calls:="left":: !calls;1. in let right()=calls:="right":: !calls;2. in
 ignore(left(),right()); print_endline("tuple "^String.concat ","(List.rev !calls));
 calls:=[];ignore(left()-.right());print_endline("subtract "^String.concat ","(List.rev !calls))
