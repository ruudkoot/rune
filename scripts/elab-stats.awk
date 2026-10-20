# scripts/elab-stats.awk -- the lines of `rune --pass-stats=elab` (docs/ir.md, The elaborator's
# counters) added up: the elaborator's processor time by context and operation, with each one's
# share of the whole, the counters summed (app.depth: the deepest), and the -v top=N (10)
# declarations that took longest. Other lines of standard error are skipped, so the whole of it
# can be given:
#
#   rune --pass-stats=elab ... 2> stats; awk -f scripts/elab-stats.awk stats
BEGIN { if (top == "") top = 10 }
$1 == "elab" && NF >= 5 {
  decls++
  for (i = 5; i <= NF; i++) {
    eq = index($i, "=")
    if (eq == 0) continue
    k = substr($i, 1, eq - 1); v = substr($i, eq + 1) + 0
    if (k == "total") {
      total += v
      worst[decls] = v; what[decls] = $2 " " $3 " " $4
    } else if (k ~ /\./ && k !~ /^(inst|share|match|app)\./) {
      cell[k] += v
      split(k, p, "."); ctx[p[1]] += v; opn[p[2]] += v
    } else if (k == "app.depth") {
      if (v > count[k]) count[k] = v
    } else count[k] += v
  }
}
function s(us) { return sprintf("%.3f", us / 1000000) }
function pct(us) { return total > 0 ? sprintf("%.1f%%", 100 * us / total) : "-" }
END {
  nc = split("top fundecl appcode appcheck", cs, " ")
  no = split("core inst where share match specs copy", os, " ")
  printf "%d declarations, %s s of elaboration\n\n", decls, s(total)
  printf "%-10s", "s"
  for (j = 1; j <= no; j++) printf " %9s", os[j]
  printf " %9s %7s\n", "all", "%"
  for (i = 1; i <= nc; i++) {
    printf "%-10s", cs[i]
    for (j = 1; j <= no; j++) printf " %9s", s(cell[cs[i] "." os[j]])
    printf " %9s %7s\n", s(ctx[cs[i]]), pct(ctx[cs[i]])
  }
  printf "%-10s", "all"
  for (j = 1; j <= no; j++) printf " %9s", s(opn[os[j]])
  printf " %9s\n%-10s", s(total), "%"
  for (j = 1; j <= no; j++) printf " %9s", pct(opn[os[j]])
  printf "\n\ncounters:"
  nk = split("realize nodes inst inst.names where share.types share.structures match match.paths fundecl app.code app.check app.depth unify steps", ks, " ")
  for (j = 1; j <= nk; j++) printf " %s=%d", ks[j], count[ks[j]]
  printf "\n\nthe %d declarations that took longest:\n", top
  for (n = 0; n < top && n < decls; n++) {
    best = 0
    for (d in worst) if (best == 0 || worst[d] > worst[best]) best = d
    if (best == 0) break
    printf "%10s s  %s\n", s(worst[best]), what[best]
    delete worst[best]
  }
}
