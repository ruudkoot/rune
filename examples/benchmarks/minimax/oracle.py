"""Independent board-based exhaustive oracle; not part of timed SML work."""

LINES = ((0, 1, 2), (3, 4, 5), (6, 7, 8), (0, 3, 6),
         (1, 4, 7), (2, 5, 8), (0, 4, 8), (2, 4, 6))


def search(board, player, cache):
    for line in LINES:
        if board[line[0]] and all(board[i] == board[line[0]] for i in line):
            return 1, 1, board[line[0]]
    if 0 not in board:
        return 1, 1, 0
    key = board, player
    if cache is not None and key in cache:
        return 1, 1, cache[key]
    children = []
    for i, square in enumerate(board):
        if not square:
            child = board[:i] + (player,) + board[i + 1:]
            children.append(search(child, -player, cache))
    score = (max if player == 1 else min)(s for _, _, s in children)
    if cache is not None:
        cache[key] = score
    return 1 + sum(n for n, _, _ in children), 1 + max(d for _, d, _ in children), score


if __name__ == "__main__":
    full = search((0,) * 9, 1, None)
    table = search((0,) * 9, 1, {})
    assert full == (549946, 10, 0)
    assert table == (16168, 10, 0)
    print(*full, *table)
