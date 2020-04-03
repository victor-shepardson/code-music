just2semi j = 12 * (log j) / (log 2)
semi2just s = exp (s * (log 2) / 12)
newscales = [
      ("justionian",     map just2semi [1,   9/8,   5/4,   4/3,   3/2,   5/3, 15/8]),
      ("justdorian",     map just2semi [1,   9/8,   6/5,   4/3,   3/2,   5/3, 16/9]),
      ("justphrygian",   map just2semi [1, 16/15,   6/5,   4/3,   3/2,   8/5, 16/9]),
      ("justlydian",     map just2semi [1,   9/8,   5/4, 45/32,   3/2,   5/3, 15/8]),
      ("justmixolydian", map just2semi [1,   9/8,   5/4,   4/3,   3/2,   5/3, 16/9]),
      ("justaeolian",    map just2semi [1,   9/8,   6/5,   4/3,   3/2,   8/5, 16/9]),
      ("justlocrian",    map just2semi [1, 16/15,   6/5,   4/3,   45/32, 8/5, 16/9])]
