local Config = require("Config")
local utf8 = require("utf8")

local FONT_SIZE = 32
local HEADER_FONT_SIZE = 46
local FOOTER_FONT_SIZE = 28
local bgImagePath = "assets/images/bg.png"
local DIRECTORY_LISTS = "assets/data/iptvlists"
local FILE_PATH = "assets/data/iptvlists.txt"
local LOG_FILE = "assets/data/applog.txt"
local LOG_MPV = "assets/data/mpv.txt"
local BOOKMARK_FILE, HISTORY_FILE = "assets/data/iptvlists/BOOKMARKS.m3u", "assets/data/iptvlists/HISTORY.m3u"
local pageSize = 14
local activeIndex, currentPage, activeIndexChannels, currentPageChannels = 1, 1, 1, 1
local totalItems, totalItemsChannels = 0, 0
local pagesNames, pagesChannels, strings, currentIptvList = {}, {}, {}, {}
local isChannelListVisible, isOnlineMode = false, true
local prevActiveIndex, prevPage
local prevActiveIndexChannel, prevPageChannel
local globalIndex, globalIndexChannel = 1
local prePlayMode,playStreamMode  = false, false
local timer, delay = 0, 3
local errorStream, errorStreamText = false, ''
local headerFont, mainFont, footerFont, mode, bgImage,prePlayModeHeader, prePlayModeUrlText
local statusCode = nil

local lineY = 0
local animationStartTime = 0
local animationDuration = 0.9
local isAnimating = false

local thread
local channel

function log(message)
    if Config.LOG_SHOW_CONSOLE then print(message) end
    if Config.LOG_SAVE_FILE then os.execute('echo "' .. message .. '" >> ' .. LOG_FILE) end
end

function addBookmark()
    if Config.USE_BOOKMARKS then
        local str = "\n#EXTINF:-1,".. prePlayModeHeader .. "\n" .. prePlayModeUrlText
        os.execute('echo "' .. str .. '" >> ' .. BOOKMARK_FILE)
    end
end

function addHistory()
    if Config.SAVE_HISTORY and prePlayModeHeader and prePlayModeUrlText  then
        local str = "\n#EXTINF:-1," .. prePlayModeHeader .. "\n" .. prePlayModeUrlText
        os.execute('echo "' .. str .. '" >> ' .. HISTORY_FILE)
    end
end

function loadIptvList()
    strings = {}
    totalItems = 0
    for line in love.filesystem.lines(FILE_PATH) do
        local name, url = line:match("^(.-)::(.+)$")
        if name and url then
            totalItems = totalItems + 1
            table.insert(strings, {name = name, url = url})
        end
    end
    calculatePagesNames()  -- Переучитываем страницы
    log("Loaded " .. totalItems .. " names from " .. FILE_PATH)
end

function loadOfflineList()
    strings = {}
    totalItems = 0
    local files = love.filesystem.getDirectoryItems(DIRECTORY_LISTS)
    if #files == 0 then
        log("No files found in the " .. DIRECTORY_LISTS ..  " folder.")  -- Логируем, если нет файлов в папке
    else
        for _, file in ipairs(files) do
            local name = trim(file, 30)
            totalItems = totalItems + 1
            table.insert(strings, {name = name, url = file})
        end
    end
    calculatePagesNames()
    log("Loaded " .. totalItems .. " names from " .. DIRECTORY_LISTS .. " folder.")
end

