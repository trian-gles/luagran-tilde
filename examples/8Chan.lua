-- basic template for usage

local npan = require('npan')

local granmodule = {}
granmodule.state = {}

local function randrange(m, n)
    return math.random() * (n - m) + m
end

local function octfreq(linocts)
    return 2^linocts
end


CARRIERMIN = 20
CARRIERMAX = 20000

MODFREQMIN = 0.5
MODFREQMAX = 20000

MODDEPTHMIN = 20
MODDEPTHMAX = 20000


function granmodule.init()
    granmodule.state.rate = 10
	
	
	granmodule.state.distance = 1
	granmodule.state.anglemin = 0
	granmodule.state.anglemax = 360
	
	npan.set_speakers({45, 1,   -- front left
      -45, 1,   -- front right
       90, 1,   -- side left
      -90, 1,   -- side right
      135, 1,   -- rear left
     -135, 1,   -- rear right rear
        0, 1,   -- front center
      180, 1 	-- rear center
	  })
end

function granmodule.generate()
    -- create parameters for a grain and modify state if needed
    local rate = 10
    local dur = 100
    local freq = octfreq(randrange(7, 14))
    local moddepth = octfreq(randrange(7, 11))
    local modfreq = octfreq(randrange(2, 14))
    local amp = 1
	local angle = randrange(granmodule.state.anglemin, granmodule.state.anglemax)
    local pan = npan.get_gains(angle, granmodule.state.distance)

    return rate, dur, freq, modfreq, moddepth, amp, pan
end

function granmodule.update(...)
    -- receives updates from lists sent to the object as args
    granmodule.state.rate = ...
end

return granmodule

