-- basic template for usage



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
    post("Running init method")
    post(package.path)
end

function granmodule.generate()
    -- create parameters for a grain and modify state if needed
    post("new grain")
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

