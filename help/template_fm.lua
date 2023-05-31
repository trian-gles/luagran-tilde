-- basic template for usage



local granmodule = {}
granmodule.state = {}
local mymod = require("mymod")

function randrange(m, n)
    return math.random() * (n - m) + m
end

function octfreq(linocts)
    return 2^linocts
end

function granmodule.init()
    granmodule.state.rate = 10
    granmodule.state.modfreq = 1000
    mymod.myfunc();
    -- setup initial values for the state at the start
end

function granmodule.generate()
    -- create parameters for a grain and modify state if needed
    rate = granmodule.state.rate
    dur = 100
    freq = octfreq(randrange(10, 11))
    modfreq = granmodule.state.modfreq //octfreq(randrange(5, 10))
    moddepth = octfreq(randrange(9, 10))
    amp = 1
    pan = 0.5

    return rate, dur, freq, modfreq, moddepth, amp, pan
end

function granmodule.update(...)
    -- receives updates from lists sent to the object as args
    granmodule.state.rate, granmodule.state.modfreq = ...
end

return granmodule

