# kitreynolds3 provenance

ML Kit `6dab5582db22a5f5672ca1fc5244171687d83ce5`, `test/kitreynolds3.sml`. Original, patch and notices retained.

Shared binary tree with labels descending by depth. The exhaustive
ancestor search remains exponential although mk_tree allocates only n nodes.
Uses an explicit ancestor list and membership traversal.
No ancestor label can repeat on a path, giving an independent false result
for every positive depth. Normal retains depth 20; output becomes a checked
count of searches. The two representation variants remain separately named.
