local granmodule = {}
granmodule.state = {}
local matrix = require('matrix')
require 'math'

local N = 4

local function box_muller(mu, sigma2) -- should be replaced with ziggurat at some point
	local theta = 2 * math.pi * math.random()
	local sqrt = math.sqrt(-2 * math.log(math.random()))
	return sqrt * math.cos(theta), sqrt * math.sin(theta)
end

function granmodule.init()
	granmodule.state.mu = matrix:new({0, 0, 0, 0})
	granmodule.state.cov = matrix:new(4, "I")

	granmodule.state.L = matrix.transpose(matrix:new(4, "I"))

	granmodule.state.e = matrix:new(4, "I") * 0.0001

	granmodule.state.u = matrix:new({0, 0, 0, 0})

	granmodule.state.rate = 10
	
end

local function restrict(min, max, val)
	return math.min(math.max(val, min), max)
end

function granmodule.generate()

	local x = granmodule.multivariate_sample(granmodule.state.mu, granmodule.state.L, granmodule.state.u)
	for i=1,N do
		if x[i][1] == nil then
			x[i][1] = 0
			post("Value nil!")
		end
	end
	
	local pan = math.random()
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

function granmodule.multivariate_sample(m, L, u)
	local n = #m
	for i=1,math.ceil(n/2) do
		local z1, z2 = box_muller(0, 1)
		u[i * 2 - 1][1] = z1

		if (i*2 <= n) then
			u[i * 2][1] = z2 -- could be more efficient but whatevs
		end
	end
	return m + matrix.mul(L, u)
end

function granmodule.test()
	local m = matrix:new({1, 2, 3, 4})
	print(#m)
	local L = matrix:new(4, "I")
	local u = matrix:new(4, 1, 0)
	return granmodule.multivariate_sample(m, L, u)
end

function granmodule.update(...)
	local mux, muy, muz, muq, sigx, sigy, sigz, sigq, sigxy, sigxz, sigxq, sigyz, sigyq, sigzq, rate = ...

	granmodule.state.mu[1][1] = mux
	granmodule.state.mu[2][1] = muy
	granmodule.state.mu[3][1] = muq
	granmodule.state.mu[4][1] = muz
	granmodule.state.cov = matrix:new(
		{
			{sigx, sigxy, sigxz, sigxq}, 
			{sigxy, sigy, sigyz, sigyq}, 
			{sigxz, sigyz, sigz, sigzq},
			{sigxq, sigyq, sigzq, sigq}
		}
	)
	granmodule.state.L = matrix.cholesky(granmodule.state.cov + granmodule.state.e)
	granmodule.state.rate = rate
end

return granmodule