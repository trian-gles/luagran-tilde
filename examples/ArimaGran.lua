require 'CircularBuffer'


local granmodule = {}
granmodule.state = {}

function box_mueller(mu, sigma2)

end

function granmodule.init()
	granmodule.state.ar = [1]
	granmodule.state.ma = [1]
	granmodule.state.const = 0
	granmodule.state.sigma2 = 1
	
    -- setup initial values for the state at the start
	granmodule.state.y = CircularBuffer:new(#granmodule.state.ar)
	grandmodule.state.errors = CircularBuffer:new(#granmodule.state.ma)
end

function granmodule.generate()
 	-- compute our moving average terms    
	mov_avg = 0
	for i, v in ipairs(granmodule.state.ma) do
		relative_index = -1 * (i-1)
		mov_avg = mov_avg + v * grandmodule.state.errors:get(relative_index)
	end
	
	-- compute our autoregressive terms
	auto_reg = 0
	for i, v in ipairs(granmodule.state.ar) do
		relative_index = -1 * (i-1)
		mov_avg = mov_avg + v * grandmodule.state.y:get(relative_index)
	end
	
	-- compute error and store
	err = box_mueller(0, granmodule.state.sigma2)
	granmodule.state.error:push(err)
	
	-- compute y and store
	y = granmodule.state.const + err + mov_avg + auto_reg
	granmodule.state.y:push(y)
	
	
    -- create parameters for a grain and modify state if needed
    rate = .01
    dur = 0.01
    freq = octfreq(y)
    amp = 1
    pan = 0.5

    return rate, dur, freq, amp, pan
end

function octfreq(linocts)
    return 2^linocts
end

function granmodule.update(...)
    -- receives updates from lists sent to the object as args
end

return granmodule