function calculatePagesNames()
    pagesNames = {}
    for i = 1, math.ceil(totalItems / pageSize) do
        local startIdx = (i - 1) * pageSize + 1
        local endIdx = math.min(i * pageSize, totalItems)
        local page = {}
        for j = startIdx, endIdx do
            table.insert(page, {index = j, name = strings[j].name})
        end
        pagesNames[i] = page
    end
    log("Calculated " .. #pagesNames .. " pages for names.")
end

function loadChannelsList(source)
    log("Loading offline IPTV list from: " .. source)
    log("Mode is online: " ..  tostring(isOnlineMode))

    currentIptvList = {}

    if not isOnlineMode then
        local success, file = pcall(love.filesystem.read, DIRECTORY_LISTS .. "/" .. source)

        log("Attempting to read file: " .. DIRECTORY_LISTS .. "/" .. source)

        if success then
            for line in file:gmatch("([^\n]*)\n?") do
                if line:match("^#EXTINF:") then
                    local name = line:match("^#EXTINF:.-,(.+)")
                    if name then
                        table.insert(currentIptvList, {name = name})
                    end
                elseif line:match("^http") then
                    currentIptvList[#currentIptvList].url = line
                end
            end
            totalItemsChannels = #currentIptvList
            calculatePagesChannels()
            log("Loaded " .. totalItemsChannels .. " channels from file.")
        else
            log("Failed to load channels from file: " .. source)
        end
    else
        local url = source:match("::(.+)")
        if url then
            local wgetCommand = "wget -qO- '" .. url .. "'"
            local handle = io.popen(wgetCommand)
            local result = handle:read("*a")
            handle:close()

            if result and #result > 0 then
                for line in result:gmatch("([^\n]*)\n?") do
                    if line:match("^#EXTINF:") then
                        local name = line:match("^#EXTINF:.-,(.+)")
                        if name then
                            table.insert(currentIptvList, {name = name})
                        end
                    elseif line:match("^http") then
                        currentIptvList[#currentIptvList].url = line
                    end
                end
                totalItemsChannels = #currentIptvList
                calculatePagesChannels()
                log("Loaded " .. totalItemsChannels .. " channels from URL.")
            else
                log("Failed to fetch channels. URL might be inaccessible.")
                showError("Error loading channels.")
            end
        else
            log("Invalid URL format: " .. source)
            showError("Invalid URL format.")
        end
    end
end

function showError(message)
    love.graphics.setColor(1, 0, 0)
    love.graphics.setFont(mainFont)
    local textWidth = love.graphics.getFont():getWidth(message)
    love.graphics.print(message, (love.graphics.getWidth() - textWidth) / 2, love.graphics.getHeight() / 2)
    log("Error: " .. message)
end

function loadChannels(url)
    log("Loading online IPTV list from URL: " .. url)
    loadChannelsList(url)
end

function calculatePagesChannels()
    pagesChannels = {}
    for i = 1, math.ceil(totalItemsChannels / pageSize) do
        local startIdx = (i - 1) * pageSize + 1
        local endIdx = math.min(i * pageSize, totalItemsChannels)
        local page = {}
        for j = startIdx, endIdx do
            table.insert(page, {index = j, name = currentIptvList[j].name})
        end
        pagesChannels[i] = page
    end
end

function trim(text, maxLength)
    local byteLength = 0
    local truncatedText = ""

    for i = 1, utf8.len(text) do
        local char = string.sub(text, utf8.offset(text, i), utf8.offset(text, i + 1) - 1)
        byteLength = byteLength + utf8.len(char)

        if byteLength > maxLength then
            truncatedText = truncatedText .. "..."
            break
        end
        truncatedText = truncatedText .. char
    end

    return truncatedText
end

function drawPaginator()
    love.graphics.setColor(0.5, 0.5, 0.5)
    love.graphics.setFont(headerFont)

    if isOnlineMode then
        mode = " (Online)"
    else
        mode = " (Offline)"
    end

    local headerText = "IPTV Viewer" .. mode
    local textWidth = love.graphics.getFont():getWidth(headerText)
    love.graphics.print(headerText, (love.graphics.getWidth() - textWidth) / 2, 20)

    love.graphics.setFont(mainFont)
    local page = pagesNames[currentPage]
    if not page then return end
    for i, item in ipairs(page) do
        local color = i == activeIndex and {1, 0.5, 0} or {1, 1, 1}
        local displayNumber = (currentPage - 1) * pageSize + i
        love.graphics.setColor(color)
        love.graphics.print(displayNumber .. ". " .. trim(item.name, 32), 50, 50 + (i - 1) * FONT_SIZE + 40)
    end
end

function drawChannelsList()
    love.graphics.setColor(0.5, 0.5, 0.5)
    love.graphics.setFont(headerFont)
    local selectedName = strings[globalIndex].name
    local headerText = trim(selectedName, 25)
    local textWidth = love.graphics.getFont():getWidth(headerText)
    love.graphics.print(headerText, (love.graphics.getWidth() - textWidth) / 2, 20)

    love.graphics.setFont(mainFont)
    local page = pagesChannels[currentPageChannels]
    if not page then return end
    for i, item in ipairs(page) do
        local color = i == activeIndexChannels and {1, 0.5, 0} or {1, 1, 1}
        local displayNumber = (currentPageChannels - 1) * pageSize + i
        love.graphics.setColor(color)
        love.graphics.print(displayNumber .. ". " .. trim(item.name, 33), 50, 50 + (i - 1) * FONT_SIZE + 40)
    end
end

function love.keypressed(key)
    log("Key pressed: " .. key)

    if key == "down" then
        if not isChannelListVisible then
            activeIndex = activeIndex + 1
            if activeIndex > #pagesNames[currentPage] then
                activeIndex = 1
                currentPage = currentPage + 1
                if currentPage > #pagesNames then
                    currentPage = 1
                end
            end
             log("Active Index (Names List): " .. activeIndex .. " (Page: " .. currentPage .. ")")
        else
            activeIndexChannels = activeIndexChannels + 1
            if activeIndexChannels > #pagesChannels[currentPageChannels] then
                activeIndexChannels = 1
                currentPageChannels = currentPageChannels + 1
                if currentPageChannels > #pagesChannels then
                    currentPageChannels = 1
                end
            end

            prePlayModeHeader = currentIptvList[activeIndexChannels].name
            prePlayModeUrlText = currentIptvList[activeIndexChannels].url
            log("Active Index (Channels List): " .. activeIndexChannels .. " (Page: " .. currentPageChannels .. ")")
        end
    elseif key == "up" then
        if not isChannelListVisible then
            activeIndex = activeIndex - 1
            if activeIndex < 1 then
                currentPage = currentPage - 1
                if currentPage < 1 then
                    currentPage = #pagesNames
                end
                activeIndex = #pagesNames[currentPage]
            end
            log("Active Index (Names List): " .. activeIndex .. " (Page: " .. currentPage .. ")")
        else
            activeIndexChannels = activeIndexChannels - 1
            if activeIndexChannels < 1 then
                currentPageChannels = currentPageChannels - 1
                if currentPageChannels < 1 then
                    currentPageChannels = #pagesChannels
                end
                activeIndexChannels = #pagesChannels[currentPageChannels]
            end
            prePlayModeHeader = currentIptvList[activeIndexChannels].name
            prePlayModeUrlText = currentIptvList[activeIndexChannels].url
            log("Active Index (Channels List): " .. activeIndexChannels .. " (Page: " .. currentPageChannels .. ")")
        end
    elseif key == "right" then
        if not isChannelListVisible then
            currentPage = currentPage + 1
            if currentPage > #pagesNames then
                currentPage = 1
            end
            activeIndex = 1
            log("Active Index (Names List): " .. activeIndex .. " (Page: " .. currentPage .. ")")
        else
            currentPageChannels = currentPageChannels + 1
            if currentPageChannels > #pagesChannels then
                currentPageChannels = 1
            end
            activeIndexChannels = 1

            prePlayModeHeader = currentIptvList[activeIndexChannels].name
            prePlayModeUrlText = currentIptvList[activeIndexChannels].url
            log("Active Index (Channels List): " .. activeIndexChannels .. " (Page: " .. currentPageChannels .. ")")
        end
    elseif key == "left" then
        if not isChannelListVisible then
            currentPage = currentPage - 1
            if currentPage < 1 then
                currentPage = #pagesNames
            end
            activeIndex = 1
            log("Active Index (Names List): " .. activeIndex .. " (Page: " .. currentPage .. ")")
        else
            currentPageChannels = currentPageChannels - 1
            if currentPageChannels < 1 then
                currentPageChannels = #pagesChannels
            end
            activeIndexChannels = 1

            prePlayModeHeader = currentIptvList[activeIndexChannels].name
            prePlayModeUrlText = currentIptvList[activeIndexChannels].url
            log("Active Index (Channels List): " .. activeIndexChannels .. " (Page: " .. currentPageChannels .. ")")
        end
    elseif key == "return" then
        if playStreamMode then
            log("Clear " .. LOG_MPV)
            os.execute("echo ' ' >> " .. LOG_MPV)
        end

        if not isChannelListVisible then
            globalIndex = (currentPage - 1) * pageSize + activeIndex
            local selectedName = strings[globalIndex].name
            local source = strings[globalIndex].name
            log("Selected num string: " .. globalIndex)
            log("Selected name: " .. selectedName)

            if not isOnlineMode then
                source = source
            else
                source = source .. "::" .. strings[globalIndex].url
            end
            log("Selected source: " .. source .. " mode: " .. mode)
            loadChannelsList(source)

            isChannelListVisible = true
            prevActiveIndex = activeIndex
            prevPage = currentPage
        elseif isChannelListVisible and not prePlayMode then
            addHistory()

            prevActiveIndexChannel = activeIndexChannels
            prevPageChannel = currentPageChannels
            globalIndexChannel = (currentPageChannels - 1) * pageSize + activeIndexChannels
            local selectedName = currentIptvList[globalIndexChannel].name
            local source = currentIptvList[globalIndexChannel].name
            log("currentPageChannels: " .. currentPageChannels .. " pageSize: " .. pageSize .. " activeIndexChannels: " .. activeIndexChannels)
            log("Selected num string: " .. globalIndexChannel)
            log("Selected name: " .. selectedName)

            prePlayModeHeader = currentIptvList[activeIndexChannels].name
            prePlayModeUrlText = currentIptvList[activeIndexChannels].url

            prePlayModeHeader = source

            if not isOnlineMode then
                source = source
            else
                source = source .. "::" .. strings[globalIndex].url
            end

            prePlayModeUrlText = currentIptvList[globalIndexChannel].url

            errorStream = false
            errorStreamText = ''

            if not prePlayModeUrlText then
                        errorStream = true
                        errorStreamText = 'No valid URL'
                        prePlayModeUrlText = "URL without http/https protocol"
            end

            log("Selected source: " .. prePlayModeUrlText .. " mode: " .. mode)
            prePlayMode = true
            log("Start check URL: " .. prePlayModeUrlText)

            local isAvailable, statusCode = checkURLAvailability(prePlayModeUrlText)

            if not isAvailable then
                if not statusCode then statusCode = 'unknown' end
                log("Failed open URL: " .. prePlayModeUrlText .. " code: " .. statusCode)
                errorStream = true
                errorStreamText = "Failed open stream URL, status code: " .. statusCode
            else
               log("Success URL: " .. prePlayModeUrlText)
               playStreamMode = true
               log("playStreamMode is on")
               log("channel: " .. prePlayModeHeader)
               log("command: mpv --log-file=" .. LOG_MPV .. "  " .. prePlayModeUrlText .. " &")
               log("playStreamMode is on. MPV started")

               local cmd = os.execute("/usr/bin/mpv --log-file=" .. LOG_MPV .. " " .. prePlayModeUrlText .. " &")
               channel:push(cmd)
           end
        end
    elseif key == "x" then
        startAnimation()
        log("prePlayMode: " .. tostring(prePlayMode))
        log("playStreamMode: " .. tostring(playStreamMode))

        if not prePlayMode then
            if isChannelListVisible  then
                isChannelListVisible = false
                --calculatePagesNames()
                activeIndex = prevActiveIndex
                currentPage = prevPage

                currentPageChannels = 1
                activeIndexChannels = 1
                log("Returning to Names List from Channels List page: " .. currentPage .. " index: " .. prevActiveIndex)
                log("Channels list page and index reset to 1.")
            end
        elseif prePlayMode then
            prePlayMode = false
            playStreamMode = false
            isChannelListVisible = true

            if not errorStream then
                log("pkill -9 mpv")
                log("playStreamMode is off. MPV closed")
                --os.execute("pkill -2 mpv")
                channel:push("pkill -9 mpv")
                startAnimation()
            end
            isChannelListVisible = true

            currentPageChannels = prevPageChannel
            activeIndexChannels = prevActiveIndexChannel
            --calculatePagesChannels()
            log("Returning to Channels List page: " .. activeIndexChannels .. " index: " .. prevActiveIndexChannel)
        end

    elseif key == "space" then
        if not isChannelListVisible then
            isOnlineMode = not isOnlineMode
            if isOnlineMode then
                loadIptvList()
                log("Switched to Online Mode.")
            else
                loadOfflineList()
                log("Switched to Offline Mode.")
            end
            currentPage = 1
            activeIndex = 1
        end
    elseif key == "z" then
        if isChannelListVisible then
            log("Save/unsave bookmark")
            addBookmark()
        end
     elseif key == "c" then
        if not playStreamMode then
            startAnimation()
        end
    end
end

function checkURLAvailability(url)
    log("Check: curl --head --silent --max-time 2 '" .. url .. "'")
    local command = "curl --head --silent --max-time 2 '" .. url .. "'"
    local file = io.popen(command)
    local result = file:read("*a")
    file:close()
    statusCode = result:match("HTTP/%d%.%d (%d%d%d)")

    if not statusCode then statusCode = nil end

    if statusCode and statusCode ~= "200" or not statusCode then
        return false, statusCode
    else
        return true, statusCode
    end
end

function drawErrorStream()
    love.graphics.setColor(0.5, 0.5, 0.5)
    love.graphics.setFont(footerFont)
    local text = trim(errorStreamText, 50)
    love.graphics.print(text, (love.graphics.getWidth() - love.graphics.getFont():getWidth(text)) / 2, love.graphics.getHeight() - 40)
end

-- Love2D Load function
function love.load()
    bgImage = love.graphics.newImage(bgImagePath)
    headerFont = love.graphics.newFont(Config.FONT_PATH, HEADER_FONT_SIZE)
    mainFont = love.graphics.newFont(Config.FONT_PATH, FONT_SIZE)
    footerFont = love.graphics.newFont(Config.FONT_PATH, FOOTER_FONT_SIZE)
    loadIptvList()
    calculatePagesNames()

    local script = [[
        local channel = love.thread.getChannel("mpv_channel")
        while true do
            local command = channel:demand() -- Wait for a command
            if command then
                os.execute(command) -- Execute the command
            end
        end
    ]]

    love.filesystem.write("mpv_thread.lua", script)

    if love.filesystem.getInfo("mpv_thread.lua") then
        print("mpv_thread.lua successfully created!")

        channel = love.thread.getChannel("mpv_channel")
        thread = love.thread.newThread("mpv_thread.lua")
        thread:start()
    else
        print("Error: Failed to create mpv_thread.lua!")
    end
end

function drawPrePlayMode()
    local headerText = trim(prePlayModeHeader, 25)
    love.graphics.setFont(headerFont)
    love.graphics.setColor(0.5, 0.5, 0.5)
    local width, height = love.graphics.getDimensions()
    local textWidth = love.graphics.getFont():getWidth(headerText)
    love.graphics.print(headerText, (width - textWidth) / 2, 20)
    love.graphics.setFont(mainFont)
    love.graphics.setColor(1, 1, 1)
    local url = trim(prePlayModeUrlText, 60)
    love.graphics.printf("Playing stream: " .. url, 0, love.graphics.getHeight()  / 2 - FONT_SIZE / 2, love.graphics.getWidth() , "center")
end

function drawBgImage()
    local windowWidth = love.graphics.getWidth()
    local windowHeight = love.graphics.getHeight()
    local imageWidth = bgImage:getWidth()
    local imageHeight = bgImage:getHeight()
    local x = windowWidth - imageWidth
    local y = windowHeight - imageHeight
    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(bgImage, x-40, y-40)
end

function love.draw()
    local channelData = ""

    love.graphics.clear(44/255, 52/255, 58/255) --bg

    drawBgImage()

    if not isChannelListVisible then
        drawPaginator()
    else
        if not prePlayMode  then
            channelData = "/" .. currentPageChannels
            drawChannelsList()
        elseif prePlayMode then
            drawPrePlayMode()
        end
    end

    if not prePlayMode and not playStreamMode then
        local bottomMargin = 40
        love.graphics.setColor(0.5, 0.5, 0.5)  -- Gray color
        love.graphics.setFont(footerFont)
        local footerText = "Page: " .. currentPage  .. channelData
        local footerWidth = love.graphics.getFont():getWidth(footerText)
        love.graphics.print(footerText, (love.graphics.getWidth() - footerWidth) / 2, love.graphics.getHeight() - bottomMargin)
    end

    if prePlayMode and errorStream then
        drawErrorStream()
    end

    love.graphics.setColor(1, 0.5, 0, 0.3)
    love.graphics.setLineWidth(5)
    love.graphics.line(0, lineY, love.graphics.getWidth(), lineY)
end

function startAnimation()
    animationStartTime = love.timer.getTime()
    isAnimating = true
end

function love.update(dt)
    if isAnimating then
        local elapsedTime = love.timer.getTime() - animationStartTime

        if elapsedTime < animationDuration then
            lineY = (elapsedTime / animationDuration) * love.graphics.getHeight()
        else
            lineY = 0
            isAnimating = false
        end
    end
end