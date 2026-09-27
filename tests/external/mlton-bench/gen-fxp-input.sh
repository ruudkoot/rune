#!/bin/sh
# gen-fxp-input.sh > fxp-input.xml -- the input of MLton's fxp benchmark,
# which the suite does not ship: a 2 MB XML document of sections, paragraphs,
# lists and notes with attributes, character references and entity
# references, made by a fixed linear congruential generator so that every
# machine gets the same document and the same --count. No DOCTYPE, so fxp
# parses without validating.
awk 'BEGIN {
  srand(0); seed = 12345
  split("alpha beta gamma delta epsilon zeta eta theta iota kappa lambda mu nu xi omicron pi rho sigma tau upsilon phi chi psi omega", w, " ")
  split("section para list item note em code ref", tags, " ")
  split("href id class rel n", attrs, " ")
  print "<?xml version=\"1.0\" encoding=\"UTF-8\"?>"
  print "<doc>"
  size = 0
  while (size < 1200000) size += element(1)
  print "</doc>"
}
function rnd(n) { seed = (seed * 1103515245 + 12345) % 2147483648; return int(seed / 65536) % n }
function word() { return w[rnd(24) + 1] }
function text(k,   s, i) {
  s = ""
  for (i = 0; i < k; i++) s = s (i ? " " : "") word()
  if (rnd(4) == 0) s = s " &amp; " word() " &lt;x&gt; (c)"
  return s
}
function attributes(   s, k, i) {
  s = ""; k = rnd(4)
  for (i = 0; i < k; i++) s = s " " attrs[rnd(5) + 1] "=\"" word() rnd(1000) "\""
  return s
}
function element(depth,   t, a, n, i, out, k) {
  t = tags[rnd(8) + 1]
  if (depth == 1 && rnd(3) == 0) t = "section"
  a = attributes()
  out = "<" t a ">\n"
  n = rnd(3) + 1
  for (i = 0; i < n; i++) {
    k = rnd(12) + 1
    out = out text(k) "\n"
    if (depth < 3 && rnd(3) == 0) out = out element(depth + 1)
  }
  if (t == "section") out = "<title" attributes() ">\n" text(4) "\n</title>\n" out
  out = out "</" t ">\n"
  printf "%s", out
  return length(out)
}'
