require 'math'

Quadratic = {a=0,b=0,c=0}

function Quadratic:new(a, b, c)
	o = {}
	setmetatable(o, self)
	self.__index = self
	self.a = a or 0
	self.b = b or 0
	self.c = c or 0
	return o
end

function Quadratic:roots()
	sqrroot = (self.b^2 - 4*self.a*self.c)
	
	if sqrroot < 0 then
		return nil
	elseif self.a == 0 then
		return self.c / self.b^2
	else
		return {(-self.b + sqrroot^0.5)/(2*self.a),(-self.b - sqrroot^0.5)/(2*self.a)}
	end
end

function Quadratic.__add(x1, x2)
	return Quadratic:new(x1.a+x2.a, x1.b+x2.b, x1.c+x2.c)
end

function Quadratic.__sub(x1, x2)
	return Quadratic:new(x1.a-x2.a, x1.b-x2.b, x1.c-x2.c)
end

function Quadratic.__mul(x1, x2)

    --(bx + c) * (b'x + c') = bb'x^2 + bc'x + b'cx + cc'
    a = x1.b * x2.b + x1.a * x2.c + x1.c * x2.a

    b = x1.b * x2.c + x2.b * x1.c

    c = x1.c * x2.c

    return Quadratic:new(a, b, c)
end


function determinant_marginal(m, valid_cols, valid_rows)
  if valid_cols == nil then
    valid_cols = {}
    for i = 1, #m do
      valid_cols[i] = i
    end
  end
  if valid_rows == nil then
    valid_rows = {}
    for i = 1, #m do
      valid_rows[i] = i
    end
  end

  if #valid_rows == 2 then
    local a = m[valid_rows[1]][valid_cols[1]]
    local b = m[valid_rows[1]][valid_cols[2]]
    local c = m[valid_rows[2]][valid_cols[1]]
    local d = m[valid_rows[2]][valid_cols[2]]
    return (a * d) - (b * c)
  else
    local total = 0
    local sign = 1
    for i, col in ipairs(valid_cols) do
      local curr_val = m[valid_rows[1]][col]
      local sub_valid_cols = {}
      for j = 1, #valid_cols do
        if j ~= i then
          table.insert(sub_valid_cols, valid_cols[j])
        end
      end
      local sub_valid_rows = {}
      for j = 2, #valid_rows do
        table.insert(sub_valid_rows, valid_rows[j])
      end
      local sub_determinant = determinant_marginal(m, sub_valid_cols, sub_valid_rows)
      total = (curr_val * sub_determinant) * sign + total
      sign = sign * -1
    end
    return total
  end
end


function determinant(m, sub_length, start_row, valid_cols, valid_rows)
  if not sub_length then
    total_mat_N = #m
  else
    total_mat_N = sub_length
  end

  if not valid_cols then
    valid_cols = {}
    for i = 1, total_mat_N do
      table.insert(valid_cols, i)
    end
  end
  
  if not valid_rows then
    valid_rows = {}
    for i = 1, total_mat_N do
      table.insert(valid_rows, i)
    end
  end

  local N = #valid_cols
  
  if N == 2 then
    local a = m[total_mat_N - 1][valid_cols[1]]
    local b = m[total_mat_N - 1][valid_cols[2]]
    local c = m[total_mat_N][valid_cols[1]]
    local d = m[total_mat_N][valid_cols[2]]
    return (a * d) - (b * c)
  else
    local total = 0
    local sign = 1 -- will alternate between positive and negative
    for i, col in ipairs(valid_cols) do
      local curr_val = m[start_row][col]
      local sub_valid_cols = {}
      for j, sub_col in ipairs(valid_cols) do
        if j ~= i then
          table.insert(sub_valid_cols, sub_col)
        end
      end
      local sub_determinant = determinant(m, total_mat_N, start_row+1, sub_valid_cols, valid_rows)
      total = (curr_val * sub_determinant) * sign + total -- recursive call
      sign = sign * -1
    end
    return total
  end
end


function check_positive_definite(m)
  for N = 2, #m do
    if not determinant(m, N) >= 0 then
      return false
    end
  end
  return true
end


