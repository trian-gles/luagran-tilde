-- basic template for usage

local npan = require('npan')

local granmodule = {}
granmodule.state = {}

function randrange(m, n)
    return math.random() * (n - m) + m
end

function octfreq(linocts)
    return 2^linocts
end



function granmodule.init()
    granmodule.state.rate = 10
	
	
	granmodule.state.distance = 1
	granmodule.state.anglemin = 0
	granmodule.state.anglemax = 360
	
	npan.setspeakers()
end

function granmodule.generate()
    -- create parameters for a grain and modify state if needed
    rate = 10
    dur = 100
    freq = octfreq(randrange(7, 14))
    amp = 1
	angle = random.randrange(granmodule.state.anglemin, granmodule.state.anglemax)
    pan = npan.getamplitudes(granmodule.state.distance, granmodule.state.angle)

    return rate, dur, freq, amp, pan
end

function granmodule.update(...)
    -- receives updates from lists sent to the object as args
    granmodule.state.rate = ...
end

return granmodule
