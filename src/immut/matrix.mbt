///|
typealias IArray[T] = @immut/array.T[T]

///|
struct Matrix[T] {
  row : Int
  col : Int
  data : IArray[T]
} derive(Eq)

///|
struct Indexed[T] {
  index : (Int) -> T
}

///|
pub impl[T : Show] Show for Matrix[T] with to_string(s) {
  let mut res = ""
  for i = 0; i < s.row; i = i + 1 {
    res = res + "|"
    for j = 0; j < s.col; j = j + 1 {
      res = res + s.data[i * s.col + j].to_string()
      if j < s.col - 1 {
        res = res + ", "
      }
    }
    res = res + "|"
    if i < s.row - 1 {
      res = res + "\n"
    }
  }
  res
}

///|
pub impl[T : Show] Show for Matrix[T] with output(s, l) {
  l.write_string(s.to_string())
}

///|
pub fn map[T, U](self : Matrix[T], f : (T) -> U) -> Matrix[U] {
  { row: self.row, col: self.col, data: self.data.map(f) }
}

///|
pub fn Matrix::make[T](row : Int, col : Int, f : (Int, Int) -> T) -> Matrix[T] {
  {
    row,
    col,
    data: @immut/array.makei(row * col, fn(i) { f(i / col, i % col) }),
  }
}

///|
pub fn Matrix::new[T](row : Int, col : Int, elem : T) -> Matrix[T] {
  Matrix::make(row, col, fn { _, _ => elem })
}

///|
pub fn Matrix::from_2d_array[T](arr : Array[Array[T]]) -> Matrix[T] {
  Matrix::make(arr.length(), arr[0].length(), fn(i, j) { arr[i][j] })
}

///|
pub fn Matrix::op_get[T](self : Matrix[T], row : Int) -> Indexed[T] {
  { index: fn { c => self.data[c + self.col * row] } }
}

///|
pub fn op_get[T](self : Indexed[T], col : Int) -> T {
  (self.index)(col)
}

///|
pub fn Matrix::set[T](
  self : Matrix[T],
  i : Int,
  j : Int,
  elem : T
) -> Matrix[T] {
  { row: self.row, col: self.col, data: self.data.set(i * self.col + j, elem) }
}

///|
test {
  let m = Matrix::from_2d_array([[2, 3, 4], [1, 2, 3]])
  inspect!(
    m,
    content=
      #||2, 3, 4|
      #||1, 2, 3|
    ,
  )
  inspect!(m[0][1], content="3")
}

///|
pub fn op_mul[T : @lg.Mul + @lg.Add](
  self : Matrix[T],
  other : Matrix[T]
) -> Matrix[T] {
  let row = self.row
  let col = other.col
  let inner = self.col
  guard inner == other.row
  let data = @immut/array.makei(row * col, fn(i) {
    let r = i / col
    let c = i % col
    let mut sum = self[r][0] * other[0][c]
    for k = 1; k < inner; k = k + 1 {
      sum = sum + self[r][k] * other[k][c]
    }
    sum
  })
  { row, col, data }
}

///|
pub fn op_add[T : @lg.Add](self : Matrix[T], other : Matrix[T]) -> Matrix[T] {
  guard self.col == other.col
  guard self.row == other.row
  {
    data: array_zip_with(self.data, other.data, T::op_add),
    row: self.row,
    col: self.col,
  }
}

///|
pub fn op_neg[T : @lg.Neg](self : Matrix[T]) -> Matrix[T] {
  self.map(T::op_neg)
}

///|
pub fn op_sub[T : @lg.Add + @lg.Neg](
  self : Matrix[T],
  other : Matrix[T]
) -> Matrix[T] {
  self + -other
}

///|
pub fn scale[T : @lg.Mul](self : Matrix[T], cst : T) -> Matrix[T] {
  self.map(fn(x) { x * cst })
}

///|
pub fn add_constant[T : @lg.Add](self : Matrix[T], cst : T) -> Matrix[T] {
  self.map(fn(x) { x + cst })
}

///|
pub fn identity[T : @lg.One + @lg.Zero](size : Int) -> Matrix[T] {
  Matrix::make(size, size, fn(i, j) {
    guard i == j else { T::zero() }
    T::one()
  })
}

///|
pub fn null[T : Compare + @lg.Zero](self : Matrix[T]) -> Bool {
  not(self.data.iter().any(fn(x) { x != T::zero() }))
}

///|
pub fn adjoint[T : @lg.Conjugate](self : Matrix[T]) -> Matrix[T] {
  self.map(T::conjugate)
}

///| Compute the transpose of a matrix
pub fn transpose[T](self : Matrix[T]) -> Matrix[T] {
  Matrix::make(self.col, self.row, fn(i, j) { self[j][i] })
}

