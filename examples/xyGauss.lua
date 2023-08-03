this.inlets = 5
this.outlets = 1

local mux = 0
local muy = 0
local localx = 1
local localy = 1
local cov = 0

local RESOLUTION = 41;


local outMat = jit.new("jit.matrix", 1, "float32", 41, 41)

function float(f)
	local l = this.last_inlet
	if l == 0 then
		mux = f
	elseif l == 1 then
		muy = -f
	elseif l == 2 then
		varx = f
	elseif l == 3 then
		vary = f
	elseif l == 4 then
		cov = -f
	end
end

function redraw()
	local determinant = varx * vary - cov * cov
	
	local normalizer = math.sqrt(determinant) * 2 * math.pi
	
	local range = (RESOLUTION / 4)
	for i=1,RESOLUTION do 
		for j=1,RESOLUTION do
			local xindex = ((i - range) / range) - mux
			local yindex = ((j - range) / range) - muy
			-- XEX^t
			local extop = xindex * vary - yindex * cov
			local exbottom = yindex * varx - xindex * cov
			
			local xex = xindex * extop + yindex * exbottom
			xex = xex / (varx * vary - cov * cov)
			local val = math.exp(-0.5 * xex) / normalizer
			
			outMat:setcell2d(i-1, j-1, val)
		end
	end
	
	outlet(0, "jit_matrix", outMat.name);
end