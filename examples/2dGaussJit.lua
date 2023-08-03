this.inlets = 5


local mat1 = jit.matrix("position")
local mux = 0
local muy = 0
local varx = 1
local vary = 1
local cov = 0

local l11 = math.sqrt(varx)
local l21 = cov / l11
local l12 = 0
local l22 = math.sqrt(vary - l21^2)

local curr_i = 0
local curr_j = 0


function box_muller(mu, sigma2) -- should be replaced with ziggurat at some point
	local theta = 2 * math.pi * math.random()
	local root = math.sqrt(-2 * math.log(math.random()))
	return root * math.cos(theta) * sigma2, root * math.sin(theta) * sigma2
end

function sample()
	local u1, u2 = box_muller(0, 1)
	local x = l11 * u1 + mux
	local y = l21 * u1 + l22 * u2 + muy
	return x, y
end

function float(f)
	local l = this.last_inlet
	if l == 0 then
		mux = f
	elseif l == 1 then
		muy = -f
	elseif l == 2 then
		varx = f
		l11 = math.sqrt(varx)
		l21 = cov / l11
		l22 = math.sqrt(vary - l21^2)
	elseif l == 3 then
		vary = f
		l22 = math.sqrt(vary - l21^2)
	elseif l == 4 then
		cov = f
		l21 = cov / l11
		l22 = math.sqrt(vary - l21^2)
	end
end

function apply()
	for _=1,1500 do
		local x, y = sample()
		mat1:setcell(curr_i, curr_j, "val", x / 10, y / 10)
		curr_i = curr_i + 1
		
		if (curr_i == 50) then
			curr_i = 0
			curr_j = curr_j + 1
		
			if (curr_j == 50) then
				curr_j = 0
			end 
		end
	end
end

