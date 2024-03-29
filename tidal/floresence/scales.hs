-- just2semi j = 12 * (log j) / (log 2)
rat2semi rat_pat = (log rat_pat) * (12 / log 2)
rat2semi' rat_pat = (log rat_pat) |* (12 / log 2)
semi2rat semi_pat = exp (semi_pat * (log 2) / 12)
newscales = [
      ("justionian",     map rat2semi [1,   9/8,   5/4,   4/3,   3/2,   5/3, 15/8]),
      ("justdorian",     map rat2semi [1,   9/8,   6/5,   4/3,   3/2,   5/3, 16/9]),
      ("justphrygian",   map rat2semi [1, 16/15,   6/5,   4/3,   3/2,   8/5, 16/9]),
      ("justlydian",     map rat2semi [1,   9/8,   5/4, 45/32,   3/2,   5/3, 15/8]),
      ("justmixolydian", map rat2semi [1,   9/8,   5/4,   4/3,   3/2,   5/3, 16/9]),
      ("justaeolian",    map rat2semi [1,   9/8,   6/5,   4/3,   3/2,   8/5, 16/9]),
      ("justlocrian",    map rat2semi [1, 16/15,   6/5,   4/3,   45/32, 8/5, 16/9]),
      ("tenthirdsdorian",map rat2semi [1, 1.11572158, 1.2, 1.3388659, 1.49380158, 1.66666667, 1.7925619])] -- third root of 10/3 tuning
