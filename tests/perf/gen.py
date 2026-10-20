#!/usr/bin/env python3
"""Programs that scale one construct of the module language, for the
compile-time budgets of tests/perf (docs/plans/performance.md, M1; its E19
measured them on six compilers):

    tests/perf/gen.py KIND PARAMS... > file.sml

A budget names one by its line `generate KIND PARAMS...` and compiles it as
@gen (tests/perf/run-perf.sh). KIND and its parameters:
  sig S                  a signature BIG of S specs (types, eqtypes, values,
                         datatypes, substructures), declared once
  inst S K               BIG, then a signature with K substructures : BIG
                         (instantiation alone, no sharing)
  share S K              as inst, plus K-1 equations `sharing A<i> = A1`
  shareall S K           as inst, plus one equation `sharing A1 = A2 = ... = AK`
  sharenest S K          MLton's shape: K structures M<i> : sig structure A : BIG end
                         and a structure X : BIG with `sharing X = M<i>.A` each
  where S W              BIG, then `BIG where type t1 = int and ... and type tW = int`
  funapp B A             a functor whose body has B declarations, applied A
                         times at top level
  funnest D M B          functors F0..FD, F<i>'s body applies F<i-1> M times
                         and has B declarations of its own; FD applied once
  expo N                 MLton's regression exponential.sml with f applied N
                         times
  funsig S A             BIG of S specs, a structure matching it, and a functor
                         with parameter BIG applied A times (matching cost)

The programs use no Basis Library identifier, so that every compiler can
take them without its Basis.
"""
import sys


def big_sig(S, name="BIG"):
    """S specs, in rotation: type, eqtype, val, datatype, structure."""
    out = [f"signature {name} = sig"]
    types = []
    for i in range(S):
        k = i % 5
        if k == 0:
            out.append(f"  type t{i}")
            types.append(f"t{i}")
        elif k == 1:
            out.append(f"  eqtype e{i}")
            types.append(f"e{i}")
        elif k == 2:
            a = types[-1] if types else "int"
            b = types[-2] if len(types) > 1 else "int"
            out.append(f"  val v{i} : {a} -> {b} * int list")
        elif k == 3:
            a = types[-1] if types else "int"
            out.append(f"  datatype d{i} = D{i} of {a} | E{i} of int * d{i}")
            types.append(f"d{i}")
        else:
            a = types[-1] if types else "int"
            out.append(f"  structure S{i} : sig type u val w : u * {a} end")
    out.append("end")
    return "\n".join(out), types


def impl_struct(S, name="Impl"):
    """A structure that matches big_sig(S): every type int (datatypes
    declared), every value a function that loops or a raise at its type."""
    out = [f"structure {name} = struct"]
    types = []
    val = {"int": "0"}
    for i in range(S):
        k = i % 5
        if k == 0:
            out.append(f"  type t{i} = int")
            types.append(f"t{i}"); val[f"t{i}"] = "0"
        elif k == 1:
            out.append(f"  type e{i} = int")
            types.append(f"e{i}"); val[f"e{i}"] = "0"
        elif k == 2:
            a = types[-1] if types else "int"
            b = types[-2] if len(types) > 1 else "int"
            out.append(f"  fun v{i} (x : {a}) : {b} * int list = v{i} x")
        elif k == 3:
            a = types[-1] if types else "int"
            out.append(f"  datatype d{i} = D{i} of {a} | E{i} of int * d{i}")
            types.append(f"d{i}"); val[f"d{i}"] = f"D{i} ({val[a]})"
        else:
            a = types[-1] if types else "int"
            out.append(f"  structure S{i} = struct type u = int val w : u * {a} = (0, {val[a]}) end")
    out.append("end")
    return "\n".join(out)


def gen_funsig(S, A):
    """a functor whose parameter is BIG (S specs) and whose body uses a
    few of its components, applied A times to the same structure"""
    out = [big_sig(S)[0], impl_struct(S),
           "functor F (X : BIG) = struct val a = X.v2 type t = X.t0 end"]
    for i in range(1, A + 1):
        out.append(f"structure R{i} = F (Impl)")
    return "\n".join(out)