function adjust_posdef_diagonals(m, i, j)
  local current_value = m[i][j]
  if current_value ~= 0 then
    current_sign = current_value / math.abs(current_value)
  else
    current_sign = 1
  end

  local diag_i = m[i][i]
  local diag_j = m[j][j]
  if current_value ^ 2 > diag_i * diag_j then
    current_value = current_sign * ((diag_i * diag_j) ^ 0.5)
    m[i][j] = current_value
    m[j][i] = current_value
  end
end


function get_all_combs(choices)
  local c = {}
  local n = #choices
  
  for i = 1, n do
    for _, comb in ipairs(get_combinations(choices, i)) do
      table.insert(c, comb)
    end
  end
  
  return c
end

function get_combinations(choices, length)
  if length == 1 then
    return map(choices, function(x) return {x} end)
  end
  
  local combs = {}
  for i = 1, #choices do
    local sub_choices = {}
    for j = i+1, #choices do
      table.insert(sub_choices, choices[j])
    end
    
    for _, comb in ipairs(get_combinations(sub_choices, length-1)) do
      table.insert(combs, {choices[i], table.unpack(comb)})
    end
  end
  
  return combs
end

function map(arr, fn)
  local new_arr = {}
  for i, v in ipairs(arr) do
    new_arr[i] = fn(v)
  end
  return new_arr
end

function adjust_positive_definite(m, i, j)
  m_quad = make_quadratic(m)
  current_value = m[i][j]
  if current_value ~= 0 then
    current_sign = current_value / math.abs(current_value)
  else
    current_sign = 1
  end

  -- set this index as an unknown
  m_quad[i][j].b = 1
  m_quad[j][i].b = 1
  m_quad[i][j].c = 0
  m_quad[j][i].c = 0
  starting_length = math.max(math.min(i, j), 2) -- the smallest sub matrix we have to test.  There's a better way to do this, but I'll try this first
  N = #m

  -- set up all combinations of numbers including this one
  combs = {{}}
  for o = 1, N do
    if o ~= i and o ~= j then
      table.insert(combs[1], o)
    end
  end
  for k = 1, N - 1 do
    for _, v in ipairs(combinations(combs[k])) do
      local new_comb = {}
      for _, o in ipairs(v) do
        table.insert(new_comb, o)
      end
      table.insert(new_comb, i)
      table.insert(new_comb, j)
      table.insert(combs, new_comb)
    end
  end

  for _, combination in ipairs(combs) do
    if check_positive_definite(m) then -- the last step solved it
      return true
    end

    if determinant_marginal(m, combination, combination) > 0 then -- this sub determinant is not the problem
      goto continue
    end

    det = determinant_marginal(m_quad, combination, combination)
    root_1, root_2 = det:roots()

    if type(root_1) == "userdata" then
      return false -- no real roots, no solution.  Try another index in the matrix!
    end
    
    -- print(string.format("Proposing roots %f and %f", root_1, root_2))
    determinant_concavity = det.a / math.abs(det.a)
    root_1 = root_1 - determinant_concavity * 0.001
    root_2 = root_2 + determinant_concavity * 0.001 -- Ensure that these are positive

    if math.abs(current_value - root_1) < math.abs(current_value) - root_2 then -- chose the closer root
      current_value = root_1
    else
      current_value = root_2
    end

    m[i][j] = current_value
    m[j][i] = current_value

    ::continue::
  end

  return check_positive_definite(m)
end

function AdaptiveNMatrix:modify(value, i, j)
  if i == j then -- handle diagonal elements
    if value < 0.0001 then
      return
    end
    self.m[i][j] = value
  else -- handle non-diagonal elements
    if i < j then
      i, j = j, i
    end
    index = {i, j}
    table.remove(self.last_touched, index) -- remove old index
    table.insert(self.last_touched, index) -- add new index

    self.m[i][j] = value
    self.m[j][i] = value
    adjust_posdef_diagonals(self.m, i, j)
  end

  while true do
    for _, index_tuple in pairs(self.last_touched) do -- needs to be fixed to not include last index
      res = adjust_positive_definite(self.m, index_tuple[1], index_tuple[2])
      if res then
        return
      end
    end

    -- if still not positive definite, start setting covariances to 0
    for _, index_tuple in pairs(self.last_touched) do
      self.m[index_tuple[1]][index_tuple[2]] = 0
      self.m[index_tuple[2]][index_tuple[1]] = 0
      res = check_positive_definite(self.m)
      if res then
        return
      end
    end
  end
end