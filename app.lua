function table:deepCopy()
       if type(self) ~= 'table' then return self end
       local res = setmetatable({}, getmetatable(self))
       for k, v in pairs(self) do res[table.deepCopy(k)] = table.deepCopy(v) end
       return res
end

local function matchCriteria(fn, criteria)
    local isArray = false
    local arrayMatch = false
    for k, v in pairs(criteria) do
        if math.type(k) ~= nil then
            isArray = true
            if fn.id == v then
                arrayMatch = true
                break
            end
        else
            if k == 'id' then
                if fn.id ~= v then return false end
            end
            if k == 'type' then
                if fn.type:match('^' .. v .. '$') == nil then return false end
            end
            if fn.meta[k] == nil then return false end
            if fn.meta[k]:match('^' .. v .. '$') == nil then return false end
        end
    end
    if isArray then return arrayMatch end
    return true
end

function findFunction(criteria)
    if math.type(criteria) ~= nil then
        for _, fn in ipairs(functions) do
            if fn.id == criteria then return fn end
        end
    elseif type(criteria) == 'table' then
        for _, fn in ipairs(functions) do
            if matchCriteria(fn, criteria) then return fn end
        end
    end
    return nil
end


function findFunctions(criteria)
    local res = {}
    if type(criteria) == 'table' then
        for _, fn in ipairs(functions) do
            if matchCriteria(fn, criteria) then table.insert(res, fn) end
        end
    end
    return res
end

local topicArmed = {}
local topicFunction = {}

function handleTrigger(topic, payload, retained)
	local data = json:decode(payload)
	if cfg.overOrUnder == "under" then
		if data.value < cfg.threshold then
			topicArmed[topic] = true
		else
			topicArmed[topic] = false
		end
	elseif cfg.overOrUnder == "over" then
		if data.value > cfg.threshold then
			topicArmed[topic] = true
		else
			topicArmed[topic] = false
		end
	end
	sendNotificationIfArmed(topic, data.value, cfg.overOrUnder)
end

function onStart()
	for i, fun in ipairs(cfg.trigger_functions) do
		local triggerFunction = findFunction(fun)
		local triggerTopic = triggerFunction.meta.topic_read

		-- Keep mapping between topic and function. In the case
		-- of two functions haveing the same topic the last one
		-- in this loop will be used.
		topicFunction[triggerTopic] = triggerFunction

		mq:sub(triggerTopic, 0)
		mq:bind(triggerTopic, handleTrigger)
	end
end

function sendNotificationIfArmed(topic, value, action)
	local armed = false
	local firing = ""
	local unit = ""
	for top, a in pairs(topicArmed) do
		if a == true then
			armed = true
			func = topicFunction[top]
		end
	end

	if armed and cfg.notification_output ~= nil then
		local payloadData = {
			value = value,
			action = action,
			firing = func.meta.name,
			unit = func.meta.unit,
			note = func.meta.note,
			-- Instead of the above, the whole function could be added.
			-- Not sure if the user wants to expose the whole function.
			--
			-- func = func, -- Find no way to use resrved word function
			treshold = cfg.threshold
		}
		lynx.notify(cfg.notification_output, payloadData)
	end
end
