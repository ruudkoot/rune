let ()=
 let data=Scanf.Scanning.from_string"(0 0 0)(1 0 0)(0 1 0)(1 1 1)(0 0 0)"in
 let triangle=new Triangle.obj data in
 let show()=print_endline(String.concat " "(List.map string_of_bool triangle#benchmarkDemand))in
 show();ignore triangle#area;show();ignore triangle#normal;show();ignore triangle#tangent;show()