def gen_sig(S):
    return big_sig(S)[0]


def gen_inst(S, K, sharing=None):
    s, _ = big_sig(S)
    out = [s, "signature USE = sig"]
    for i in range(1, K + 1):
        out.append(f"  structure A{i} : BIG")
    if sharing == "chain":
        for i in range(2, K + 1):
            out.append(f"  sharing A{i} = A1")
    elif sharing == "all" and K >= 2:
        out.append("  sharing " + " = ".join(f"A{i}" for i in range(1, K + 1)))
    out.append("end")
    return "\n".join(out)


def gen_sharenest(S, K):
    s, _ = big_sig(S)
    out = [s, "signature USE = sig"]
    for i in range(1, K + 1):
        out.append(f"  structure M{i} : sig structure A : BIG end")
    out.append("  structure X : BIG")
    for i in range(1, K + 1):
        out.append(f"  sharing X = M{i}.A")
    out.append("end")
    return "\n".join(out)


def gen_where(S, W):
    s, types = big_sig(S)
    flex = [t for t in types if t.startswith("t") or t.startswith("e")]
    if W > len(flex):
        sys.exit(f"where: only {len(flex)} non-datatype types in BIG of {S} specs")
    # `and type`: the derived form (Appendix A) that Moscow ML also takes
    clauses = "\n  and ".join(f"type {t} = int" for t in flex[:W])
    return s + "\nsignature W = BIG where " + clauses


ARG = "signature ARG = sig type t val x : t val f : t -> t end"


def body_decs(B, prefix=""):
    """B declarations over the parameter X : ARG."""
    out = []
    for j in range(B):
        k = j % 4
        p = f"{prefix}{j}"
        if k == 0:
            out.append(f"  val a{p} = X.f X.x")
        elif k == 1:
            out.append(f"  fun g{p} y = (X.f y, fn z => (z, y))")
        elif k == 2:
            out.append(f"  datatype d{p} = D{p} of X.t | E{p} of int * d{p}")
        else:
            out.append(f"  fun h{p} (D{prefix}{j-1} v) = X.f v | h{p} (E{prefix}{j-1} (_, d)) = h{p} d")
    return out


def arg_struct(i):
    return f"struct type t = int val x = {i} fun f (y : int) = y end"


def gen_funapp(B, A):
    out = [ARG, "functor F (X : ARG) = struct"] + body_decs(B) + ["end"]
    for i in range(1, A + 1):
        out.append(f"structure S{i} = F ({arg_struct(i)})")
    return "\n".join(out)


def gen_funnest(D, M, B):
    out = [ARG, "functor F0 (X : ARG) = struct"] + body_decs(B) + ["  type t = X.t", "  val x = X.x", "  val f = X.f", "end"]
    for d in range(1, D + 1):
        out.append(f"functor F{d} (X : ARG) = struct")
        for m in range(1, M + 1):
            out.append(f"  structure N{m} = F{d-1} (X)")
        out += body_decs(B)
        out += ["  type t = X.t", "  val x = X.x", "  val f = X.f"]
        out.append("end")
    out.append(f"structure R = F{D} ({arg_struct(1)})")
    return "\n".join(out)


def gen_expo(N):
    fs = " ".join(["f"] * N)
    return ("fun f x = x\n"
            "fun toy () =\n"
            "   let\n"
            f"      fun g y = {fs} y\n"
            "   in g 3; g 4\n"
            "   end\n"
            "val _ = toy ()")


def main():
    kind, args = sys.argv[1], [int(a) for a in sys.argv[2:]]
    gens = {
        "sig": gen_sig,
        "inst": lambda S, K: gen_inst(S, K),
        "share": lambda S, K: gen_inst(S, K, "chain"),
        "shareall": lambda S, K: gen_inst(S, K, "all"),
        "sharenest": gen_sharenest,
        "where": gen_where,
        "funapp": gen_funapp,
        "funnest": gen_funnest,
        "expo": gen_expo,
        "funsig": gen_funsig,
    }
    print(gens[kind](*args))


if __name__ == "__main__":
    main()
