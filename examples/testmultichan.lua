local granmodule = {}
granmodule.state = {}

function randrange(m, n)
    return math.random() * (n - m) + m
end

function octfreq(linocts)
    return 2^linocts
end



function granmodule.init()
	
end

function granmodule.generate()
    -- create parameters for a grain and modify state if needed
    rate = 10
    dur = 100
    freq = octfreq(randrange(7, 14))
    amp = 1
    pan = {0.25, 0.5, 0.75, 1}

    return rate, dur, freq, amp, pan
end

function granmodule.update(...)

end

return granmodule