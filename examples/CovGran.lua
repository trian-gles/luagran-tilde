local granmodule = {}
granmodule.state = {}
local matrix = require('matrix')
require 'math'


CARRIERMIN = 4.5
CARRIERMAX = 15

local function box_muller(mu, sigma2) -- should be replaced with ziggurat at some point
	local theta = 2 * math.pi * math.random()
	local sqrt = math.sqrt(-2 * math.log(math.random()))
	return sqrt * math.cos(theta), sqrt * math.sin(theta)
end

local function uniform(min, max)
	return math.random() + math.random(min, max - 1)
end

function granmodule.init()
	granmodule.state.carriermu = 8 
	granmodule.state.carriersig = 0 
	granmodule.state.modfreqmu = 4
	granmodule.state.modfreqsig = 0
	granmodule.state.moddepthmu = 0
	granmodule.state.moddepthsig = 0
	granmodule.state.durmu = 100
	granmodule.state.dursig = 0
	granmodule.state.panhi = 1
	granmodule.state.panlo = 0
	granmodule.state.rate = 10
	
end

local function restrict(min, max, val)
	return math.min(math.max(val, min), max)
end

function granmodule.generate()

	
	
	local pan = math.random
	local amp = 1 --x[1][1] + 0.5
	amp = restrict(0, 1, amp)

	local rate = math.random() + granmodule.state.rate
	rate = restrict(0.1, 200, rate)

	local dur =  4 * 4^x[4][1] -- exponentially scaled
	dur = restrict(0.001, 100, dur)

	local modFreq = 2 ^ (3 * x[2][1] + 9)
	modFreq = restrict(20, 20000, modFreq)

	local modDepth = 2 ^ (3 * x[3][1] + 9)
	modDepth = restrict(20, 20000, modDepth)

	local freq = 2 ^ (4 * x[1][1] + 10) -- exponentially scaled, as frequency is anyways
	freq = restrict(20, 20000, freq)
	if freq == nil then
		post("FREQ NIL")
		freq = 440
	end

	if pan == nil then
		post("PAN NIL")
		pan = 0.5
	end

	if dur == nil then
		post("dur NIL")
		dur = 2
	end
	

    return rate, dur, freq, modFreq, modDepth, amp, pan
end



function granmodule.update(...)
	local carriermu, carriersig, modfreqmu, modfreqsig, moddepthmu, moddepthsig, durmu, dursig, panhi, panlo, rate = ...

	
end

return granmodule