///| Compute the determinant of a matrix
pub fn determinant[T : @lg.Mul + @lg.Add + @lg.One + @lg.Neg + @lg.Zero](
  self : Matrix[T]
) -> T {
  let n = self.row
  guard n == self.col
  fn go {
    f, 1 => f(0, 0)
    f, n => {
      let mut det = T::zero()
      for i in 0..<n {
        let sub_view = fn { j, k => f(j + 1, if k < i { k } else { k + 1 }) }
        let sign = if i % 2 == 0 { T::one() } else { -T::one() }
        det += sign * f(0, i) * go(sub_view, n - 1)
      }
      det
    }
  }

  go(fn { i, j => self[i][j] }, n)
}

///|
pub fn pow[T : @lg.Semiring](self : Matrix[T], power : Int) -> Matrix[T] {
  loop identity(self.col), power, self {
    s, 0, _ => s
    s, 1, m => s * m
    s, p, m => continue if (p & 1) == 1 { s * m } else { s }, p >> 1, m * m
  }
}

///|
pub fn horizontal_combine[T](self : Matrix[T], other : Matrix[T]) -> Matrix[T] {
  let r1 = self.row
  let c1 = self.col
  let r2 = other.row
  let c2 = other.col
  guard r1 == r2
  Matrix::make(r1, c1 + c2, fn(i, j) {
    if j < c1 {
      self[i][j]
    } else {
      other[i][j - c1]
    }
  })
}

///|
pub fn vertical_combine[T](self : Matrix[T], other : Matrix[T]) -> Matrix[T] {
  Matrix::horizontal_combine(self.transpose(), other.transpose()).transpose()
}

///|
test "matrix_combine" {
  let m1 = Matrix::from_2d_array([[1, 2], [3, 4]])
  let m2 = Matrix::from_2d_array([[1, 0], [0, 1]])
  let m3 = horizontal_combine(m1, m2)
  let m4 = vertical_combine(m1, m2)
  inspect!(
    m3,
    content=
      #||1, 2, 1, 0|
      #||3, 4, 0, 1|
    ,
  )
  inspect!(
    m4,
    content=
      #||1, 2|
      #||3, 4|
      #||1, 0|
      #||0, 1|
    ,
  )
}

///|
pub fn swap_rows[T](self : Matrix[T], r1 : Int, r2 : Int) -> Matrix[T] {
  guard r1 < self.row && r2 < self.row
  guard r1 >= 0 && r2 >= 0
  guard r1 != r2
  let new_matrix = Matrix::make(self.row, self.col, fn(i, j) {
    if i == r1 {
      self[r2][j]
    } else if i == r2 {
      self[r1][j]
    } else {
      self[i][j]
    }
  })
  new_matrix
}

///|
pub fn swap_cols[T](self : Matrix[T], c1 : Int, c2 : Int) -> Matrix[T] {
  self.transpose().swap_rows(c1, c2).transpose()
}

///|
test "swap_matrix" {
  let m1 = Matrix::from_2d_array([[1, 2], [3, 4]])
  let m2 = Matrix::from_2d_array([[1, 0], [0, 1]])
  let m3 = swap_rows(m1, 0, 1)
  let m4 = swap_cols(m2, 0, 1)
  inspect!(
    m3,
    content=
      #||3, 4|
      #||1, 2|
    ,
  )
  inspect!(
    m4,
    content=
      #||0, 1|
      #||1, 0|
    ,
  )
}

///|
test {
  let m1 = Matrix::from_2d_array([[1, 2], [3, 4]])
  let m2 = Matrix::from_2d_array([[1, 0], [0, 1]])
  let m3 = m1 * m2
  let m4 = m1 + m2
  inspect!(
    m3,
    content=
      #||1, 2|
      #||3, 4|
    ,
  )
  inspect!(
    m4,
    content=
      #||2, 2|
      #||3, 5|
    ,
  )
  inspect!(
    -m1,
    content=
      #||-1, -2|
      #||-3, -4|
    ,
  )
  inspect!(
    m1.scale(10),
    content=
      #||10, 20|
      #||30, 40|
    ,
  )
  let m5 : Matrix[Int] = identity(5)
  inspect!(
    m5,
    content=
      #||1, 0, 0, 0, 0|
      #||0, 1, 0, 0, 0|
      #||0, 0, 1, 0, 0|
      #||0, 0, 0, 1, 0|
      #||0, 0, 0, 0, 1|
    ,
  )
  inspect!(
    m4.add_constant(10),
    content=
      #||12, 12|
      #||13, 15|
    ,
  )
  inspect!(m4.determinant(), content="4")
  inspect!(m1.determinant(), content="-2")
  inspect!(m5.determinant(), content="1")
  let m = Matrix::make(3, 3, fn(i, _) -> Int { i }).pow(10)
  inspect!(
    m,
    content=
      #||0, 0, 0|
      #||19683, 19683, 19683|
      #||39366, 39366, 39366|
    ,
  )
}
