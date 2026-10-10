#!/bin/sh
# Dynamic modules (docs/units.md, Dynamic modules; the incremental roadmap's
# M9): a module compiled against a signature and loaded by a program
# compiled against the signature alone -- an abstract type, a datatype whose
# constructors the module declares in another order, a polymorphic value and
# an exception across the boundary -- under the interpreter and --jit=all; a
# module of another signature refused; a plugin through Dynamic.load; two
# modules that share a library's types; a whole program refused; a module
# reloaded while the program runs, and one with an abstract type refused.
#   tests/dynamic/run.sh [--rune BIN]
set -u
cd "$(dirname "$0")/../.."
root=$(pwd)
rune=bin/rune
[ "${1:-}" = --rune ] && rune=$2
case $rune in /*) ;; *) rune=$root/$rune ;; esac
vm=$(dirname "$rune")/runevm
out=$root/tests/out/dynamic
rm -rf "$out"
mkdir -p "$out"
cd "$out" || exit 1
pass=0
fail=0
ok() { pass=$((pass + 1)); }
bad() { echo "FAIL dynamic.$1"; fail=$((fail + 1)); }
put() { printf '%s\n' "$2" > "$1"; }
# module NAME FILES...: the last file's unit, NAME.rbu
module() { n=$1; shift; rm -rf "$n.units"
  for last in "$@"; do :; done
  "$rune" --units --no-cache --emit-units "$n.units" "$@" -o "$n.whole.rbc" 2> "$n.err" &&
    cp "$(grep -- "-$(basename "$last" .sml)\.rbu\$" "$n.units/units")" "$n.rbu"; }

put shape.sml 'signature SHAPE =
sig
  type t
  datatype kind = Round | Square of int
  exception Bad of int
  val make : int -> t
  val area : t -> int
  val kindOf : t -> kind
  val name : string
  val twice : '"'"'a -> '"'"'a * '"'"'a
end'
put impl.sml '_export structure Impl : SHAPE =
struct
  datatype kind = Square of int | Round
  type t = int * kind
  exception Bad of int
  fun make n = if n < 0 then raise Bad n else (n, if n > 5 then Round else Square n)
  fun area (n, _) = n * n
  fun kindOf (_, k) = k
  val name = "impl"
  fun twice x = (x, x)
end'
put client.sml 'structure S = _dynamic "impl.rbu" : SHAPE
fun kind k = case k of S.Round => "round" | S.Square n => "square " ^ Int.toString n
val () = print (S.name ^ " " ^ Int.toString (S.area (S.make 3)) ^ " " ^ kind (S.kindOf (S.make 3)) ^ " "
                ^ kind (S.kindOf (S.make 7)) ^ "\n")
val () = print (#1 (S.twice "poly") ^ "\n")
val () = (ignore (S.make ~4); print "no raise\n") handle S.Bad n => print ("Bad " ^ Int.toString n ^ "\n")'
module impl shape.sml impl.sml || bad "the module does not compile ($out/impl.err)"
"$rune" --units --no-cache shape.sml client.sml -o client.rbc 2> client.err || bad "the client does not compile ($out/client.err)"
want='impl 9 square 3 round
poly
Bad ~4'
for jit in "" --jit=all; do
  # shellcheck disable=SC2086
  [ "$("$vm" $jit client.rbc 2>&1)" = "$want" ] && ok || bad "a module through _dynamic $jit: $("$vm" $jit client.rbc 2>&1 | head -2)"
done

# a module of another signature: refused, naming both fingerprints
put other.sml "$(sed 's/val area : t -> int/val area : t -> real/' shape.sml)
_export structure Other : SHAPE =
struct
  datatype kind = Round | Square of int
  type t = int
  exception Bad of int
  fun make n = n
  fun area n = real n
  fun kindOf _ = Round
  val name = \"other\"
  fun twice x = (x, x)
end"
module other other.sml && cp other.rbu impl.rbu
"$vm" client.rbc > mismatch.out 2>&1
grep -q 'Mismatch "impl.rbu implements another signature' mismatch.out && ok || bad "mismatch: $(head -1 mismatch.out)"
module impl shape.sml impl.sml

# a plugin: a unit that registers itself in a structure of the program
put registry.sml 'structure Registry = struct val plugins : (string * (int -> int)) list ref = ref [] end'
put plugin.sml 'val () = Registry.plugins := ("double", fn x => 2 * x) :: !Registry.plugins'
put host.sml 'val () = Dynamic.load "plugin.rbu"
val () = List.app (fn (n, f) => print (n ^ " " ^ Int.toString (f 21) ^ "\n")) (!Registry.plugins)'
module plugin registry.sml plugin.sml
"$rune" --units --no-cache registry.sml host.sml -o host.rbc 2> host.err
[ "$("$vm" host.rbc 2>&1)" = "double 42" ] && ok || bad "plugin: $("$vm" host.rbc 2>&1 | head -1)"

# two modules that share a library's types: what one makes the other takes
put lib.sml 'structure Lib = struct datatype pt = P of int * int end'
put maker.sml 'signature MAKER = sig val make : int -> Lib.pt end'
put measurer.sml 'signature MEASURER = sig val norm : Lib.pt -> int end'
put mk.sml '_export structure Mk : MAKER = struct fun make n = Lib.P (n, n + 1) end'
put ms.sml '_export structure Ms : MEASURER = struct fun norm (Lib.P (a, b)) = a * a + b * b end'
put both.sml 'structure M = _dynamic "mk.rbu" : MAKER
structure N = _dynamic "ms.rbu" : MEASURER
val () = print (Int.toString (N.norm (M.make 3)) ^ "\n")'
module mk lib.sml maker.sml mk.sml
module ms lib.sml measurer.sml ms.sml
"$rune" --units --no-cache lib.sml maker.sml measurer.sml both.sml -o both.rbc 2> both.err
[ "$("$vm" both.rbc 2>&1)" = 25 ] && ok || bad "two modules: $("$vm" both.rbc 2>&1 | head -1) ($out/both.err)"

# a whole program cannot load one
"$rune" shape.sml client.sml -o whole.rbc > whole.err 2>&1 && bad "a whole program: accepted" ||
  { grep -q 'is built in units (rune --units)' whole.err && ok || bad "a whole program: $(head -1 whole.err)"; }

# hot reload (the incremental roadmap's M12): the program loads v1 from
# live.rbu, keeps a function of it, puts v2 in its place and reloads; a call
# through the structure reaches v2, the function kept is v1's, and a
# reload of a module of another signature changes nothing -- under the
# interpreter and --jit=all, in a loop that calls through the structure
put live.sml 'signature LIVE = sig val version : unit -> string val step : int -> int end'
put v1.sml '_export structure V : LIVE = struct fun version () = "v1" fun step n = n + 1 end'
put v2.sml '_export structure V : LIVE = struct fun version () = "v2" fun step n = n * 2 end'
put v3.sml 'signature LIVE = sig val version : unit -> string end
_export structure V : LIVE = struct fun version () = "v3" end'
put reload.sml 'structure L = _dynamic "live.rbu" : LIVE
fun copy (a, b) =
  let val i = BinIO.openIn a val v = BinIO.inputAll i val () = BinIO.closeIn i
      val out = BinIO.openOut b in BinIO.output (out, v); BinIO.closeOut out end
fun loop (0, acc) = acc | loop (n, acc) = loop (n - 1, L.step acc)
val kept = L.version
val () = print (L.version () ^ " " ^ Int.toString (loop (10, 0)) ^ "\n")
val () = copy ("v2.rbu", "live.rbu")
val () = Dynamic.reload "live.rbu"
val () = print (L.version () ^ " " ^ Int.toString (loop (10, 1)) ^ " " ^ kept () ^ "\n")
val () = copy ("v3.rbu", "live.rbu")
val () = (Dynamic.reload "live.rbu"; print "reloaded\n") handle Dynamic.Mismatch _ => print "mismatch\n"
val () = print (L.version () ^ "\n")'
module v1 live.sml v1.sml && module v2 live.sml v2.sml && module v3 v3.sml || bad "the live modules do not compile"
"$rune" --units --no-cache live.sml reload.sml -o reload.rbc 2> reload.err || bad "the reloading program does not compile ($out/reload.err)"
want='v1 10
v2 1024 v1
mismatch
v2'
for jit in "" --jit=all; do
  cp v1.rbu live.rbu
  # shellcheck disable=SC2086
  got=$("$vm" $jit reload.rbc 2>&1)
  [ "$got" = "$want" ] && ok || bad "a module reloaded $jit: [$got]"
done

# a module whose signature has an abstract type is not reloaded: a value of
# it that the program holds could be of another representation in the new
# module
put noreload.sml 'structure S = _dynamic "impl.rbu" : SHAPE
val kept = S.make 3
val () = (Dynamic.reload "impl.rbu"; print "reloaded\n")
         handle Dynamic.Mismatch m => print (if String.isSubstring "abstract type" m then "refused\n" else m ^ "\n")
val () = print (Int.toString (S.area kept) ^ "\n")'
"$rune" --units --no-cache shape.sml noreload.sml -o noreload.rbc 2> noreload.err || bad "the program does not compile ($out/noreload.err)"
got=$("$vm" noreload.rbc 2>&1)
[ "$got" = 'refused
9' ] && ok || bad "a module of an abstract type reloaded: [$got]"

echo "dynamic: passed $pass, failed $fail"
[ $fail = 0 ]
