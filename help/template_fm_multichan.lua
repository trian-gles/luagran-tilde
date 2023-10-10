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
	granmodule.state.modfreq = 1000
end

function granmodule.generate()
-- create parameters for a grain and modify state if needed
    rate = 10
    dur = 100
    freq = octfreq(randrange(8, 11))
    modfreq = granmodule.state.modfreq //octfreq(randrange(5, 10))
    moddepth = octfreq(randrange(9, 10))
    amp = 1
    pan = {0.1, 0.5, 1.}

    return rate, dur, freq, modfreq, moddepth, amp, pan
end

function granmodule.update(...)
end

return granmodule

