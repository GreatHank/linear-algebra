///|
struct Matrix[T] {
  row : Int
  col : Int
  data : Array[T]
} derive(Eq)

///|
struct Lens[T] {
  set : (Int, T) -> Unit
  get : (Int) -> T
}

///|
pub impl[T : Show] Show for Matrix[T] with to_string(s) {
  let mut res = ""
  for i in 0..<s.row {
    res = res + "|"
    for j in 0..<s.col {
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
pub fn[T, U] Matrix::map(self : Matrix[T], f : (T) -> U) -> Matrix[U] {
  { row: self.row, col: self.col, data: self.data.map(f) }
}

///|
pub fn[T] matrix_to_transpose(self : Matrix[T]) -> Transpose[T] {
  { row: self.col, col: self.row, data: self.data }
}

///|
pub fn[T] Matrix::map_row(self : Matrix[T], row : Int, f : (T) -> T) -> Unit {
  for i in 0..<self.col {
    self.data[row * self.col + i] = f(self.data[row * self.col + i])
  }
}

///|
pub fn[T] Matrix::map_col(self : Matrix[T], col : Int, f : (T) -> T) -> Unit {
  for i in 0..<self.row {
    self.data[i * self.col + col] = f(self.data[i * self.col + col])
  }
}

///|
pub fn[T] Matrix::copy(self : Matrix[T]) -> Matrix[T] {
  { row: self.row, col: self.col, data: self.data.copy() }
}

///|
test "map_function" {
  let m = Matrix::from_2d_array([[1, 2, 3], [4, 5, 6]])
  let m1 = {
    m.copy()..map_row(0, fn(x) { x * 2 })
    m
  }
  let m2 = {
    m.copy()..map_col(0, fn(x) { x * 2 })
    m
  }
  inspect(m1.to_string(), content="|2, 4, 6|\n|4, 5, 6|")
  inspect(m2.to_string(), content="|2, 2, 3|\n|8, 5, 6|")
}

///|
pub fn[A] Matrix::make(row : Int, col : Int, f : (Int, Int) -> A) -> Matrix[A] {
  { row, col, data: Array::makei(row * col, fn(i) { f(i / col, i % col) }) }
}

///|
pub fn[T] Matrix::new(row : Int, col : Int, elem : T) -> Matrix[T] {
  Matrix::make(row, col, fn { _, _ => elem })
}

///|
pub fn[T] Matrix::from_2d_array(arr : Array[Array[T]]) -> Matrix[T] {
  Matrix::make(arr.length(), arr[0].length(), fn(i, j) { arr[i][j] })
}

///|
pub fn[T] Matrix::from_array(
  row : Int,
  col : Int,
  data : Array[T]
) -> Matrix[T] {
  guard row * col == data.length()
  { row, col, data }
}

///| 
pub fn[T] Matrix::op_get(self : Matrix[T], row : Int) -> Lens[T] {
  {
    set: fn { c, v => self.data[c + self.col * row] = v },
    get: fn { c => self.data[c + self.col * row] },
  }
}

///|
pub fn[T] op_get(self : Lens[T], col : Int) -> T {
  (self.get)(col)
}

///|
pub fn[T] Lens::op_set(self : Lens[T], col : Int, elem : T) -> Unit {
  (self.set)(col, elem)
}

///|
test "op_set" {
  let m = Matrix::from_2d_array([[2, 3, 4], [1, 2, 3]])
  inspect(m[0][1], content="3")
  m[0][1] = 4
  inspect(m[0][1], content="4")
}

///|
pub impl[T : Mul + Add] Mul for Matrix[T] with op_mul(
  self : Matrix[T],
  other : Matrix[T]
) -> Matrix[T] {
  let row = self.row
  let col = other.col
  let inner = self.col
  guard inner == other.row
  let data = Array::makei(row * col, fn(i) {
    let r = i / col
    let c = i % col
    let mut sum = self[r][0] * other[0][c]
    for k in 1..<inner {
      sum += self[r][k] * other[k][c]
    }
    sum
  })
  { row, col, data }
}

///|
pub impl[T : Add] Add for Matrix[T] with op_add(
  self : Matrix[T],
  other : Matrix[T]
) -> Matrix[T] {
  guard self.col == other.col
  guard self.row == other.row
  {
    data: array_zip_with(self.data, other.data, T::op_add),
    row: self.row,
    col: self.col,
  }
}

///|
pub impl[T : Neg] Neg for Matrix[T] with op_neg(self : Matrix[T]) -> Matrix[T] {
  self.map(T::op_neg)
}

///|
pub impl[T : Add + Neg] Sub for Matrix[T] with op_sub(
  self : Matrix[T],
  other : Matrix[T]
) -> Matrix[T] {
  self + -other
}

///|
pub fn[T : Mul] scale(self : Matrix[T], cst : T) -> Matrix[T] {
  self.map(fn(x) { x * cst })
}

///|
pub fn[T : Add] add_constant(self : Matrix[T], cst : T) -> Matrix[T] {
  self.map(fn(x) { x + cst })
}

///|
pub fn[T : One + Zero] identity(size : Int) -> Matrix[T] {
  Matrix::make(size, size, fn(i, j) {
    guard i == j else { T::zero() }
    T::one()
  })
}

///|
pub fn[T : Compare + Zero] null(self : Matrix[T]) -> Bool {
  not(self.data.iter().any(fn(x) { x != T::zero() }))
}

///|
pub fn[T : Conjugate] adjoint(self : Matrix[T]) -> Matrix[T] {
  self.map(T::conjugate)
}

///|
pub fn[T] transpose(self : Matrix[T]) -> Matrix[T] {
  Matrix::make(self.col, self.row, fn(i, j) { self[j][i] })
}

///|
pub fn[T] swap_rows(self : Matrix[T], r1 : Int, r2 : Int) -> Unit {
  let r = self.row
  let c = self.col
  guard r1 < r && r2 < r && r1 >= 0 && r2 >= 0
  if r1 == r2 {
    return
  }
  let temp = Array::makei(c, fn(i) { self.data[r1 * self.col + i] })
  for i in 0..<c {
    self.data[r1 * self.col + i] = self.data[r2 * self.col + i]
  }
  for i in 0..<c {
    self.data[r2 * self.col + i] = temp[i]
  }
}

///|
pub fn[T] swap_cols(self : Matrix[T], c1 : Int, c2 : Int) -> Unit {
  let r = self.row
  let c = self.col
  guard c1 < c && c2 < c && c1 >= 0 && c2 >= 0
  if c1 == c2 {
    return
  }
  let temp = Array::makei(r, fn(i) { self.data[i * self.col + c1] })
  for i in 0..<r {
    self.data[i * self.col + c1] = self.data[i * self.col + c2]
  }
  for i in 0..<r {
    self.data[i * self.col + c2] = temp[i]
  }
}

///|
test "swap" {
  let m = Matrix::from_2d_array([[1, 2, 3], [4, 5, 6]])
  let m1 = {
    m.copy()..swap_rows(0, 1)
    m
  }
  let m2 = {
    m.copy()..swap_cols(0, 1)
    m
  }
  inspect(m1.to_string(), content="|4, 5, 6|\n|1, 2, 3|")
  inspect(m2.to_string(), content="|2, 1, 3|\n|5, 4, 6|")
}

///|
pub fn[T : Semiring] pow(self : Matrix[T], power : Int) -> Matrix[T] {
  loop identity(self.col), power, self {
    s, 0, _ => s
    s, 1, m => s * m
    s, p, m => continue if (p & 1) == 1 { s * m } else { s }, p >> 1, m * m
  }
}

///|
pub fn[T : Compare + Num + Sub + Inverse] reduce_row_elimination(
  self : Matrix[T]
) -> Matrix[T] {
  let r = self.row
  let c = self.col
  let mut col = 0
  for i in 0..<r {
    if col >= c {
      break
    }
    let mut max_row = i
    for j in (i + 1)..<r {
      if self[j][col].abs() > self[max_row][col].abs() {
        max_row = j
      }
    }
    ignore(self.swap_rows(i, max_row))
    if self[i][col] == T::zero() {
      col = col + 1
      continue
    }
    let val = self[i][col]
    ignore(self.map_row(i, fn(x) { x * val.inv() }))
    for j in 0..<r {
      if j == i {
        continue
      }
      let factor = self[j][col]
      for k in 0..<c {
        self[j][k] = self[j][k] - self[i][k] * factor
      }
    }
    col = col + 1
  }
  self
}

///|
test "reduce_row_elimination" {
  let m = Matrix::from_2d_array([
    [1.0, 2.0, 3.0, 7.0],
    [1.0, 1.0, 1.0, 2.0],
    [2.0, 3.0, 3.0, 5.0],
  ])
  inspect(
    m.reduce_row_elimination(),
    content=
      #||1, 0, 0, 1|
      #||0, 1, 0, -3|
      #||0, 0, 1, 4|
    ,
  )
}

///|
pub fn[T] horizontal_combine(self : Matrix[T], other : Matrix[T]) -> Matrix[T] {
  guard self.row == other.row
  Matrix::make(self.row, self.col + other.col, fn(i, j) {
    if j < self.col {
      self[i][j]
    } else {
      other[i][j - self.col]
    }
  })
}

///|
pub fn[T] vertical_combine(self : Matrix[T], other : Matrix[T]) -> Matrix[T] {
  guard self.col == other.col
  let array = self.data
  array.push_iter(other.data.iter())
  return { row: self.row + other.row, col: self.col, data: array }
}

///|
test "matrix_combine" {
  let m1 = Matrix::from_2d_array([[1, 2], [3, 4]])
  let m2 = Matrix::from_2d_array([[1, 0], [0, 1]])
  let m3 = m1.horizontal_combine(m2)
  let m4 = m1.vertical_combine(m2)
  inspect(
    m3,
    content=
      #||1, 2, 1, 0|
      #||3, 4, 0, 1|
    ,
  )
  inspect(
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
pub fn[T] row_to_array(self : Matrix[T], row : Int) -> Array[T] {
  guard row >= 0 && row < self.row
  let start = row * self.col
  let end = start + self.col
  let arr = []
  for i in start..<end {
    arr.push(self.data[i])
  }
  arr
}

///|
pub fn[T] col_to_array(self : Matrix[T], col : Int) -> Array[T] {
  guard col >= 0 && col < self.col
  let arr = []
  for i in 0..<self.row {
    arr.push(self.data[i * self.col + col])
  }
  arr
}

///|
pub fn[T] to_array(self : Matrix[T]) -> Array[T] {
  self.data.copy()
}
