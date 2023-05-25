local granmodule = {}
granmodule.state = {}
local matrix = require('matrix')
require 'math'

local function box_muller(mu, sigma2) -- should be replaced with ziggurat at some point
	local theta = 2 * math.pi * math.random()
	local sqrt = math.sqrt(-2 * math.log(math.random()))
	return sqrt * math.cos(theta), sqrt * math.sin(theta)
end

function granmodule.init()
	granmodule.state.mu = matrix:new({0, 0, 0})
	granmodule.state.cov = matrix:new(3, "I")

	granmodule.state.L = matrix.transpose(matrix:new(3, "I"))

	granmodule.state.e = matrix:new(3, "I") * 0.0001

	granmodule.state.u = matrix:new({0, 0, 0})
end

local function restrict(min, max, val)
	return math.min(math.max(val, min), max)
end

function granmodule.generate()

	local x = granmodule.multivariate_sample(granmodule.state.mu, granmodule.state.L, granmodule.state.u)
	for i=1,3 do
		if x[i][1] == nil then
			x[i][1] = 0
			post("Value nil!")
		end
	end
	
	local amp = 1
	local pan = x[1][1] + 0.5
	pan = restrict(0, 1, pan)

	local rate = math.random() * 20
	rate = restrict(0.1, 200, rate)

	local dur = 4 * 4^x[2][1] -- exponentially scaled
	dur = restrict(0.001, 100, dur)

	local freq = 2 ^ (4 * x[3][1] + 10) -- exponentially scaled, as frequency is anyways
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

    return rate, dur, freq, amp, pan
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
	local m = matrix:new({1, 2, 3})
	local L = matrix:new(3, "I")
	local u = matrix:new(3, 1, 0)
	return granmodule.multivariate_sample(m, L, u)
end

function granmodule.update(...)
	local mux, muy, muz, sigx, sigy, sigz, sigxy, sigxz, sigyz = ...

	granmodule.state.mu[1][1] = mux
	granmodule.state.mu[2][1] = muy
	granmodule.state.mu[3][1] = muz
	granmodule.state.cov = matrix:new(
		{
			{sigx, sigxy, sigxz}, 
			{sigxy, sigy, sigyz}, 
			{sigxz, sigyz, sigz}
		}
	)
	granmodule.state.L = matrix.cholesky(granmodule.state.cov + granmodule.state.e)
end

return granmodule