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
	granmodule.state.cov = matrix:new(
		{
			{1, 0, 0}, 
			{0, 1, 0}, 
			{0, 0, 1}
		}
	)

	granmodule.state.L = matrix:new(
		{
			{0, 0, 1}, 
			{0, 1, 0}, 
			{1, 0, 0}
		}
	)

	granmodule.state.u = matrix:new({0, 0, 0})
end

local function scale(a, b, val)
	return a * val + b
end

local function restrict(min, max, val)
	return math.min(math.max(val, min), max)
end

function granmodule.generate()

	local x = granmodule.multivariate_sample(granmodule.state.mu, granmodule.state.L, granmodule.state.u)
	local amp = 1
	local pan = math.random()

	local rate = scale(3, 10.1, x[1][1])
	rate = restrict(0.1, 200, rate)

	local dur = scale(3, 15, x[2][1])
	dur = restrict(0.01, 40, dur)

	local freq = 2 ^ scale(4, 10, x[3][1])
	freq = restrict(20, 20000, freq)

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
	post(matrix.tostring(granmodule.state.mu))
	granmodule.state.cov = matrix:new(
		{
			{sigx, sigxy, sigxz}, 
			{sigxy, sigy, sigyz}, 
			{sigxz, sigyz, sigz}
		}
	)
	post(matrix.tostring(granmodule.state.cov))
	granmodule.state.L = matrix.transpose(matrix.cholesky(granmodule.state.cov))
end

return granmodule