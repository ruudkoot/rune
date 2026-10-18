%tokentype {T}
%token x {X}
%%
a : x {("\x41",'\x42',\$1,$1,$>)}