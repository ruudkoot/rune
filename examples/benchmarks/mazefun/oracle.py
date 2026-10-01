"""Union-find maze oracle, independent of the list/flood-fill SML kernel."""
from pathlib import Path


def maze(n, m):
    cells = {(i, j) for i in range(0, n, 2) for j in range(0, m, 2)}
    parent = {cell: cell for cell in cells}

    def find(cell):
        if parent[cell] != cell:
            parent[cell] = find(parent[cell])
        return parent[cell]

    holes = [(i, j) for i in range(n) for j in range(m) if i % 2 != j % 2]
    seed = 0
    while holes:
        seed = (seed * 3581 + 12751) % 131072
        i, j = holes.pop(seed % len(holes))
        neighbors = [(a, b) for a, b in ((i-1, j), (i+1, j), (i, j-1), (i, j+1))
                     if (a, b) in cells]
        roots = [find(cell) for cell in neighbors]
        if len(set(roots)) == len(roots):
            cells.add((i, j))
            parent[i, j] = (i, j)
            for root in roots:
                parent[root] = (i, j)
    # Every original cavity is connected; each passage has degree two.
    assert len({find(cell) for cell in parent}) == 1
    assert len(cells) == 2 * (((n+1)//2) * ((m+1)//2)) - 1
    return "/".join("".join(" _" if (i, j) in cells else " *" for j in range(m))
                    for i in range(n))


if __name__ == "__main__":
    base = Path(__file__).resolve().parent
    for profile, n, m in (("smoke", 11, 11), ("normal", 15, 15), ("large", 15, 15)):
        assert (base / (profile + ".expected")).read_text() == maze(n, m) + "\n"
    print("mazefun oracle: three independent fixtures agree")
