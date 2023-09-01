this.inlets = 3

mat1 = jit.matrix("position")

function box_muller(mu, sigma2) -- should be replaced with ziggurat at some point
	local theta = 2 * math.pi * math.random()
	local root = math.sqrt(-2 * math.log(math.random()))
	return root * math.cos(theta) * sigma2, root * math.sin(theta) * sigma2
end


local period = 235
local omega = 2 * math.pi * (1 / period)

local r = 0.995
local phi2 = - (r^2)
local phi1 = 2 * r * math.cos(omega)

local sig2_0 = 1
local sig2 = sig2_0 * (1 - phi2) / ((1 + phi2) * (1 - phi1 - phi2) * (1 + phi1 - phi2))
local sig = math.sqrt(sig2)

local ylast = 0
local ylast2 = 0

local curr_i = 0
local curr_j = 0

local curr_angle = 0

local twopi = math.pi * 2


function setR(newR)
	r = newR
	phi2 = - (r^2)
	phi1 = 2 * r * math.cos(omega)
	sig2_0 = 1
	sig2 = sig2_0 * (1 - phi2) / ((1 + phi2) * (1 - phi1 - phi2) * (1 + phi1 - phi2))
	sig = math.sqrt(sig2)
end

function setSig2_0(newsig)
	sig2_0 = newsig
	sig2 = sig2_0 * (1 - phi2) / ((1 + phi2) * (1 - phi1 - phi2) * (1 + phi1 - phi2))
	sig = math.sqrt(sig2)
end

function setPeriod(newP)
	period = newP
	omega = 2 * math.pi * (1 / period)
	setR(r)
end

setR(0.9999)

setPeriod(250)

function float(v)
	if (this.last_inlet == 1) then
		setR(math.pow(1.002, -v))
	elseif (this.last_inlet == 2) then
		setSig2_0(v)
	else
		setPeriod(v)
	end
end

function apply()
	
	for _=1,1500 do
		local noise, _ = box_muller(0, sig2_0)
		local mod = phi1 * ylast + phi2 * ylast2 + noise
		if tostring(mod) == tostring(-(0/0)) then
			print(ylast)
		end
		
		mod = math.min(mod, 5 * sig)
		mod = math.max(mod, -5 * sig)
		local norm_mod = mod / sig
		
		local x = norm_mod * math.cos(curr_angle)
		
		local y = norm_mod * math.sin(curr_angle)
		
		curr_angle = curr_angle + omega
		while curr_angle > twopi do
			curr_angle = curr_angle - twopi
		end
		
		ylast2 = ylast
		ylast = mod
		
		
		mat1:setcell(curr_i, curr_j, "val", x/2, y/2)
		curr_i = curr_i + 1
	
		if (curr_i == 250) then
			curr_i = 0
			curr_j = curr_j + 1
		
			if (curr_j == 250) then
				curr_j = 0
			end 
		end
	
	end
	
end