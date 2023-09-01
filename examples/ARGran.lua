require 'CircularBuffer'
require 'math'

local granmodule = {}
granmodule.state = {}

local function box_muller(mu, sigma2) -- should be replaced with ziggurat at some point
	local theta = 2 * math.pi * math.random()
	local root = math.sqrt(-2 * math.log(math.random()))
	return root * math.cos(theta) * sigma2, root * math.sin(theta) * sigma2
end

function granmodule.init()
	
	local phi2 = 0

	local phi1 = 0
	granmodule.state.ar = {phi1, phi2}
	local sig2 = (1 - phi2) / ((1 + phi2) * (1 - phi1 - phi2) * (1 + phi1 - phi2))
	
	granmodule.state.mean = 11
	granmodule.state.spread = 0.7
	granmodule.state.sigma2 = 1
	granmodule.state.normalize = 1
	
	granmodule.state.normalize = sig2^0.5
	
	granmodule.state.dur = 2
	granmodule.state.rateBase = 0.2
	
    -- setup initial values for the state at the start
	granmodule.state.y = CircularBuffer:new(#granmodule.state.ar)
end

function granmodule.generate()
	
	-- compute our autoregressive terms
	local auto_reg = 0
	for i, v in ipairs(granmodule.state.ar) do
		local relative_index = -1 * (i-1)
		auto_reg = auto_reg + v * granmodule.state.y:get(relative_index)
	end
	
	
	
	-- compute error and store
	local err = box_muller(0, granmodule.state.sigma2)
	
	-- compute y and store
	local y = err + auto_reg
	
	granmodule.state.neg1 = y
	
	granmodule.state.y:push(y)
	
	local y_scaled = y * granmodule.state.spread / granmodule.state.normalize + granmodule.state.mean
	--post(octfreq(y_scaled))
	
    -- create parameters for a grain and modify state if needed
    rate = math.random() * granmodule.state.rateBase + granmodule.state.rateBase
    dur = granmodule.state.dur

	freq = math.min(math.max(octfreq(y_scaled), 20), 20000)
    amp = 1
    pan = math.random()
    return rate, dur, freq, amp, pan
end

function octfreq(linocts)
    return 2^linocts
end

function granmodule.update(...)
    local noise, period, sigma2, mean, dur, rate = ...
	granmodule.state.sigma2 = sigma2
	noise = 1.002 ^ (-noise)
	local phi2 = - (noise^2)
	local phi1 = 2 * noise * math.cos((1 / period) * 2 * 3.1415926)
	local sig2 = (1 - phi2) / ((1 + phi2) * (1 - phi1 - phi2) * (1 + phi1 - phi2))
	granmodule.state.mean = mean
	granmodule.state.dur = dur
	granmodule.state.ar[1] = phi1
	granmodule.state.ar[2] = phi2
	granmodule.state.rateBase = rate
	--post(tostring(phi1))
	--post(tostring(phi2))
	
	granmodule.state.normalize = sig2^0.5
end

return granmodule