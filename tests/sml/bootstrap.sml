val _ = RuneCompiler.compile "let val x = 2 + 3 in x * 4 end";
val _ = RuneCompiler.compile "if 2 < 3 then true else false";

fun expectsTypeError source =
  let
    val failed = (RuneCompiler.compile source; false)
                 handle Fail _ => true
  in
    if failed then () else raise Fail "expected type error"
  end;

val _ = expectsTypeError "if 1 then 2 else 3";
val _ = expectsTypeError "true + 1";
