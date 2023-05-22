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
    post("Running init method")
    post(package.path)
    mymod.myfunc();
    -- setup initial values for the state at the start
end

function granmodule.generate()
    --post("new grain");
    -- create parameters for a grain and modify state if needed
    rate = granmodule.state.rate
    dur = 100
    freq = octfreq(randrange(7, 14))
    amp = 1
    pan = 0.5

    return rate, dur, freq, amp, pan
end

function granmodule.update(...)
    -- receives updates from lists sent to the object as args
    granmodule.state.rate = ...
end

return granmodule

