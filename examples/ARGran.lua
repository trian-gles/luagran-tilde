require 'CircularBuffer'
require 'math'

local granmodule = {}
granmodule.state = {}

local function box_muller(mu, sigma2) -- should be replaced with ziggurat at some point
	local theta = 2 * math.pi * math.random()
	local sqrt = math.sqrt(-2 * math.log(math.random()))
	return sqrt * math.cos(theta), sqrt * math.sin(theta)
end

function granmodule.init()
	granmodule.state.ar = {0, 0}
	
	granmodule.state.mean = 9
	granmodule.state.spread = 1
	granmodule.state.sigma2 = 1
	granmodule.state.normalize = 1
	
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
	granmodule.state.y:push(y)
	
	local y_scaled = y * granmodule.state.spread / granmodule.state.normalize + granmodule.state.mean
	
	
    -- create parameters for a grain and modify state if needed
    rate = 0.02
    dur = math.random() + 1
    freq = octfreq(y_scaled)
    amp = 1
    pan = 0.5
    return rate, dur, freq, amp, pan
end

function octfreq(linocts)
    return 2^linocts
end

function granmodule.update(...)
    local noise, period = ...
	
	noise = 1.2 ^ (-(noise))
	local phi2 = - (noise^2)
	local phi1 = 2 * noise * math.cos((1 / period) * 2 * 3.1415926)
	local sig2 = (1 - phi2) / ((1 + phi2) * (1 - phi1 - phi2) * (1 + phi1 - phi2))
	
	granmodule.state.ar[1] = phi1
	granmodule.state.ar[2] = phi2
	
	granmodule.state.normalize = sig2^0.5
end

return granmodule