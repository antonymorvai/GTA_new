-- UUID v4 für Event-IDs und Korrelations-IDs.
-- math.random reicht hier: IDs müssen eindeutig sein, nicht kryptographisch sicher.

math.randomseed(os.time() + (os.clock() * 1000000))

function GenerateUuid()
    local template = 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'
    return (template:gsub('[xy]', function(c)
        local v = (c == 'x') and math.random(0, 15) or math.random(8, 11)
        return string.format('%x', v)
    end))
end
