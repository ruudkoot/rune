#!/usr/bin/env python3
"""Independently rewrite the geometric KB axioms using reviewed final rules."""
import random
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2] / "examples/benchmarks"


def parse(text):
    tokens = re.findall(r"v\d+|[A-Z]|[()*]", text)
    at = 0

    def atom():
        nonlocal at
        token = tokens[at]
        at += 1
        if token == "(":
            value = product()
            assert tokens[at] == ")"
            at += 1
            return value
        if token == "I":
            assert tokens[at] == "("
            at += 1
            value = product()
            assert tokens[at] == ")"
            at += 1
            return ("I", value)
        return (token,)

    def product():
        nonlocal at
        result = atom()
        while at < len(tokens) and tokens[at] == "*":
            at += 1
            result = ("*", result, atom())
        return result

    result = product()
    assert at == len(tokens)
    return result


def match(pattern, term, bindings):
    name = pattern[0]
    if name.startswith("v"):
        if name in bindings:
            return bindings[name] == term
        bindings[name] = term
        return True
    return name == term[0] and len(pattern) == len(term) and all(
        match(p, t, bindings) for p, t in zip(pattern[1:], term[1:]))


def substitute(term, bindings):
    return bindings[term[0]] if term[0].startswith("v") else (
        term[0], *(substitute(t, bindings) for t in term[1:]))


def normal(term, rules):
    budget = 10000

    def visit(term):
        nonlocal budget
        term = (term[0], *(visit(t) for t in term[1:]))
        for lhs, rhs in rules:
            bindings = {}
            if match(lhs, term, bindings):
                budget -= 1
                assert budget > 0, "nonterminating rewrite"
                return visit(substitute(rhs, bindings))
        return term

    return visit(term)


def check():
    rules = []
    for line in (ROOT / "validation/geometric-kb.rules").read_text().splitlines():
        equation = line.split(" : ", 1)[1]
        lhs, rhs = equation.split(" = ")
        rules.append((parse(lhs), parse(rhs)))
    assert len(rules) == 24
    axioms = ["U*v1 = v1", "I(v1)*v1 = U", "(v3*v2)*v1 = v3*(v2*v1)",
              "A*B = B*A", "C*C = U", "I(A) = C*(A*I(C))", "C*(B*I(C)) = B"]
    equations = [tuple(parse(side) for side in axiom.split(" = ")) for axiom in axioms]
    assert all(normal(lhs, rules) == normal(rhs, rules) for lhs, rhs in equations)
    rng = random.Random(104)

    def term(depth):
        if depth == 0 or rng.randrange(3) == 0:
            return (rng.choice("UABC"),)
        if rng.randrange(3) == 0:
            return ("I", term(depth - 1))
        return ("*", term(depth - 1), term(depth - 1))

    for _ in range(100):
        bindings = {"v" + str(i): term(3) for i in range(1, 4)}
        for lhs, rhs in equations:
            assert normal(substitute(lhs, bindings), rules) == normal(substitute(rhs, bindings), rules)
    reduced = [r for r in rules if r[0] != parse("I(A)")]
    assert normal(parse("I(A)"), reduced) != normal(parse("C*(A*I(C))"), reduced)
    print("KB oracle: 24 rules, 7 open axioms, 700 ground instances; removed-rule check rejected")


if __name__ == "__main__":
    check()
