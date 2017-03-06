//Classes for working with matrices of numbers/UGens which are represented by nested Arrays
//a[r][c] is element of a at row r and column c
// so a column vector looks like : [[1], [2], [3]]
//  but [1,2,3] should also work, for convenience.
//  Array.flop already cooperates: [1,2,3].flop == [[1,2,3]]
// and a row vector: [[1,2,3]]

DotProduct {
	*ar { |v1, v2|
		^Mix.ar(v1*v2)
	}
	*kr { |v1, v2|
		^Mix.kr(v1*v2)
	}
}

MatMul {
	*ar { |m1, m2|
		var m2t = m2.flop;
		^Array.fill2D(m1.size, m2t.size, {|r,c|
			DotProduct.ar(m1[r], m2t[c])
		})
	}
	*kr { |m1, m2|
		var m2t = m2.flop;
		^Array.fill2D(m1.size, m2t.size, {|r,c|
			DotProduct.kr(m1[r], m2t[c])
		})
	}
}

//nested ArrayMin
// ArrayMin returns a list, which interacts weirdly with multichannel expansion
MatMin {
	*ar { |m|
		^ArrayMin.ar(ArrayMin.ar(m).flop[0])[0]
	}
	*kr { |m|
		^ArrayMin.kr(ArrayMin.kr(m).flop[0])[0]
	}
}

// construct a well-behaved feedback matrix
//  (nonnegative with all rows and columns summing to 1)
// from a given (square) source matrix
FBMat {
	*ar { |m, i=1,j=1|
		var n = m.size,
		eqd = Array.fill2D(n, n, {|r,c|
			Mix.ar([
				m[r][c],
				0-m.wrapAt(r+i)[c],
				0-m[r].wrapAt(c+j),
				m.wrapAt(r+i).wrapAt(c+j)
			])
		}),
		pos = eqd-MatMin.ar(eqd)+1e-7,
		norm = Mix.ar(Mix.ar(pos));
		^(pos*n/norm)
	}
	*kr { |m, i=1,j=1|
		var n = m.size,
		eqd = Array.fill2D(n, n, {|r,c|
			Mix.kr([
				m[r][c],
				0-m.wrapAt(r+i)[c],
				0-m[r].wrapAt(c+j),
				m.wrapAt(r+i).wrapAt(c+j)
			])
		}),
		pos = eqd-MatMin.kr(eqd)+1e-7,
		norm = Mix.kr(Mix.kr(pos));
		^(pos*n/norm)
	}
}
// s.boot
// misc test/debug snippets
// [1,2,3].flop == [[1,2,3]]
// MatMul.ar([[1,2,3]], [1,2,3])
// MatMul.ar([1,2,3], [[1,2]])
// {ArrayMin.kr([[1,2,3], [4,5,6]].flop).flop[0].poll(label: \test)}.play
// {MatMin.kr([[1,2,3], [4,5,6]]).poll(label:\test)}.play
// {FBMat.ar([[1,0,0,0], [0,1,0,0], [0,0,1,0], [0,0,0,1]]).poll(1, label:\test)}.play