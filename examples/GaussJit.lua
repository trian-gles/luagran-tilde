this.inlets = 5
this.outlets = 2

local mux = 0
local muy = 0
local varx = 1
local vary = 1
local cov = 0

RESOLUTION = 21

outMat = jit.new("jit.matrix", 1, "float32", 21, 21)

function loadbang()
	
end

function float(f)
	if this.last_inlet == 0 then
		mux = f
	elseif this.last_inlet == 1 then
		muy = f
	elseif this.last_inlet == 2 then
		varx = f
	elseif this.last_inlet == 3 then
		vary = f
	elseif this.last_inlet == 4 then
		cov = f
	end
	make_positive_definite()
	
	outlet(1, cov)
	print(cov)
	bang()
end

function make_positive_definite()
	varx = math.max(0.001, varx)
	vary = math.max(0.001, vary)
	
	if cov * cov + 0.0001 > varx * vary then
		local sign = cov / math.abs(cov)
		cov = sign * (math.sqrt(varx * vary) - 0.0001)
	end
end

function bang()
	local determinant = varx * vary - cov * cov
	local normalizer = math.sqrt(determinant) * 2 * math.pi
	
	local range = RESOLUTION / 2
	for i = 0, RESOLUTION do
		for j = 0, RESOLUTION do
			local xindex = ((i - range) / range) - mux
			local yindex = ((j - range) / range) - muy
			
			-- XEX^t
			local extop = xindex * vary - yindex * cov
			local exbottom = yindex * varx - xindex * cov
			
			local xex = xindex * extop + yindex * exbottom
			xex = xex / (varx * vary - cov * cov)
			local val = math.exp(-0.5 * xex) / normalizer
			
			outMat:setcell2d(i, j, val)
		end
	end
	
	outlet(0, "jit_matrix", outMat.name)
end

function mvGaussPDF()
	
end
