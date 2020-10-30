local _G, _ = _G or getfenv()

local LFT = CreateFrame("Frame")
local me = UnitName('player')
local addonVer = '0.0.2.2'
local LFT_ADDON_CHANNEL = 'LFT'
--local LFTTypeDropDown = CreateFrame('Frame', 'LFTTypeDropDown', UIParent, 'UIDropDownMenuTemplate')
local groupsFormedThisSession = 0

LFT.showedUpdateNotification = false
LFT.maxDungeonsInQueue = 5
LFT.groupSizeMax = 5
LFT.class = ''
LFT.channel = 'LFT'
LFT.channelIndex = 0
LFT.level = UnitLevel('player')
LFT.findingGroup = false
LFT.findingMore = false
LFT:RegisterEvent("ADDON_LOADED")
LFT:RegisterEvent("PLAYER_ENTERING_WORLD")
LFT:RegisterEvent("PARTY_MEMBERS_CHANGED")
LFT:RegisterEvent("PARTY_LEADER_CHANGED")
LFT:RegisterEvent("PLAYER_LEVEL_UP")
LFT.availableDungeons = {}
LFT.group = {}
LFT.oneGroupFull = false
LFT.groupFullCode = ''
LFT.acceptNextInvite = false
LFT.onlyAcceptFrom = ''
LFT.queueStartTime = 0
LFT.averageWaitTime = 0
LFT.types = {
    [1] = 'Suggested Dungeons',
    --    [2] = 'Random Dungeon',
    [3] = 'All Available Dungeons'
}
LFT.maxDungeonsList = 11
LFT.minimapFrames = {}
LFT.myRandomTime = 0
LFT.random_min = 0
LFT.random_max = 10

LFT.RESET_TIME = 0
LFT.TANK_TIME = 2
LFT.HEALER_TIME = 5
LFT.DAMAGE_TIME = 8
LFT.FULLCHECK_TIME = 26 --time when checkGroupFull is called, has to wait for goingWith messages
LFT.TIME_MARGIN = 30

LFT.foundGroup = false
LFT.inGroup = false
LFT.isLeader = false
LFT.LFMGroup = {}
LFT.LFMDungeonCode = ''
LFT.currentGroupSize = 0

LFT.objectivesFrames = {}

LFT.classColors = {
    ["warrior"] = { r = 0.78, g = 0.61, b = 0.43, c = "|cffc79c6e" },
    ["mage"] = { r = 0.41, g = 0.8, b = 0.94, c = "|cff69ccf0" },
    ["rogue"] = { r = 1, g = 0.96, b = 0.41, c = "|cfffff569" },
    ["druid"] = { r = 1, g = 0.49, b = 0.04, c = "|cffff7d0a" },
    ["hunter"] = { r = 0.67, g = 0.83, b = 0.45, c = "|cffabd473" },
    ["shaman"] = { r = 0.14, g = 0.35, b = 1.0, c = "|cff0070de" },
    ["priest"] = { r = 1, g = 1, b = 1, c = "|cffffffff" },
    ["warlock"] = { r = 0.58, g = 0.51, b = 0.79, c = "|cff9482c9" },
    ["paladin"] = { r = 0.96, g = 0.55, b = 0.73, c = "|cfff58cba" }
}

LFT.channelOwner = false

local LFTTime = CreateFrame("Frame")
LFTTime:Hide()
LFTTime.second = -1
LFTTime.spamWhenAvailable = false

LFTTime:SetScript("OnShow", function()
    this.startTime = GetTime()
    if LFTTime.second == -1 then
        LFTTime.second = 0
    end

    if LFTTime.spamWhenAvailable and LFT.channelOwner then
        SendChatMessage('timeIs:0', "CHANNEL", DEFAULT_CHAT_FRAME.editBox.languageID, GetChannelName(LFT.channel))
        LFTTime.spamWhenAvailable = false
    end
end)

LFTTime:SetScript("OnUpdate", function()
    local plus = 1 --seconds
    local gt = GetTime() * 1000
    local st = (this.startTime + plus) * 1000
    if gt >= st then
        this.startTime = GetTime()
        if LFTTime.second + 1 == 60 then
            LFTTime.second = 0
            -- re send every minute
            if LFT.channelOwner then
                SendChatMessage('timeIs:' .. LFTTime.second, "CHANNEL", DEFAULT_CHAT_FRAME.editBox.languageID, GetChannelName(LFT.channel))
            end
            return true
        end
        LFTTime.second = LFTTime.second + 1
        if LFTTime.second == LFT.TIME_MARGIN and LFT.channelOwner then
            SendChatMessage('timeIs:' .. LFTTime.second, "CHANNEL", DEFAULT_CHAT_FRAME.editBox.languageID, GetChannelName(LFT.channel))
        end
    end
end)

local LFTServerTime = CreateFrame("Frame")
LFTServerTime:Hide()

LFTServerTime:SetScript("OnShow", function()
    this.startTime = GetTime()
    local _, minute = GetGameTime()
    LFTServerTime.serverMinute = minute
end)

LFTServerTime:SetScript("OnUpdate", function()
    local plus = 1 --seconds
    local gt = GetTime() * 1000
    local st = (this.startTime + plus) * 1000
    if gt >= st then
        this.startTime = GetTime()

        local _, minute = GetGameTime()
        --lfdebug(' server minute = ' .. minute)
        if minute ~= LFTServerTime.serverMinute then
            --lfdebug('server minute changed !  ' .. minute)
            --lfdebug('server minute changed !  ' .. minute)
            --lfdebug('server minute changed !  ' .. minute)
            --lfdebug('server minute changed !  ' .. minute)
            --lfdebug('server minute changed !  ' .. minute)
            LFTTime:Show()
            LFTServerTime:Hide()
        end

    end
end)

local LFTGoingWithPicker = CreateFrame("Frame")
LFTGoingWithPicker:Hide()
LFTGoingWithPicker.candidate = ''
LFTGoingWithPicker.priority = 0
LFTGoingWithPicker.dungeon = ''

LFTGoingWithPicker:SetScript("OnShow", function()
    this.startTime = GetTime()
end)

LFTGoingWithPicker:SetScript("OnHide", function()
end)

LFTGoingWithPicker:SetScript("OnUpdate", function()
    local plus = 1 --seconds
    local gt = GetTime() * 1000
    local st = (this.startTime + plus) * 1000
    if gt >= st then

        SendChatMessage('goingWith:' .. LFTGoingWithPicker.candidate .. ':' .. LFTGoingWithPicker.dungeon .. ':' .. LFT_ROLE, "CHANNEL", DEFAULT_CHAT_FRAME.editBox.languageID, GetChannelName(LFT.channel))
        LFT.foundGroup = true

        LFTGoingWithPicker.candidate = ''
        LFTGoingWithPicker.priority = 0
        LFTGoingWithPicker.dungeon = ''
        LFTGoingWithPicker:Hide()
    end
end)

local COLOR_RED = '|cffff222a'
local COLOR_ORANGE = '|cffff8000'
local COLOR_GREEN = '|cff1fba1f'
local COLOR_HUNTER = '|cffabd473'
local COLOR_YELLOW = '|cffffff00'
local COLOR_WHITE = '|cffffffff'
local COLOR_DISABLED = '|cff888888'
local COLOR_TANK = '|cff0070de'
local COLOR_HEALER = COLOR_GREEN
local COLOR_DAMAGE = COLOR_RED

-- dungeon complete animation
local LFTDungeonComplete = CreateFrame("Frame")
LFTDungeonComplete:Hide()
LFTDungeonComplete.frameIndex = 0
LFTDungeonComplete.dungeonInProgress = false

LFTDungeonComplete:SetScript("OnShow", function()
    this.startTime = GetTime()
    LFTDungeonComplete.frameIndex = 0
    _G['LFTDungeonComplete']:SetAlpha(0)
    _G['LFTDungeonComplete']:Show()
end)

LFTDungeonComplete:SetScript("OnHide", function()
    --    this.startTime = GetTime()
end)

LFTDungeonComplete:SetScript("OnUpdate", function()
    local plus = 0.03 --seconds
    local gt = GetTime() * 1000
    local st = (this.startTime + plus) * 1000
    if gt >= st then
        this.startTime = GetTime()
        local frame = ''
        if LFTDungeonComplete.frameIndex < 10 then
            frame = frame .. '0' .. LFTDungeonComplete.frameIndex
        else
            frame = frame .. LFTDungeonComplete.frameIndex
        end
        _G['LFTDungeonCompleteFrame']:SetTexture('Interface\\addons\\LFT\\images\\dungeon_complete\\dungeon_complete_' .. frame)
        if LFTDungeonComplete.frameIndex < 35 then
            _G['LFTDungeonComplete']:SetAlpha(_G['LFTDungeonComplete']:GetAlpha() + 0.03)
        end
        if LFTDungeonComplete.frameIndex > 119 then
            _G['LFTDungeonComplete']:SetAlpha(_G['LFTDungeonComplete']:GetAlpha() - 0.03)
        end
        if LFTDungeonComplete.frameIndex >= 150 then
            _G['LFTDungeonComplete']:Hide()
            _G['LFTDungeonStatus']:Hide()
            _G['LFTDungeonCompleteFrame']:SetTexture('Interface\\addons\\LFT\\images\\dungeon_complete\\dungeon_complete_00')
            LFTDungeonComplete:Hide()

            local index = 0
            for _, boss in next, LFT.bosses[LFT.groupFullCode] do
                index = index + 1
                LFT.objectivesFrames[index]:Hide()
                LFT.objectivesFrames[index].completed = false
                _G["LFTObjective" .. index .. 'ObjectiveComplete']:Hide()
                _G["LFTObjective" .. index .. 'ObjectivePending']:Hide()
                _G["LFTObjective" .. index .. 'Objective']:SetText('')
            end
            --LFT.objectivesFrames = {}
        end
        LFTDungeonComplete.frameIndex = LFTDungeonComplete.frameIndex + 1
    end
end)

-- objectives
local LFTObjectives = CreateFrame("Frame")
LFTObjectives:Hide()
LFTObjectives:RegisterEvent("CHAT_MSG_COMBAT_HOSTILE_DEATH")
LFTObjectives.collapsed = false
LFTObjectives.closedByUser = false
LFTObjectives.lastObjective = 0
LFTObjectives.leftOffset = -80
LFTObjectives.frameIndex = 0
LFTObjectives.objectivesComplete = 0

function close_lft_objectives()
    LFTObjectives.closedByUser = true
    --lfdebug('LFTObjectives.closedByUser = true')
    _G['LFTDungeonStatus']:Hide()
end

-- swoooooooosh

LFTObjectives:SetScript("OnShow", function()
    LFTObjectives.leftOffset = -80
    LFTObjectives.frameIndex = 0
    this.startTime = GetTime()
end)

LFTObjectives:SetScript("OnHide", function()
    --    this.startTime = GetTime()
end)

LFTObjectives:SetScript("OnUpdate", function()
    local plus = 0.001 --seconds
    local gt = GetTime() * 1000
    local st = (this.startTime + plus) * 1000
    if gt >= st then
        this.startTime = GetTime()
        LFTObjectives.frameIndex = LFTObjectives.frameIndex + 1
        LFTObjectives.leftOffset = LFTObjectives.leftOffset + 5
        _G["LFTObjective" .. LFTObjectives.lastObjective .. 'Swoosh']:SetPoint("TOPLEFT", _G["LFTObjective" .. LFTObjectives.lastObjective], "TOPLEFT", LFTObjectives.leftOffset, 5)
        if LFTObjectives.frameIndex <= 10 then
            _G["LFTObjective" .. LFTObjectives.lastObjective .. 'Swoosh']:SetAlpha(LFTObjectives.frameIndex / 10)
        end
        if LFTObjectives.frameIndex >= 30 then
            _G["LFTObjective" .. LFTObjectives.lastObjective .. 'Swoosh']:SetAlpha(1 - LFTObjectives.frameIndex / 40)
        end
        if LFTObjectives.leftOffset >= 120 then
            LFTObjectives:Hide()
            _G["LFTObjective" .. LFTObjectives.lastObjective .. 'Swoosh']:SetAlpha(0)
        end
    end
end)

LFTObjectives:SetScript("OnEvent", function()
    if event == "CHAT_MSG_COMBAT_HOSTILE_DEATH" then
        local creatureDied = arg1
        --lfdebug(creatureDied)
        --        if LFT.dungeons[zoneText] then
        if LFT.bosses[LFT.groupFullCode] then
            for _, boss in next, LFT.bosses[LFT.groupFullCode] do
                --creatureDied == 'You have slain ' .. boss .. '!'
                if creatureDied == boss .. ' dies.' then
                    LFTObjectives.objectiveComplete(boss)
                    return true
                end
            end
        end
        --        end
    end
end)

-- fill available dungeons delayer because UnitLevel(member who just joined) returns 0
local LFTFillAvailableDungeonsDelay = CreateFrame("Frame")
LFTFillAvailableDungeonsDelay.offset = 0
LFTFillAvailableDungeonsDelay.triggers = 0
LFTFillAvailableDungeonsDelay.queueAfterIfPossible = false
LFTFillAvailableDungeonsDelay:Hide()
LFTFillAvailableDungeonsDelay:SetScript("OnShow", function()
    this.startTime = GetTime()
end)

LFTFillAvailableDungeonsDelay:SetScript("OnHide", function()
    if LFTFillAvailableDungeonsDelay.triggers < 10 then
        LFT.fillAvailableDungeons(LFTFillAvailableDungeonsDelay.offset, LFTFillAvailableDungeonsDelay.queueAfterIfPossible)
        LFTFillAvailableDungeonsDelay.triggers = LFTFillAvailableDungeonsDelay.triggers + 1
    else
        lferror('Error occurred at LFTFillAvailableDungeonsDelay triggers = 10. Please report this to Xerron/Er.')
    end
end)
LFTFillAvailableDungeonsDelay:SetScript("OnUpdate", function()
    local plus = 0.1 --seconds
    local gt = GetTime() * 1000
    local st = (this.startTime + plus) * 1000
    if gt >= st then
        LFTFillAvailableDungeonsDelay:Hide()
    end
end)

-- channel join delayer

local LFTChannelJoinDelay = CreateFrame("Frame")
LFTChannelJoinDelay:Hide()

LFTChannelJoinDelay:SetScript("OnShow", function()
    this.startTime = GetTime()
end)

LFTChannelJoinDelay:SetScript("OnHide", function()
    LFT.checkLFTChannel()
end)

LFTChannelJoinDelay:SetScript("OnUpdate", function()
    local plus = 15 --seconds
    local gt = GetTime() * 1000
    local st = (this.startTime + plus) * 1000
    if gt >= st then
        LFTChannelJoinDelay:Hide()
    end
end)

local LFTQueue = CreateFrame("Frame")
LFTQueue:Hide()

-- group invite timer

local LFTInvite = CreateFrame("Frame")
LFTInvite:Hide()
LFTInvite.inviteIndex = 1
LFTInvite:SetScript("OnShow", function()
    this.startTime = GetTime()
    LFTInvite.inviteIndex = 1
    local awesomeButton = _G['LFTGroupReadyAwesome']
    awesomeButton:SetText('Waiting Players (' .. LFT.groupSizeMax - GetNumPartyMembers() - 1 .. ')')
    awesomeButton:Disable()
end)

LFTInvite:SetScript("OnUpdate", function()
    local plus = 0.5 --seconds
    local gt = GetTime() * 1000
    local st = (this.startTime + plus) * 1000
    if gt >= st then
        this.startTime = GetTime()

        LFTInvite.inviteIndex = this.inviteIndex + 1

        if LFTInvite.inviteIndex == 2 then
            if LFT.group[LFT.groupFullCode].healer ~= '' then
                InviteByName(LFT.group[LFT.groupFullCode].healer)
            end
        end
        if LFTInvite.inviteIndex == 3 then
            if LFT.group[LFT.groupFullCode].damage1 ~= '' then
                InviteByName(LFT.group[LFT.groupFullCode].damage1)
            end
        end
        if LFTInvite.inviteIndex == 4 and LFTInvite.inviteIndex <= LFT.groupSizeMax then
            if LFT.group[LFT.groupFullCode].damage2 ~= '' then
                InviteByName(LFT.group[LFT.groupFullCode].damage2)
            end
        end
        if LFTInvite.inviteIndex == 5 and LFTInvite.inviteIndex <= LFT.groupSizeMax then
            if LFT.group[LFT.groupFullCode].damage3 ~= '' then
                InviteByName(LFT.group[LFT.groupFullCode].damage3)
                LFTInvite:Hide()
                LFTInvite.inviteIndex = 1
            end
        end
    end
end)

-- role check timer

local LFTRoleCheck = CreateFrame("Frame")
LFTRoleCheck:Hide()

LFTRoleCheck:SetScript("OnShow", function()
    this.startTime = GetTime()
end)

LFTRoleCheck:SetScript("OnHide", function()
    --lfdebug('lftrolecheck onhide')
    if LFT.isLeader then
        if LFT.findingMore then
        else
            lfprint('A member of your group has not confirmed his role.')
            PlaySoundFile("Interface\\Addons\\LFT\\sound\\lfg_denied.ogg")
            _G['findMoreButton']:Enable()
        end
    end
    _G['LFTRoleCheck']:Hide()
end)

LFTRoleCheck:SetScript("OnUpdate", function()
    local plus = 25 --seconds
    if LFT.isLeader then
        plus = plus + 2 --leader waits 2 more second to hide
    end
    local gt = GetTime() * 1000
    local st = (this.startTime + plus) * 1000
    if gt >= st then
        --lfdebug(' lftrolecheck > ' .. plus)
        LFTRoleCheck:Hide()

        if LFT.isLeader then
            lfprint('A member of your group does not have the ' .. COLOR_HUNTER .. '[LFT] ' .. COLOR_WHITE ..
                    'addon. Looking for more is disabled. (Type ' .. COLOR_HUNTER .. '/lft advertise ' .. COLOR_WHITE .. ' to send them a link)')
            _G['findMoreButton']:Disable()

        else
            declineRole()
        end
    end
end)

-- who counter timer

local LFTWhoCounter = CreateFrame("Frame")
LFTWhoCounter:Hide()
LFTWhoCounter.people = 0
LFTWhoCounter.listening = false
LFTWhoCounter:SetScript("OnShow", function()
    this.startTime = GetTime()
    LFTWhoCounter.people = 0
    LFTWhoCounter.listening = true
    lfprint('Checking people online with the addon (5secs)...')
end)

LFTWhoCounter:SetScript("OnHide", function()
    LFTWhoCounter.people = LFTWhoCounter.people + 1 -- + me
    lfprint('Found ' .. COLOR_GREEN .. LFTWhoCounter.people .. COLOR_WHITE .. ' online using LFT addon.')
    LFTWhoCounter.listening = false
end)

LFTWhoCounter:SetScript("OnUpdate", function()
    local plus = 5 --seconds
    local gt = GetTime() * 1000
    local st = (this.startTime + plus) * 1000
    if gt >= st then
        LFTWhoCounter:Hide()
    end
end)

--closes the group ready frame when someone leaves queue from the button
local LFTGroupReadyFrameCloser = CreateFrame("Frame")
LFTGroupReadyFrameCloser:Hide()
LFTGroupReadyFrameCloser.response = ''
LFTGroupReadyFrameCloser:SetScript("OnShow", function()
    this.startTime = GetTime()
end)

LFTGroupReadyFrameCloser:SetScript("OnHide", function()
end)
LFTGroupReadyFrameCloser:SetScript("OnUpdate", function()
    local plus = 30 --time after i click leave queue, afk
    local plus2 = 35 --time after i close the window
    local gt = GetTime() * 1000
    local st = (this.startTime + plus) * 1000
    local st2 = (this.startTime + plus2) * 1000
    if gt >= st then
        if LFTGroupReadyFrameCloser.response == '' then
            sayNotReady()
        end
    end
    if gt >= st2 then
        _G['LFTReadyStatus']:Hide()
        lfprint('A member of your group has not accepted the invitation. You are rejoining the queue.')
        if LFT.isLeader then
            leaveQueue('LFTGroupReadyFrameCloser isleader = true')
            local offset = FauxScrollFrame_GetOffset(_G['DungeonListScrollFrame']);
            LFT.fillAvailableDungeons(offset, 'queueAgain' == 'queueAgain')
        end
        if LFTGroupReadyFrameCloser.response == 'notReady' then
            --doesnt trigger for leader, cause it leaves queue
            --which resets response to ''
            LeaveParty()
            LFTGroupReadyFrameCloser.response = ''
        end
        LFTGroupReadyFrameCloser:Hide()
    end
end)

-- communication

local LFTComms = CreateFrame("Frame")
LFTComms:Hide()
LFTComms:RegisterEvent("CHAT_MSG_CHANNEL")
LFTComms:RegisterEvent("CHAT_MSG_WHISPER")
LFTComms:RegisterEvent("CHAT_MSG_CHANNEL_LEAVE")
LFTComms:RegisterEvent("PARTY_INVITE_REQUEST")
LFTComms:RegisterEvent("CHAT_MSG_ADDON")
LFTComms:RegisterEvent("CHAT_MSG_CHANNEL_NOTICE")
LFTComms:RegisterEvent("CHAT_MSG_CHANNEL_NOTICE_USER")
--"CHAT_MSG_CHANNEL_NOTICE_USER"
--Category: Communication
--
--Fired when something changes in the channel like moderation enabled, user is kicked, announcements changed and so on. CHAT_*_NOTICE in GlobalStrings.lua has a full list of available types.
--
--arg1
--type ("ANNOUNCEMENTS_OFF", "ANNOUNCEMENTS_ON", "BANNED", "OWNER_CHANGED", "INVALID_NAME", "INVITE", "MODERATION_OFF", "MODERATION_ON", "MUTED", "NOT_MEMBER", "NOT_MODERATED", "SET_MODERATOR", "UNSET_MODERATOR" )
--arg2
--If arg5 has a value then this is the user affected ( eg: "Player Foo has been kicked by Bar" ), if arg5 has no value then it's the person who caused the event ( eg: "Channel Moderation has been enabled by Bar" )
--arg4
--Channel name with number
--arg5
--Player that caused the event (eg "Player Foo has been kicked by Bar" )

LFTComms:SetScript("OnEvent", function()
    if event then
        if event == 'CHAT_MSG_CHANNEL_NOTICE_USER' then
            if arg1 == 'OWNER_CHANGED' then
                LFT.channelOwner = arg2 == me
                if LFT.channelOwner then
                    lfdebug('changed iam channel owner')
                else
                    lfdebug('changed i am not channel owner')
                end
            end
            if arg1 == 'CHANNEL_OWNER' then
                LFT.channelOwner = arg2 == me
                if LFT.channelOwner then
                    lfdebug(' iam channel owner')
                else
                    lfdebug('i am not channel owner')
                end
            end
            if arg1 == 'PLAYER_ALREADY_MEMBER' then
                -- probably only used when reloadui
                if not LFT.channelOwner then
                    SendChatMessage("needTime:", "CHANNEL", DEFAULT_CHAT_FRAME.editBox.languageID, GetChannelName(LFT.channel))
                end
                LFT.checkLFTChannel()
            end
            --lfdebug('CHAT_MSG_CHANNEL_NOTICE_USER')
            --lfdebug(arg1) --event, we need CHANNEL_OWNER
            --lfdebug(arg2) -- owner name
            --lfdebug(arg3) -- blank
            --lfdebug(arg4) -- 6.Lft
            --lfdebug(arg5) -- blank
        end
        if event == 'CHAT_MSG_CHANNEL_NOTICE' then
            if arg9 == LFT.channel and arg1 == 'YOU_JOINED' then
                LFT.channelIndex = arg8
                DisplayChannelOwner(LFT.channel)
                if not LFT.channelOwner then
                    SendChatMessage("needTime:", "CHANNEL", DEFAULT_CHAT_FRAME.editBox.languageID, GetChannelName(LFT.channel))
                end
            end
        end

        if event == 'CHAT_MSG_ADDON' and arg1 == 'LFT' then
            lfdebug(arg4 .. ' says : ' .. arg2)
            if string.sub(arg2, 1, 11) == 'objectives:' then
                local objEx = string.split(arg2, ':')
                if LFT.groupFullCode ~= objEx[2] then
                    LFT.groupFullCode = objEx[2]
                end

                local objectivesString = string.split(objEx[3], '-')

                if not LFTObjectives.closedByUser and not _G["LFTDungeonStatus"]:IsVisible() then
                    LFT.showDungeonObjectives()
                end

                for stringIndex, s in next, objectivesString do
                    if s then
                        if s == '1' then
                            local index = 0
                            for _, boss in next, LFT.bosses[LFT.groupFullCode] do
                                index = index + 1
                                if index == stringIndex then
                                    LFTObjectives.objectiveComplete(boss, true)
                                end
                            end
                        end
                    end
                end
            end
            if string.sub(arg2, 1, 11) == 'notReadyAs:' then

                PlaySoundFile("Interface\\Addons\\LFT\\sound\\lfg_denied.ogg")

                local readyEx = string.split(arg2, ':')
                local role = readyEx[2]
                if role == 'tank' then
                    _G['LFTReadyStatusReadyTank']:SetTexture('Interface\\addons\\LFT\\images\\readycheck-notready')
                end
                if role == 'healer' then
                    _G['LFTReadyStatusReadyHealer']:SetTexture('Interface\\addons\\LFT\\images\\readycheck-notready')
                end
                if role == 'damage' then
                    if _G['LFTReadyStatusReadyDamage1']:GetTexture() == 'Interface\\addons\\LFT\\images\\readycheck-waiting' then
                        _G['LFTReadyStatusReadyDamage1']:SetTexture('Interface\\addons\\LFT\\images\\readycheck-notready')
                    elseif _G['LFTReadyStatusReadyDamage2']:GetTexture() == 'Interface\\addons\\LFT\\images\\readycheck-waiting' then
                        _G['LFTReadyStatusReadyDamage2']:SetTexture('Interface\\addons\\LFT\\images\\readycheck-notready')
                    elseif _G['LFTReadyStatusReadyDamage3']:GetTexture() == 'Interface\\addons\\LFT\\images\\readycheck-waiting' then
                        _G['LFTReadyStatusReadyDamage3']:SetTexture('Interface\\addons\\LFT\\images\\readycheck-notready')
                    end
                end
            end
            if string.sub(arg2, 1, 8) == 'readyAs:' then
                local readyEx = string.split(arg2, ':')
                local role = readyEx[2]

                if role == 'tank' then
                    _G['LFTReadyStatusReadyTank']:SetTexture('Interface\\addons\\LFT\\images\\readycheck-ready')
                end
                if role == 'healer' then
                    _G['LFTReadyStatusReadyHealer']:SetTexture('Interface\\addons\\LFT\\images\\readycheck-ready')
                end
                if role == 'damage' then
                    if _G['LFTReadyStatusReadyDamage1']:GetTexture() == 'Interface\\addons\\LFT\\images\\readycheck-waiting' then
                        _G['LFTReadyStatusReadyDamage1']:SetTexture('Interface\\addons\\LFT\\images\\readycheck-ready')
                    elseif _G['LFTReadyStatusReadyDamage2']:GetTexture() == 'Interface\\addons\\LFT\\images\\readycheck-waiting' then
                        _G['LFTReadyStatusReadyDamage2']:SetTexture('Interface\\addons\\LFT\\images\\readycheck-ready')
                    elseif _G['LFTReadyStatusReadyDamage3']:GetTexture() == 'Interface\\addons\\LFT\\images\\readycheck-waiting' then
                        _G['LFTReadyStatusReadyDamage3']:SetTexture('Interface\\addons\\LFT\\images\\readycheck-ready')
                    end
                end
                if _G['LFTReadyStatusReadyTank']:GetTexture() == 'Interface\\addons\\LFT\\images\\readycheck-ready' and
                        _G['LFTReadyStatusReadyHealer']:GetTexture() == 'Interface\\addons\\LFT\\images\\readycheck-ready' and
                        _G['LFTReadyStatusReadyDamage1']:GetTexture() == 'Interface\\addons\\LFT\\images\\readycheck-ready' and
                        _G['LFTReadyStatusReadyDamage2']:GetTexture() == 'Interface\\addons\\LFT\\images\\readycheck-ready' and
                        _G['LFTReadyStatusReadyDamage3']:GetTexture() == 'Interface\\addons\\LFT\\images\\readycheck-ready' then
                    _G['LFTReadyStatus']:Hide()
                    LFTGroupReadyFrameCloser:Hide()
                    LFT.showDungeonObjectives()
                    --promote the tank to leader
                    if LFT.isLeader and role == 'tank' and arg4 ~= me then
                        PromoteByName(arg4)
                    end
                end
            end
            if string.sub(arg2, 1, 11) == 'LFTVersion:' and arg4 ~= me then
                if not LFT.showedUpdateNotification then
                    local verEx = string.split(arg2, ':')
                    if LFT.ver(verEx[2]) > LFT.ver(addonVer) then
                        lfprint(COLOR_HUNTER .. 'Looking For Turtles ' .. COLOR_WHITE .. ' - new version available ' ..
                                COLOR_GREEN .. 'v' .. verEx[2] .. COLOR_WHITE .. ' (current version ' ..
                                COLOR_ORANGE .. 'v' .. addonVer .. COLOR_WHITE .. ')')
                        lfprint('Update yours at ' .. COLOR_HUNTER .. 'https://github.com/CosminPOP/LFT')
                        LFT.showedUpdateNotification = true
                    end
                end
            end

            if string.sub(arg2, 1, 11) == 'leaveQueue:' and arg4 ~= me then
                leaveQueue('leaveQueue: addon party')
            end

            if string.sub(arg2, 1, 8) == 'minimap:' then
                if not LFT.isLeader then
                    local miniEx = string.split(arg2, ':')
                    local code = miniEx[2]
                    local tank = tonumber(miniEx[3])
                    local healer = tonumber(miniEx[4])
                    local damage = tonumber(miniEx[5])
                    LFT.group = {} --reset old entries
                    LFT.group[code] = {
                        tank = '',
                        healer = '',
                        damage1 = '',
                        damage2 = '',
                        damage3 = ''
                    }
                    if tank == 1 then
                        LFT.group[code].tank = 'DummyTank'
                    end
                    if healer == 1 then
                        LFT.group[code].healer = 'DummyHealer'
                    end
                    if damage > 0 then
                        LFT.group[code].damage1 = 'DummyDamage1'
                    end
                    if damage > 1 then
                        LFT.group[code].damage2 = 'DummyDamage2'
                    end
                    if damage > 2 then
                        LFT.group[code].damage3 = 'DummyDamage3'
                    end
                end
            end
            if string.sub(arg2, 1, 14) == 'LFMPartyReady:' then

                local queueEx = string.split(arg2, ':')
                local mCode = queueEx[2]
                local objectivesCompleted = queueEx[3]
                local objectivesTotal = queueEx[4]
                LFT.groupFullCode = mCode
                --uncheck everything
                --for i, frame in LFT.availableDungeons do
                _G['Dungeon_' .. LFT.groupFullCode]:SetChecked(false)
                --end
                LFT.findingGroup = false
                LFT.findingMore = false
                local background = ''
                local dungeonName = 'unknown'
                for d, data in next, LFT.dungeons do
                    if data.code == mCode then
                        background = data.background
                        dungeonName = d
                    end
                end
                _G['LFTGroupReadyBackground']:SetTexture('Interface\\addons\\LFT\\images\\background\\ui-lfg-background-' .. background)
                _G['LFTGroupReadyRole']:SetTexture('Interface\\addons\\LFT\\images\\' .. LFT_ROLE .. '2')
                _G['LFTGroupReadyMyRole']:SetText(LFT.ucFirst(LFT_ROLE))
                _G['LFTGroupReadyDungeonName']:SetText(dungeonName)
                _G['LFTGroupReadyObjectivesCompleted']:SetText(objectivesCompleted .. '/' .. objectivesTotal .. ' Bosses Defeated')
                LFT.readyStatusReset()
                _G['LFTGroupReady']:Show()
                LFTGroupReadyFrameCloser:Show()

                PlaySoundFile("Interface\\Addons\\LFT\\sound\\levelup2.ogg")
                LFT.fixMainButton()
                _G['LFTMain']:Hide()
                LFTQueue:Hide()

                if LFT.isLeader then
                    SendChatMessage("[LFT]:lft_group_formed:" .. mCode .. ":" .. time() - LFT.queueStartTime, "CHANNEL", DEFAULT_CHAT_FRAME.editBox.languageID, GetChannelName(LFT.channel))
                end
            end
            if string.sub(arg2, 1, 10) == 'weInQueue:' then
                local queueEx = string.split(arg2, ':')
                LFT.weInQueue(queueEx[2])
            end
            if string.sub(arg2, 1, 10) == 'roleCheck:' then
                if arg4 ~= me then
                    PlaySoundFile("Interface\\AddOns\\LFT\\sound\\lfg_rolecheck.ogg")
                end
                lfprint('A role check has been initiated. Your group will be queued when all members have selected a role.')
                UIErrorsFrame:AddMessage("|cff69ccf0[LFT] |cffffff00A role check has been initiated. Your group will be queued when all members have selected a role.")

                local argEx = string.split(arg2, ':')
                local mCode = argEx[2]
                LFT.LFMDungeonCode = mCode
                LFT.resetGroup()

                if LFT.isLeader then
                    lfdebug('is leader')
                    if LFT_ROLE == 'tank' then
                        LFT.LFMGroup.tank = me
                        SendAddonMessage(LFT_ADDON_CHANNEL, "acceptRole:" .. LFT_ROLE, "PARTY")
                    end
                    if LFT_ROLE == 'healer' then
                        LFT.LFMGroup.healer = me
                        SendAddonMessage(LFT_ADDON_CHANNEL, "acceptRole:" .. LFT_ROLE, "PARTY")
                    end
                    if LFT_ROLE == 'damage' then
                        LFT.LFMGroup.damage1 = me
                        SendAddonMessage(LFT_ADDON_CHANNEL, "acceptRole:" .. LFT_ROLE, "PARTY")
                    end
                else
                    _G['LFTRoleCheckQForText']:SetText(COLOR_WHITE .. "Queued for " .. COLOR_YELLOW .. LFT.dungeonNameFromCode(mCode))
                    _G['LFTRoleCheck']:Show()
                    _G['LFTGroupReady']:Hide()
                end
                LFTRoleCheck:Show()
            end

            if string.sub(arg2, 1, 11) == 'acceptRole:' then
                local roleEx = string.split(arg2, ':')
                local roleColor = ''

                if roleEx[2] == 'tank' then
                    roleColor = COLOR_TANK
                end
                if roleEx[2] == 'healer' then
                    roleColor = COLOR_HEALER
                end
                if roleEx[2] == 'damage' then
                    roleColor = COLOR_DAMAGE
                end
                if arg4 == me then
                    lfprint('You have chosen: ' .. roleColor .. LFT.ucFirst(roleEx[2]))
                else
                    --                    lfprint(LFT.classColors[LFT.playerClass(arg4)].c .. arg4 .. COLOR_WHITE .. ' has chosen: ' .. roleColor .. LFT.ucFirst(roleEx[2]))
                end

                if roleEx[2] == 'tank' then
                    if LFT_ROLE == 'tank' then
                        if LFT.isLeader then
                            if arg4 == me then
                                --                                might as well tank = me/arg4, but LFT.LFMGroup.tank is already me
                            else
                                lfprint(LFT.classColors[LFT.playerClass(arg4)].c .. arg4 .. COLOR_WHITE .. ' has chosen ' .. COLOR_TANK .. 'Tank' .. COLOR_WHITE .. ' but you already confirmed this role.')
                                lfprint('Queueing aborted.')
                                leaveQueue(' two tanks')
                                return false
                            end
                        else
                            if LFT.LFMGroup.tank ~= '' then
                                lfprint(COLOR_TANK .. 'Tank ' .. COLOR_WHITE .. 'role has already been filled by ' .. LFT.classColors[LFT.playerClass(LFT.LFMGroup.tank)].c .. LFT.LFMGroup.tank
                                        .. COLOR_WHITE .. '. Please select a different role to rejoin the queue.')
                                return false
                            end
                        end
                    else
                    end
                    LFT.LFMGroup.tank = arg4
                end

                if roleEx[2] == 'healer' then
                    if LFT_ROLE == 'healer' then
                        if LFT.isLeader then
                            if arg4 == me then
                                --                                might as well healer = me/arg4, but LFT.LFMGroup.healer is already me
                            else
                                lfprint(LFT.classColors[LFT.playerClass(arg4)].c .. arg4 .. COLOR_WHITE .. ' has chosen ' .. COLOR_HEALER .. 'Healer' .. COLOR_WHITE .. ' but you already confirmed this role.')
                                lfprint('Queueing aborted.')
                                leaveQueue('two healers')
                                return false
                            end
                        else
                            if LFT.LFMGroup.healer ~= '' then
                                lfprint(COLOR_HEALER .. 'Healer ' .. COLOR_WHITE .. 'role has already been filled by ' .. LFT.classColors[LFT.playerClass(LFT.LFMGroup.healer)].c .. LFT.LFMGroup.healer
                                        .. COLOR_WHITE .. '. Please select a different role to rejoin the queue.')
                                return false
                            end
                        end
                    else
                    end
                    LFT.LFMGroup.healer = arg4
                end

                if roleEx[2] == 'damage' then
                    if LFT_ROLE == 'damage' then
                        if LFT.isLeader then
                            if arg4 == me then
                                --                                might as well healer = me/arg4, but LFT.LFMGroup.healer is already me
                            else
                                if LFT.LFMGroup.damage1 ~= '' and LFT.LFMGroup.damage2 ~= '' and LFT.LFMGroup.damage3 ~= '' then
                                    lfprint(LFT.classColors[LFT.playerClass(arg4)].c .. arg4 .. COLOR_WHITE .. ' has chosen ' .. COLOR_DAMAGE .. 'Damage' .. COLOR_WHITE
                                            .. ' but the group already has ' .. COLOR_DAMAGE .. '3' .. COLOR_WHITE .. ' confirmed ' .. COLOR_DAMAGE .. 'Damage' .. COLOR_WHITE .. ' members.')
                                    lfprint('Queueing aborted.')
                                    leaveQueue('4 dps')
                                    return false
                                end
                            end
                        else
                            if LFT.LFMGroup.damage1 ~= '' and LFT.LFMGroup.damage2 ~= '' and LFT.LFMGroup.damage3 ~= '' then
                                lfprint(COLOR_DAMAGE .. 'Damage ' .. COLOR_WHITE .. 'role has already been filled by ' .. COLOR_DAMAGE .. '3' .. COLOR_WHITE .. ' members. Please select a different role to rejoin the queue.')
                                return false
                            end
                        end
                    end

                    if arg4 ~= me then
                        --im already in the LFMGroup
                        if LFT.LFMGroup.damage1 == '' then
                            lfdebug('set LFT.LFMGroup.damage1 = ' .. arg4)
                            LFT.LFMGroup.damage1 = arg4
                        elseif LFT.LFMGroup.damage2 == '' then
                            lfdebug('set LFT.LFMGroup.damage2 = ' .. arg4)
                            LFT.LFMGroup.damage2 = arg4
                        elseif LFT.LFMGroup.damage3 == '' then
                            lfdebug('set LFT.LFMGroup.damage3 = ' .. arg4)
                            LFT.LFMGroup.damage3 = arg4
                        end

                    end
                end

                if arg4 ~= me then
                    lfprint(LFT.classColors[LFT.playerClass(arg4)].c .. arg4 .. COLOR_WHITE .. ' has chosen: ' .. roleColor .. LFT.ucFirst(roleEx[2]))
                end
                LFT.checkLFMgroup()
            end
            if string.sub(arg2, 1, 12) == 'declineRole:' then
                PlaySoundFile("Interface\\Addons\\LFT\\sound\\lfg_denied.ogg")
                LFT.checkLFMgroup(arg4)
            end
        end
        if event == 'PARTY_INVITE_REQUEST' and LFT.acceptNextInvite then
            if arg1 == LFT.onlyAcceptFrom then
                LFT.AcceptGroupInvite()
                LFT.acceptNextInvite = false
            else
                LFT.DeclineGroupInvite()
            end
        end
        if event == 'CHAT_MSG_CHANNEL_LEAVE' then
            LFT.removePlayerFromVirtualParty(arg2, false) --unknown role
        end
        if event == 'CHAT_MSG_CHANNEL' and string.find(arg1, '[LFT]', 1, true) and arg8 == LFT.channelIndex and arg2 ~= me and --for lfm
                string.find(arg1, '(LFM)', 1, true) then
            --[LFT]:stratlive:(LFM):name
            local mEx = string.split(arg1, ':')
            if mEx[4] == me then
                LFT.onlyAcceptFrom = arg2
                LFT.acceptNextInvite = true
            end
        end
        if event == 'CHAT_MSG_CHANNEL' and arg8 == LFT.channelIndex and string.find(arg1, 'lft_group_formed', 1, true) then
            local gfEx = string.split(arg1, ':')
            local code = gfEx[3]
            local time = tonumber(gfEx[4])
            groupsFormedThisSession = groupsFormedThisSession + 1
            if me == 'Er' then
                lfprint(groupsFormedThisSession .. ' groups formed this session.')
            end
            if not time then
                return false
            end
            if LFT.averageWaitTime == 0 then
                LFT.averageWaitTime = time
            else
                LFT.averageWaitTime = math.floor((LFT.averageWaitTime + time) / 2)
            end
            if not LFT_FORMED_GROUPS[code] then
                LFT_FORMED_GROUPS[code] = 0
            end
            LFT_FORMED_GROUPS[code] = LFT_FORMED_GROUPS[code] + 1
        end
        if event == 'CHAT_MSG_CHANNEL' and string.find(arg1, '[LFT]', 1, true) and arg8 == LFT.channelIndex and arg2 ~= me and --for lfg
                string.find(arg1, 'party:ready', 1, true) then
            local mEx = string.split(arg1, ':')
            LFT.groupFullCode = mEx[2] --code
            local healer = mEx[5]
            local damage1 = mEx[6]
            local damage2 = mEx[7]
            local damage3 = mEx[8]

            --check if party ready message is for me
            if me ~= healer and me ~= damage1 and me ~= damage2 and me ~= damage3 then
                return
            end

            LFT.onlyAcceptFrom = arg2
            LFT.acceptNextInvite = true

            local background = ''
            local dungeonName = 'unknown'
            for d, data in next, LFT.dungeons do
                if data.code == mEx[2] then
                    background = data.background
                    dungeonName = d
                end
            end
            _G['LFTGroupReadyBackground']:SetTexture('Interface\\addons\\LFT\\images\\background\\ui-lfg-background-' .. background)
            _G['LFTGroupReadyRole']:SetTexture('Interface\\addons\\LFT\\images\\' .. LFT_ROLE .. '2')
            _G['LFTGroupReadyMyRole']:SetText(LFT.ucFirst(LFT_ROLE))
            _G['LFTGroupReadyDungeonName']:SetText(dungeonName)
            LFT.readyStatusReset()
            _G['LFTGroupReady']:Show()
            LFTGroupReadyFrameCloser:Show()
            _G['LFTRoleCheck']:Hide()

            PlaySoundFile("Interface\\Addons\\LFT\\sound\\levelup2.ogg")
            LFTQueue:Hide()

            LFT.findingGroup = false
            LFT.findingMore = false
            _G['LFTMain']:Hide()

            LFT.fixMainButton()
        end

        if event == 'CHAT_MSG_CHANNEL' and arg8 == LFT.channelIndex and arg2 ~= me then
            if string.sub(arg1, 1, 7) == 'timeIs:' and not LFT.channelOwner then
                local timeEx = string.split(arg1, ':')
                LFTServerTime:Hide()
                LFTTime.second = tonumber(timeEx[2])
                lfdebug('------ TIME set to ' .. LFTTime.second .. ' -')
                LFTTime:Show()
            end
            if string.sub(arg1, 1, 9) == 'needTime:' and LFT.channelOwner then
                if LFTTime.second == -1 then
                    LFTTime.spamWhenAvailable = true
                else
                    SendChatMessage('timeIs:' .. LFTTime.second, "CHANNEL", DEFAULT_CHAT_FRAME.editBox.languageID, GetChannelName(LFT.channel))
                end
            end
            if string.sub(arg1, 1, 7) == 'whoLFT:' then
                SendChatMessage('meLFT:' .. addonVer, "CHANNEL", DEFAULT_CHAT_FRAME.editBox.languageID, GetChannelName(LFT.channel))
            end
            if string.sub(arg1, 1, 6) == 'meLFT:' then
                --lfdebug(arg1)
                if LFTWhoCounter.listening then
                    LFTWhoCounter.people = LFTWhoCounter.people + 1
                    if me == 'Er' then
                        local verEx = string.split(arg1, ':')
                        local ver = verEx[2]
                        local color = COLOR_GREEN
                        if LFT.ver(ver) < LFT.ver(addonVer) then
                            color = COLOR_ORANGE
                        end
                        lfprint(arg2 .. ' - ' .. color .. 'v' .. ver)
                    end
                end
            end
        end

        if event == 'CHAT_MSG_CHANNEL' and arg8 == LFT.channelIndex and not LFT.oneGroupFull and (LFT.findingGroup or LFT.findingMore) and arg2 ~= me then

            if string.sub(arg1, 1, 6) == 'found:' then

                local foundLongEx = string.split(arg1, ' ')

                for _, found in foundLongEx do
                    local foundEx = string.split(found, ':')
                    local mRole = foundEx[2]
                    local mDungeon = foundEx[3]
                    local name = foundEx[4]
                    local prio = nil
                    if foundEx[5] then
                        if tonumber(foundEx[5]) then
                            prio = tonumber(foundEx[5])
                        end
                    end

                    if LFT_ROLE == mRole and not LFT.foundGroup and name == me then
                        if prio then
                            if LFTGoingWithPicker.candidate == '' then
                                LFTGoingWithPicker.candidate = arg2
                                LFTGoingWithPicker.priority = prio
                                LFTGoingWithPicker.dungeon = mDungeon
                                LFTGoingWithPicker:Show()
                            else
                                if prio > LFTGoingWithPicker.priority then
                                    LFTGoingWithPicker.candidate = arg2
                                    LFTGoingWithPicker.priority = prio
                                    LFTGoingWithPicker.dungeon = mDungeon
                                end
                            end
                        else
                            SendChatMessage('goingWith:' .. arg2 .. ':' .. mDungeon .. ':' .. LFT_ROLE, "CHANNEL", DEFAULT_CHAT_FRAME.editBox.languageID, GetChannelName(LFT.channel))
                            LFT.foundGroup = true
                        end
                        --SendChatMessage('goingWith:' .. arg2 .. ':' .. mDungeon .. ':' .. LFT_ROLE, "CHANNEL", DEFAULT_CHAT_FRAME.editBox.languageID, GetChannelName(LFT.channel))
                        --LFT.foundGroup = true
                    end
                end
            end

            if string.sub(arg1, 1, 10) == 'leftQueue:' then
                local leftEx = string.split(arg1, ':')
                local name = arg2
                local mRole = leftEx[2]
                LFT.removePlayerFromVirtualParty(name, mRole)
            end

            if string.sub(arg1, 1, 10) == 'goingWith:' and (LFT_ROLE == 'tank' or LFT.isLeader) then

                local withEx = string.split(arg1, ':')
                local leader = withEx[2]
                local mDungeon = withEx[3]
                local mRole = withEx[4]

                --check if im queued for mDungeon
                for dungeon, _ in next, LFT.group do
                    if dungeon == mDungeon then
                        if leader ~= me then
                            -- only healers and damages respond with goingwith
                            LFT.remHealerOrDamage(mDungeon, arg2)
                        end
                    end
                    -- otherwise, dont care
                end

                -- lfm, leader should invite this guy now
                if LFT.isLeader then
                    lfdebug('im leader')
                else
                    lfdebug('im not leader')
                end
                if LFT.isLeader and leader == me then
                    if LFT.isNeededInLFMGroup(mRole, arg2, mDungeon) then
                        if mRole == 'tank' then
                            LFT.addTank(mDungeon, arg2, true, true)
                        end
                        if mRole == 'healer' then
                            LFT.addHealer(mDungeon, arg2, true, true)
                        end
                        if mRole == 'damage' then
                            LFT.addDamage(mDungeon, arg2, true, true)
                        end
                        LFT.inviteInLFMGroup(arg2)
                    end
                end
            end

            --            if string.sub(arg1, 1, 4) == 'LFG:' then
            -- LFG
            --            if string.find(arg1, 'LFG:', 1, true) then
            if string.sub(arg1, 1, 4) == 'LFG:' then

                local lfgEx = string.split(arg1, ' ')
                local foundMessage = ''
                local prioMembers = GetNumPartyMembers() + 1
                local prioObjectives = LFT.getDungeonCompletion()

                for _, lfg in lfgEx do
                    local spamSplit = string.split(lfg, ':')
                    local mDungeonCode = spamSplit[2]
                    local mRole = spamSplit[3] --other's role

                    for _, data in next, LFT.dungeons do
                        if data.queued and data.code == mDungeonCode then

                            --LFM forming
                            if LFT.isLeader then
                                if mRole == 'tank' then
                                    if LFT.addTank(mDungeonCode, arg2) then
                                        foundMessage = foundMessage .. 'found:tank:' .. mDungeonCode .. ':' .. arg2 .. ':' .. prioMembers .. ':' .. prioObjectives .. ' '
                                    end
                                end
                                if mRole == 'healer' then
                                    if LFT.addHealer(mDungeonCode, arg2) then
                                        foundMessage = foundMessage .. 'found:healer:' .. mDungeonCode .. ':' .. arg2 .. ':' .. prioMembers .. ':' .. prioObjectives .. ' '
                                    end
                                end
                                if mRole == 'damage' then
                                    if LFT.addDamage(mDungeonCode, arg2) then
                                        foundMessage = foundMessage .. 'found:damage:' .. mDungeonCode .. ':' .. arg2 .. ':' .. prioMembers .. ':' .. prioObjectives .. ' '
                                    end
                                end
                                if foundMessage ~= '' then
                                    SendChatMessage(foundMessage, "CHANNEL", DEFAULT_CHAT_FRAME.editBox.languageID, GetChannelName(LFT.channel))
                                end
                                return false
                            end

                            -- LFG forming
                            if LFT_ROLE == 'tank' then
                                LFT.group[mDungeonCode].tank = me

                                if mRole == 'healer' then
                                    if LFT.addHealer(mDungeonCode, arg2, false, true) then
                                        foundMessage = foundMessage .. 'found:healer:' .. mDungeonCode .. ':' .. arg2 .. ':0:0 '
                                    end
                                end
                                if mRole == 'damage' then
                                    if LFT.addDamage(mDungeonCode, arg2, false, true) then
                                        foundMessage = foundMessage .. 'found:damage:' .. mDungeonCode .. ':' .. arg2 .. ':0:0 '
                                    end
                                end
                            end

                            --pseudo fill group for tooltip display
                            if LFT_ROLE == 'healer' then
                                LFT.addHealer(mDungeonCode, me, true) --faux

                                if mRole == 'tank' and LFT.group[mDungeonCode].tank == '' then
                                    LFT.group[mDungeonCode].tank = arg2
                                end

                                if mRole == 'damage' then
                                    LFT.addDamage(mDungeonCode, arg2, true) --faux
                                end
                            end

                            if LFT_ROLE == 'damage' then
                                LFT.addDamage(mDungeonCode, me, true) --faux

                                if mRole == 'tank' and LFT.group[mDungeonCode].tank == '' then
                                    LFT.group[mDungeonCode].tank = arg2
                                end
                                if mRole == 'healer' and LFT.group[mDungeonCode].healer == '' then
                                    LFT.group[mDungeonCode].healer = arg2
                                end
                            end
                        end
                    end
                end

                SendChatMessage(foundMessage, "CHANNEL", DEFAULT_CHAT_FRAME.editBox.languageID, GetChannelName(LFT.channel))

                --                local spamSplit = string.split(arg1, ':')
                --                local mDungeonCode = spamSplit[2]
                --                local mRole = spamSplit[3] --other's role
                --
                --                for dungeon, data in next, LFT.dungeons do
                --                    if data.queued and data.code == mDungeonCode then
                --
                --                        if LFT.isLeader then
                --                            if mRole == 'tank' then LFT.addTank(mDungeonCode, arg2) end
                --                            if mRole == 'healer' then LFT.addHealer(mDungeonCode, arg2) end
                --                            if mRole == 'damage' then LFT.addDamage(mDungeonCode, arg2) end
                --                            return false
                --                        end
                --
                --                        if LFT_ROLE == 'tank' then
                --                            LFT.group[mDungeonCode].tank = me
                --
                --                            if mRole == 'healer' then LFT.addHealer(mDungeonCode, arg2, false, true) end
                --                            if mRole == 'damage' then LFT.addDamage(mDungeonCode, arg2, false, true) end
                --                        end
                --
                --                        --pseudo fill group for tooltip display
                --                        if LFT_ROLE == 'healer' then
                --                            LFT.addHealer(mDungeonCode, me, true)
                --
                --                            if mRole == 'tank' and LFT.group[mDungeonCode].tank == '' then
                --                                LFT.group[mDungeonCode].tank = arg2
                --                            end
                --
                --                            if mRole == 'damage' then
                --                                LFT.addDamage(mDungeonCode, arg2, true)
                --                            end
                --                        end
                --
                --                        if LFT_ROLE == 'damage' then
                --                            LFT.addDamage(mDungeonCode, me, true)
                --                            if mRole == 'tank' and LFT.group[mDungeonCode].tank == '' then
                --                                LFT.group[mDungeonCode].tank = arg2
                --                            end
                --                            if mRole == 'healer' and LFT.group[mDungeonCode].healer == '' then
                --                                LFT.group[mDungeonCode].healer = arg2
                --                            end
                --                        end
                --                    end
                --                end
            end
        end
    end
end)

-- debug and print functions

function lfprint(a)
    if a == nil then
        DEFAULT_CHAT_FRAME:AddMessage(COLOR_HUNTER .. '[LFT]|cff0070de:' .. time() .. '|cffffffff attempt to print a nil value.')
        return false
    end
    DEFAULT_CHAT_FRAME:AddMessage(COLOR_HUNTER .. "[LFT] |cffffffff" .. a)
end

function lferror(a)
    DEFAULT_CHAT_FRAME:AddMessage('|cff69ccf0[LFTError]|cff0070de:' .. time() .. '|cffffffff[' .. a .. ']')
end

function lfdebug(a)
    if not LFT_DEBUG then
        return false
    end
    if type(a) == 'boolean' then
        if a then
            lfprint('|cff0070de[LFTDEBUG:' .. time() .. ']|cffffffff[true]')
        else
            lfprint('|cff0070de[LFTDEBUG:' .. time() .. ']|cffffffff[false]')
        end
        return true
    end
    lfprint('|cff0070de[LFTDEBUG:' .. time() .. ']|cffffffff[' .. a .. ']')
end

LFT:SetScript("OnEvent", function()
    if event then
        if event == "ADDON_LOADED" and arg1 == 'LFT' then
            LFT.init()
        end
        if event == "PLAYER_ENTERING_WORLD" then
            LFT.level = UnitLevel('player')
            LFT.sendMyVersion()
        end
        if event == "PARTY_LEADER_CHANGED" then
            lfdebug('PARTY_LEADER_CHANGED')
            LFT.isLeader = IsPartyLeader()
            if GetNumPartyMembers() + 1 == LFT.groupSizeMax then
            else
                -- only leave queue if im in queue
                if LFT.isLeader and (LFT.findingGroup or LFT.findingMore) then
                    leaveQueue('party leader changed group < 5 ')
                end
            end
        end
        if event == "PARTY_MEMBERS_CHANGED" then
            lfdebug('PARTY_MEMBERS_CHANGED') --check -- triggers in raids too
            DungeonListFrame_Update()
            local someoneJoined = GetNumPartyMembers() + 1 > LFT.currentGroupSize
            local someoneLeft = GetNumPartyMembers() + 1 < LFT.currentGroupSize

            LFT.currentGroupSize = GetNumPartyMembers() + 1
            LFT.inGroup = GetNumRaidMembers() == 0 and GetNumPartyMembers() > 0

            if LFT.inGroup then
                if LFT.isLeader then
                else
                    _G['LFTMain']:Hide()
                end
            else
                -- i left the group OR everybody left
                lfdebug('LFTInvite.inviteIndex = ' .. LFTInvite.inviteIndex)
                _G['LFTDungeonStatus']:Hide()
                _G['LFTRoleCheck']:Hide()

                -- i left when there was a dungeon in progress
                if LFTDungeonComplete.dungeonInProgress then
                    -- todo i guess...
                    LFTDungeonComplete.dungeonInProgress = false
                end

                if LFTInvite.inviteIndex == 1 then
                    return false
                end
                if LFT.findingGroup or LFT.findingMore then
                    leaveQueue('not group and finding group/more')
                end
                return false
            end

            if someoneJoined then
                if LFT.findingMore and LFT.isLeader then

                    -- send him objectives
                    local objectivesString = ''
                    for index, _ in next, LFT.objectivesFrames do
                        if LFT.objectivesFrames[index].completed then
                            objectivesString = objectivesString .. '1-'
                        else
                            objectivesString = objectivesString .. '0-'
                        end
                    end
                    SendAddonMessage(LFT_ADDON_CHANNEL, "objectives:" .. LFT.LFMDungeonCode .. ":" .. objectivesString, "PARTY")
                    -- end send objectives

                    local newName = ''
                    local joinedManually = false
                    for i = 1, GetNumPartyMembers() do
                        local name = UnitName('party' .. i)
                        local fromQueue = name == LFT.group[LFT.LFMDungeonCode].tank or
                                name == LFT.group[LFT.LFMDungeonCode].healer or
                                name == LFT.group[LFT.LFMDungeonCode].damage1 or
                                name == LFT.group[LFT.LFMDungeonCode].damage2 or
                                name == LFT.group[LFT.LFMDungeonCode].damage3

                        if not fromQueue then
                            newName = name
                            joinedManually = true
                        end
                    end
                    if joinedManually then
                        --joined manually, dont know his role

                        LFTFillAvailableDungeonsDelay.queueAfterIfPossible = GetNumPartyMembers() < (LFT.groupSizeMax - 1)

                        if not LFTFillAvailableDungeonsDelay.queueAfterIfPossible then
                            --group full
                            SendAddonMessage(LFT_ADDON_CHANNEL, "LFMPartyReady:" .. LFT.LFMDungeonCode .. ":" .. LFTObjectives.objectivesComplete .. ":" .. LFT.tableSize(LFT.bosses[LFT.LFMDungeonCode]), "PARTY")
                            return false -- so it goes into check full in timer
                        end
                        leaveQueue(' someone joined manually')
                        --                      findMore()
                    else
                        --joined from the queue, we know his role, check if group is full
                        --  lfdebug('player ' .. newName .. ' joined from queue')

                        if LFT.checkLFMGroupReady(LFT.LFMDungeonCode) then
                            SendAddonMessage(LFT_ADDON_CHANNEL, "LFMPartyReady:" .. LFT.LFMDungeonCode .. ":" .. LFTObjectives.objectivesComplete .. ":" .. LFT.tableSize(LFT.bosses[LFT.LFMDungeonCode]), "PARTY")
                        else
                            SendAddonMessage(LFT_ADDON_CHANNEL, "weInQueue:" .. LFT.LFMDungeonCode, "PARTY")
                        end
                    end
                end
            end
            if someoneLeft then
                _G['LFTReadyStatus']:Hide()
                _G['LFTGroupReady']:Hide()
                -- find who left and update virtual group
                if LFT.findingMore and LFT.isLeader then

                    --inc some getto code
                    lfdebug('someone left')
                    local leftName = ''
                    local stillInParty = false
                    if LFT.group[LFT.LFMDungeonCode].tank ~= '' and LFT.group[LFT.LFMDungeonCode].tank ~= me then
                        leftName = LFT.group[LFT.LFMDungeonCode].tank
                        stillInParty = false
                        for i = 1, GetNumPartyMembers() do
                            local name = UnitName('party' .. i)
                            if leftName == name then
                                stillInParty = true
                                break
                            end
                        end
                        if not stillInParty then
                            LFT.group[LFT.LFMDungeonCode].tank = ''
                            LFT.LFMGroup.tank = ''
                            lfprint(leftName .. ' (' .. COLOR_TANK .. 'Tank' .. COLOR_WHITE .. ') has been removed from the queue group.')
                        end
                    end
                    --
                    if LFT.group[LFT.LFMDungeonCode].healer ~= '' and LFT.group[LFT.LFMDungeonCode].healer ~= me then
                        leftName = LFT.group[LFT.LFMDungeonCode].healer
                        stillInParty = false
                        for i = 1, GetNumPartyMembers() do
                            local name = UnitName('party' .. i)
                            if leftName == name then
                                stillInParty = true
                                break
                            end
                        end
                        if not stillInParty then
                            LFT.group[LFT.LFMDungeonCode].healer = ''
                            LFT.LFMGroup.healer = ''
                            lfprint(leftName .. ' (' .. COLOR_HEALER .. 'Healer' .. COLOR_WHITE .. ') has been removed from the queue group.')
                        end
                    end
                    --
                    if LFT.group[LFT.LFMDungeonCode].damage1 ~= '' and LFT.group[LFT.LFMDungeonCode].damage1 ~= me then
                        leftName = LFT.group[LFT.LFMDungeonCode].damage1
                        stillInParty = false
                        for i = 1, GetNumPartyMembers() do
                            local name = UnitName('party' .. i)
                            if leftName == name then
                                stillInParty = true
                                break
                            end
                        end
                        if not stillInParty then
                            LFT.group[LFT.LFMDungeonCode].damage1 = ''
                            LFT.LFMGroup.damage1 = ''
                            lfprint(leftName .. ' (' .. COLOR_DAMAGE .. 'Damage' .. COLOR_WHITE .. ') has been removed from the queue group.')
                        end
                    end
                    --
                    if LFT.group[LFT.LFMDungeonCode].damage2 ~= '' and LFT.group[LFT.LFMDungeonCode].damage2 ~= me then
                        leftName = LFT.group[LFT.LFMDungeonCode].damage2
                        stillInParty = false
                        for i = 1, GetNumPartyMembers() do
                            local name = UnitName('party' .. i)
                            if leftName == name then
                                stillInParty = true
                                break
                            end
                        end
                        if not stillInParty then
                            LFT.group[LFT.LFMDungeonCode].damage2 = ''
                            LFT.LFMGroup.damage2 = ''
                            lfprint(leftName .. ' (' .. COLOR_DAMAGE .. 'Damage' .. COLOR_WHITE .. ') has been removed from the queue group.')
                        end
                    end
                    --
                    if LFT.group[LFT.LFMDungeonCode].damage3 ~= '' and LFT.group[LFT.LFMDungeonCode].damage3 ~= me then
                        leftName = LFT.group[LFT.LFMDungeonCode].damage3
                        stillInParty = false
                        for i = 1, GetNumPartyMembers() do
                            local name = UnitName('party' .. i)
                            if leftName == name then
                                stillInParty = true
                                break
                            end
                        end
                        if not stillInParty then
                            LFT.group[LFT.LFMDungeonCode].damage3 = ''
                            LFT.LFMGroup.damage3 = ''
                            lfprint(leftName .. ' (' .. COLOR_DAMAGE .. 'Damage' .. COLOR_WHITE .. ') has been remove from the queue group.')
                        end
                    end
                end
            end
            lfdebug('ajunge aici ??')
            if LFT.isLeader then
                LFT.sendMinimapDataToParty(LFT.LFMDungeonCode)
            end
            -- update awesome button enabled if 5/5 disabled + text if not
            local awesomeButton = _G['LFTGroupReadyAwesome']
            awesomeButton:SetText('Waiting Players (' .. LFT.groupSizeMax - GetNumPartyMembers() - 1 .. ')')
            awesomeButton:Disable()

            if GetNumPartyMembers() == LFT.groupSizeMax - 1 then
                awesomeButton:SetText('Let\'s do this!')
                awesomeButton:Enable()
            end
            lfdebug(' end PARTY_MEMBERS_CHANGED')
        end
        if event == 'PLAYER_LEVEL_UP' then
            LFT.level = arg1
            LFT.fillAvailableDungeons()
        end
    end
end)

function LFT.init()

    LFTServerTime:Show()

    if LFT_DEBUG == nil then
        LFT_DEBUG = false
    end
    if LFT_DEBUG then
        _G['LFTTitleTime']:Show()
    else
        _G['LFTTitleTime']:Hide()
    end
    local _, uClass = UnitClass('player')
    LFT.class = string.lower(uClass)

    if not LFT_TYPE then
        LFT_TYPE = 1
    end
    -- disabled type 2, needs to reset to 1
    if LFT_TYPE == 2 then
        LFT_TYPE = 1
    end

    UIDropDownMenu_SetText(LFT.types[LFT_TYPE], _G['LFTTypeSelect']);
    _G['LFTDungeonsText']:SetText(LFT.types[LFT_TYPE])
    if not LFT_ROLE then
        LFT_ROLE = LFT.GetPossibleRoles()
    else
        LFT.GetPossibleRoles()
        LFTsetRole(LFT_ROLE)
    end

    if not LFT_FORMED_GROUPS then
        LFT.resetFormedGroups()
    else
        --check if formed groups include maybe new dungeon codes
        for _, data in next, LFT.dungeons do
            if not LFT_FORMED_GROUPS[data.code] then
                LFT_FORMED_GROUPS[data.code] = 0
            end
        end
    end

    LFT.channel = 'LFT'
    LFT.channelIndex = 0
    LFT.level = UnitLevel('player')
    LFT.findingGroup = false
    LFT.findingMore = false
    LFT:RegisterEvent("ADDON_LOADED")
    LFT.availableDungeons = {}
    LFT.group = {}
    LFT.oneGroupFull = false
    LFT.groupFullCode = ''
    LFT.acceptNextInvite = false
    LFT.minimapFrameIndex = 0
    LFT.currentGroupSize = GetNumPartyMembers() + 1

    LFT.isLeader = IsPartyLeader() or false

    LFT.inGroup = GetNumRaidMembers() == 0 and GetNumPartyMembers() > 0
    LFT.fixMainButton()

    LFT.fillAvailableDungeons()

    LFTChannelJoinDelay:Show()

    LFT.objectivesFrames = {}
    LFTDungeonComplete.dungeonInProgress = false

    _G['LFTGroupReadyAwesome']:Disable()

    lfprint(COLOR_HUNTER .. 'Looking For Turtles v' .. addonVer .. COLOR_WHITE .. ' - LFG Addon for Turtle WoW loaded.')

    --    _G['MainMenuBarTexture2'):SetWidth(288)
end

LFTQueue:SetScript("OnShow", function()
    this.startTime = GetTime()
    this.spammed = {
        tank = false,
        damage = false,
        heal = false,
        reset = false,
        checkGroupFull = false
    }
end)

LFTQueue:SetScript("OnHide", function()
    _G['LFT_MinimapEye']:SetTexture('Interface\\Addons\\LFT\\images\\eye\\battlenetworking0')
end)

LFTQueue:SetScript("OnUpdate", function()
    local plus = 0.15 --seconds
    local gt = GetTime() * 1000 --22.123 -> 22123
    local st = (this.startTime + plus) * 1000 -- (22.123 + 0.1) * 1000 =  22.223 * 1000 = 22223
    if gt >= st and LFT.findingGroup then
        this.startTime = GetTime()

        _G['LFT_MinimapEye']:SetTexture('Interface\\Addons\\LFT\\images\\eye\\battlenetworking' .. LFT.minimapFrameIndex)

        if LFT.minimapFrameIndex < 28 then
            LFT.minimapFrameIndex = LFT.minimapFrameIndex + 1
        else
            LFT.minimapFrameIndex = 0
        end

        if LFTTime.second == -1 then
            return false
        end

        --local cSecond = tonumber(date("%S", time()))
        local cSecond = LFTTime.second

        _G['LFTTitleTime']:SetText(cSecond)
        _G['LFTGroupStatusTimeInQueue']:SetText('Time in Queue: ' .. SecondsToTime(time() - LFT.queueStartTime))
        if LFT.averageWaitTime == 0 then
            _G['LFTGroupStatusAverageWaitTime']:SetText('Average Wait Time: Unavailable')
        else
            _G['LFTGroupStatusAverageWaitTime']:SetText('Average Wait Time: ' .. SecondsToTimeAbbrev(LFT.averageWaitTime))
        end

        if (cSecond == LFT.RESET_TIME or cSecond == LFT.RESET_TIME + LFT.TIME_MARGIN) and not this.spammed.reset then
            lfdebug('reset -- call -- spam')
            this.spammed = {
                tank = false,
                damage = false,
                heal = false,
                reset = false,
                checkGroupFull = false
            }
            if not LFT.inGroup then
                -- dont reset group if we're LFM
                LFT.resetGroup()
            end
        end

        if (cSecond == LFT.TANK_TIME + LFT.myRandomTime or cSecond == LFT.TANK_TIME + LFT.TIME_MARGIN + LFT.myRandomTime) and LFT_ROLE == 'tank' and not this.spammed.tank then
            this.spammed.tank = true
            if not LFT.inGroup then
                -- only start forming group if im not already grouped
                for _, data in next, LFT.dungeons do
                    if data.queued then
                        LFT.group[data.code].tank = me
                    end
                end
                --new: but do send lfg message if im a tank, to be picked up by LFM party leader
                LFT.sendLFMessage()
            end
        end

        if (cSecond == LFT.HEALER_TIME + LFT.myRandomTime or cSecond == LFT.HEALER_TIME + LFT.TIME_MARGIN + LFT.myRandomTime) and LFT_ROLE == 'healer' and not this.spammed.heal then
            this.spammed.heal = true
            if not LFT.inGroup then
                -- dont spam lfm if im already in a group, because leader will pick up new players
                LFT.sendLFMessage()
            end
        end

        if (cSecond == LFT.DAMAGE_TIME + LFT.myRandomTime or cSecond == LFT.DAMAGE_TIME + LFT.TIME_MARGIN + LFT.myRandomTime) and LFT_ROLE == 'damage' and not this.spammed.damage then
            this.spammed.damage = true
            if not LFT.inGroup then
                -- dont spam lfm if im already in a group, because leader will pick up new players
                LFT.sendLFMessage()
            end
        end

        if (cSecond == LFT.FULLCHECK_TIME or cSecond == LFT.FULLCHECK_TIME + LFT.TIME_MARGIN) and LFT_ROLE == 'tank' and not this.spammed.checkGroupFull then
            this.spammed.checkGroupFull = true
            if not LFT.inGroup then

                local groupFull, code, healer, damage1, damage2, damage3 = LFT.checkGroupFull()

                if groupFull then
                    LFT.groupFullCode = code

                    SendChatMessage("[LFT]:" .. code .. ":party:ready:" .. healer .. ":" .. damage1 .. ":" .. damage2 .. ":" .. damage3,
                            "CHANNEL", DEFAULT_CHAT_FRAME.editBox.languageID, GetChannelName(LFT.channel))

                    SendChatMessage("[LFT]:lft_group_formed:" .. code .. ":" .. time() - LFT.queueStartTime, "CHANNEL", DEFAULT_CHAT_FRAME.editBox.languageID, GetChannelName(LFT.channel))

                    --untick everything
                    for dungeon, data in next, LFT.dungeons do
                        if _G["Dungeon_" .. data.code] then
                            _G["Dungeon_" .. data.code]:SetChecked(false)
                        end
                        LFT.dungeons[dungeon].queued = false
                    end

                    LFT.findingGroup = false
                    LFT.findingMore = false

                    local background = ''
                    local dungeonName = 'unknown'
                    for d, data in next, LFT.dungeons do
                        if data.code == code then
                            background = data.background
                            dungeonName = d
                        end
                    end
                    _G['LFTGroupReadyBackground']:SetTexture('Interface\\addons\\LFT\\images\\background\\ui-lfg-background-' .. background)
                    _G['LFTGroupReadyRole']:SetTexture('Interface\\addons\\LFT\\images\\' .. LFT_ROLE .. '2')
                    _G['LFTGroupReadyMyRole']:SetText(LFT.ucFirst(LFT_ROLE))
                    _G['LFTGroupReadyDungeonName']:SetText(dungeonName)
                    LFT.readyStatusReset()
                    _G['LFTGroupReady']:Show()
                    LFTGroupReadyFrameCloser:Show()

                    _G['LFTRoleCheck']:Hide()

                    PlaySoundFile("Interface\\Addons\\LFT\\sound\\levelup2.ogg")
                    LFTQueue:Hide()
                    _G['LFT_MinimapEye']:SetTexture('Interface\\Addons\\LFT\\images\\eye\\battlenetworking0')

                    LFT.fixMainButton()
                    _G['LFTMain']:Hide()
                    LFTInvite:Show()
                end
            end

        end

    end
end)

function LFT.checkLFTChannel()
    lfdebug('check LFT channel call - after 15s')
    local lastVal = 0
    local chanList = { GetChannelList() }

    for _, value in next, chanList do
        if value == LFT.channel then
            LFT.channelIndex = lastVal
            break
        end
        lastVal = value
    end

    if LFT.channelIndex == 0 then
        lfdebug('not in chan, joining')
        JoinChannelByName(LFT.channel)
    else
        lfdebug('in chan, chilling LFT.channelIndex = ' .. LFT.channelIndex)
    end

    DisplayChannelOwner(LFT.channel)

end

function LFT.GetPossibleRoles()

    local tankCheck = _G['RoleTank']
    local healerCheck = _G['RoleHealer']
    local damageCheck = _G['RoleDamage']

    --ready check window
    local readyCheckTank = _G['roleCheckTank']
    local readyCheckHealer = _G['roleCheckHealer']
    local readyCheckDamage = _G['roleCheckDamage']

    tankCheck:Disable()
    tankCheck:SetChecked(false)
    healerCheck:Disable()
    healerCheck:SetChecked(false)
    damageCheck:Disable()
    damageCheck:SetChecked(false)

    readyCheckTank:Disable()
    readyCheckTank:SetChecked(false)
    readyCheckHealer:Disable()
    readyCheckHealer:SetChecked(false)
    readyCheckDamage:Disable()
    readyCheckDamage:SetChecked(false)

    if LFT.class == 'warrior' then
        readyCheckTank:Enable();
        tankCheck:Enable();

        readyCheckTank:SetChecked(true)
        tankCheck:SetChecked(true)

        readyCheckDamage:Enable()
        damageCheck:Enable()

        readyCheckDamage:SetChecked(false)
        damageCheck:SetChecked(false)
        return 'tank'
    end
    if LFT.class == 'paladin' or LFT.class == 'druid' or LFT.class == 'shaman' then
        readyCheckTank:Enable();
        tankCheck:Enable();
        readyCheckTank:SetChecked(false)
        tankCheck:SetChecked(false)

        readyCheckHealer:Enable()
        healerCheck:Enable()
        readyCheckHealer:SetChecked(true)
        healerCheck:SetChecked(true)

        readyCheckDamage:Enable()
        damageCheck:Enable()
        readyCheckDamage:SetChecked(false)
        damageCheck:SetChecked(false)
        return 'healer'
    end
    if LFT.class == 'priest' then
        readyCheckHealer:Enable()
        healerCheck:Enable()
        readyCheckHealer:SetChecked(true)
        healerCheck:SetChecked(true)

        readyCheckDamage:Enable()
        damageCheck:Enable()
        readyCheckDamage:SetChecked(false)
        damageCheck:SetChecked(false)
        return 'healer'
    end
    if LFT.class == 'warlock' or LFT.class == 'hunter' or LFT.class == 'mage' or LFT.class == 'rogue' then
        readyCheckDamage:Enable()
        damageCheck:Enable()
        readyCheckDamage:SetChecked(true)
        damageCheck:SetChecked(true)
        return 'damage'
    end
    return 'damage'
end

function LFT.getAvailableDungeons(level, type, mine)
    if level == 0 then
        return {}
    end
    local dungeons = {}
    for _, data in next, LFT.dungeons do
        if level >= data.minLevel and (level <= data.maxLevel or (not mine)) and type ~= 3 then
            dungeons[data.code] = true
        end
        if level >= data.minLevel and type == 3 then
            --all available
            dungeons[data.code] = true
        end
    end
    return dungeons
end

function LFT.fillAvailableDungeons(offset, queueAfter)
    if not offset then
        offset = 0
    end

    --unqueue queued
    for dungeon, data in next, LFT.dungeons do
        LFT.dungeons[dungeon].canQueue = true
        if data.queued and (LFT.level < data.minLevel or LFT.level > data.maxLevel) then
            LFT.dungeons[dungeon].queued = false
        end
    end

    --hide all
    for _, frame in next, LFT.availableDungeons do
        _G["Dungeon_" .. frame.code]:Hide()
    end

    -- if grouped fill only dungeons that can be joined by EVERYONE
    if LFT.inGroup then

        local party = {
            [0] = {
                level = LFT.level,
                name = UnitName('player'),
                dungeons = LFT.getAvailableDungeons(LFT.level, LFT_TYPE, true)
            }
        }
        for i = 1, GetNumPartyMembers() do
            party[i] = {
                level = UnitLevel('party' .. i),
                name = UnitName('party' .. i),
                dungeons = LFT.getAvailableDungeons(UnitLevel('party' .. i), LFT_TYPE, false)
            }

            if party[i].level == 0 and UnitIsConnected('party' .. i) then
                LFTFillAvailableDungeonsDelay.offset = offset
                LFTFillAvailableDungeonsDelay:Show()
                return false
            end
        end

        LFTFillAvailableDungeonsDelay.triggers = 0

        for dungeonCode in next, LFT.getAvailableDungeons(LFT.level, LFT_TYPE, true) do
            local canAdd = {
                [1] = UnitLevel('party1') == 0,
                [2] = UnitLevel('party2') == 0,
                [3] = UnitLevel('party3') == 0,
                [4] = UnitLevel('party4') == 0
            }

            for i = 1, GetNumPartyMembers() do
                for code in next, party[i].dungeons do
                    if dungeonCode == code then
                        canAdd[i] = true
                    end
                end
            end
            if canAdd[1] and canAdd[2] and canAdd[3] and canAdd[4] then
            else
                LFT.dungeons[LFT.dungeonNameFromCode(dungeonCode)].canQueue = false
            end
        end
    end

    local dungeonIndex = 0
    for dungeon, data in LFT.fuckingSortAlready(LFT.dungeons) do
        --    for dungeon, data in next, LFT.dungeons do
        if LFT.level >= data.minLevel and LFT.level <= data.maxLevel and LFT_TYPE ~= 3 then

            dungeonIndex = dungeonIndex + 1
            if dungeonIndex > offset and dungeonIndex <= offset + LFT.maxDungeonsList then
                if not LFT.availableDungeons[data.code] then
                    LFT.availableDungeons[data.code] = CreateFrame("CheckButton", "Dungeon_" .. data.code, _G["LFTMain"], "LFT_DungeonCheck")
                end

                LFT.availableDungeons[data.code]:Show()

                local color = COLOR_GREEN
                if LFT.level == data.minLevel or LFT.level == data.minLevel + 1 then
                    color = COLOR_RED
                end
                if LFT.level == data.minLevel + 2 or LFT.level == data.minLevel + 3 then
                    color = COLOR_ORANGE
                end
                if LFT.level == data.minLevel + 4 or LFT.level == data.maxLevel + 5 then
                    color = COLOR_GREEN
                end

                if LFT.level > data.maxLevel then
                    color = COLOR_GREEN
                end

                _G['Dungeon_' .. data.code]:Enable()

                if data.canQueue then
                    LFT.removeOnEnterTooltip(_G['Dungeon_' .. data.code .. '_Button'])
                else
                    color = COLOR_DISABLED
                    data.queued = false
                    LFT.addOnEnterTooltip(_G['Dungeon_' .. data.code .. '_Button'], dungeon .. ' is unavailable',
                            'A member of your group does not meet', 'the suggested minimum level requirement (' .. data.minLevel .. ').')
                    _G['Dungeon_' .. data.code]:Disable()
                end

                _G['Dungeon_' .. data.code .. 'Text']:SetText(color .. dungeon)
                _G['Dungeon_' .. data.code .. 'Levels']:SetText(color .. '(' .. data.minLevel .. ' - ' .. data.maxLevel .. ')')
                _G['Dungeon_' .. data.code .. '_Button']:SetID(dungeonIndex)

                LFT.availableDungeons[data.code]:SetPoint("TOP", _G["LFTMain"], "TOP", -145, -165 - 20 * (dungeonIndex - offset))
                LFT.availableDungeons[data.code].code = data.code
                LFT.availableDungeons[data.code].minLevel = data.minLevel
                LFT.availableDungeons[data.code].maxLevel = data.maxLevel

                LFT.dungeons[dungeon].queued = data.queued
                _G['Dungeon_' .. data.code]:SetChecked(data.queued)

                if LFT_TYPE == 2 and not LFT.inGroup then
                    LFT.dungeons[dungeon].queued = true
                    _G['Dungeon_' .. data.code]:SetChecked(true)
                end
            end
        end

        if LFT.level >= data.minLevel and LFT_TYPE == 3 then
            --all available

            dungeonIndex = dungeonIndex + 1
            if dungeonIndex > offset and dungeonIndex <= offset + LFT.maxDungeonsList then
                if not LFT.availableDungeons[data.code] then
                    LFT.availableDungeons[data.code] = CreateFrame("CheckButton", "Dungeon_" .. data.code, _G["LFTMain"], "LFT_DungeonCheck")
                end

                LFT.availableDungeons[data.code]:Show()

                local color = COLOR_GREEN
                if LFT.level == data.minLevel or LFT.level == data.minLevel + 1 then
                    color = COLOR_RED
                end
                if LFT.level == data.minLevel + 2 or LFT.level == data.minLevel + 3 then
                    color = COLOR_ORANGE
                end
                if LFT.level == data.minLevel + 4 or LFT.level == data.maxLevel + 5 then
                    color = COLOR_GREEN
                end

                if LFT.level > data.maxLevel then
                    color = COLOR_GREEN
                end

                _G['Dungeon_' .. data.code]:Enable()

                if data.canQueue then
                    LFT.removeOnEnterTooltip(_G['Dungeon_' .. data.code .. '_Button'])
                else
                    color = COLOR_DISABLED
                    data.queued = false
                    LFT.addOnEnterTooltip(_G['Dungeon_' .. data.code .. '_Button'], dungeon .. ' is unavailable',
                            'A member of your group does not meet', 'the suggested minimum level requirement (' .. data.minLevel .. ').')
                    _G['Dungeon_' .. data.code]:Disable()
                end

                _G['Dungeon_' .. data.code .. 'Text']:SetText(color .. dungeon)
                _G['Dungeon_' .. data.code .. 'Levels']:SetText(color .. '(' .. data.minLevel .. ' - ' .. data.maxLevel .. ')')
                _G['Dungeon_' .. data.code .. '_Button']:SetID(dungeonIndex)

                LFT.availableDungeons[data.code]:SetPoint("TOP", _G["LFTMain"], "TOP", -145, -165 - 20 * (dungeonIndex - offset))
                LFT.availableDungeons[data.code].code = data.code
                LFT.availableDungeons[data.code].minLevel = data.minLevel
                LFT.availableDungeons[data.code].maxLevel = data.maxLevel
            end
        end
        if LFT.findingMore then
            if _G['Dungeon_' .. data.code] then
                _G['Dungeon_' .. data.code]:Disable()
                _G['Dungeon_' .. data.code]:SetChecked(false)
            end
            if data.code == LFT.LFMDungeonCode then
                if _G['Dungeon_' .. data.code] then
                    _G['Dungeon_' .. data.code]:SetChecked(true)
                end
                LFT.dungeons[dungeon].queued = true
            end
        end
        if _G['Dungeon_' .. data.code] then
            if _G['Dungeon_' .. data.code]:GetChecked() then
                LFT.dungeons[dungeon].queued = true
            end
        end
    end

    -- gray out the rest if there are 5 already checked
    local queues = 0
    for _, d in next, LFT.dungeons do
        if d.queued then
            queues = queues + 1
        end
    end
    if queues >= LFT.maxDungeonsInQueue then

        for _, frame in next, LFT.availableDungeons do
            local dungeonName = LFT.dungeonNameFromCode(frame.code)
            if not LFT.dungeons[dungeonName].queued then
                _G["Dungeon_" .. frame.code]:Disable()
                _G['Dungeon_' .. frame.code .. 'Text']:SetText(COLOR_DISABLED .. dungeonName)
                _G['Dungeon_' .. frame.code .. 'Levels']:SetText(COLOR_DISABLED .. '(' .. frame.minLevel .. ' - ' .. frame.maxLevel .. ')')
                LFT.addOnEnterTooltip(_G['Dungeon_' .. frame.code .. '_Button'], 'Queueing for ' .. dungeonName .. ' is unavailable',
                        'Maximum allowed queued dungeons at a time is ' .. LFT.maxDungeonsInQueue .. '.')
            end
        end
    end
    -- end gray

    FauxScrollFrame_Update(_G['DungeonListScrollFrame'], dungeonIndex, LFT.maxDungeonsList, 20)

    LFT.fixMainButton()

    if queueAfter then
        LFTFillAvailableDungeonsDelay.queueAfterIfPossible = false

        --find checked dungeon
        local qDungeon = ''
        local dungeonName = ''
        for _, frame in next, LFT.availableDungeons do
            if _G["Dungeon_" .. frame.code]:GetChecked() then
                qDungeon = frame.code
            end
        end
        if qDungeon == '' then
            return false --do nothing
        end

        dungeonName = LFT.dungeonNameFromCode(qDungeon)

        if LFT.dungeons[dungeonName].canQueue then
            findMore()
        else
            lfprint('A member of your group does not meet the suggested minimum level requirement for |cff69ccf0' .. dungeonName)
        end
    end
end

function LFT.enableDungeonCheckButtons()
    for _, frame in next, LFT.availableDungeons do
        _G["Dungeon_" .. frame.code]:Enable()
    end
end

function LFT.disableDungeonCheckButtons(except)
    for _, frame in next, LFT.availableDungeons do
        if except and except == frame.code then
            --dont disable
        else
            _G["Dungeon_" .. frame.code]:Disable()
        end
    end
end

function LFT.resetGroup()
    LFT.group = {};
    if not LFT.oneGroupFull then
        LFT.groupFullCode = ''
        LFT.oneGroupFull = false
    end
    LFT.acceptNextInvite = false
    LFT.onlyAcceptFrom = ''
    LFT.foundGroup = false

    LFT.isLeader = IsPartyLeader()
    LFT.inGroup = GetNumRaidMembers() == 0 and GetNumPartyMembers() > 0

    LFTGroupReadyFrameCloser.response = ''

    for _, data in next, LFT.dungeons do
        if data.queued then
            local tank = ''
            if LFT_ROLE == 'tank' then
                tank = me
            end
            LFT.group[data.code] = {
                tank = tank,
                healer = '',
                damage1 = '',
                damage2 = '',
                damage3 = '',
            }
        end
    end
    LFT.myRandomTime = math.random(LFT.random_min, LFT.random_max)
    LFT.LFMGroup = {
        tank = '',
        healer = '',
        damage1 = '',
        damage2 = '',
        damage3 = '',
    }
end

function LFT.addTank(dungeon, name, faux, add)

    if LFT.group[dungeon].tank == '' then
        if add then
            LFT.group[dungeon].tank = name
        end
        if not faux then
            --SendChatMessage('found:tank:' .. dungeon .. ':' .. name, "CHANNEL", DEFAULT_CHAT_FRAME.editBox.languageID, GetChannelName(LFT.channel))
        end
        return true
    end
    return false
end

function LFT.addHealer(dungeon, name, faux, add)
    --prevent adding same person twice
    if LFT.group[dungeon].healer == name then
        return false
    end

    if LFT.group[dungeon].healer == '' then
        if add then
            LFT.group[dungeon].healer = name
        end
        if not faux then
            --SendChatMessage('found:healer:' .. dungeon .. ':' .. name, "CHANNEL", DEFAULT_CHAT_FRAME.editBox.languageID, GetChannelName(LFT.channel))
        end
        return true
    end
    return false
end

function LFT.remHealerOrDamage(dungeon, name)
    if LFT.group[dungeon].healer == name then
        LFT.group[dungeon].healer = ''
    end
    if LFT.group[dungeon].damage1 == name then
        LFT.group[dungeon].damage1 = ''
    end
    if LFT.group[dungeon].damage2 == name then
        LFT.group[dungeon].damage2 = ''
    end
    if LFT.group[dungeon].damage3 == name then
        LFT.group[dungeon].damage3 = ''
    end
end

function LFT.addDamage(dungeon, name, faux, add)

    --prevent adding same person twice
    if LFT.group[dungeon].damage1 == name or
            LFT.group[dungeon].damage2 == name or
            LFT.group[dungeon].damage3 == name then
        return false
    end

    if LFT.group[dungeon].damage1 == '' then
        if add then
            LFT.group[dungeon].damage1 = name
        end
        if not faux then
            --            SendChatMessage('found:damage:' .. dungeon .. ':' .. name, "CHANNEL", DEFAULT_CHAT_FRAME.editBox.languageID, GetChannelName(LFT.channel))
        end
        return true
    elseif LFT.group[dungeon].damage2 == '' then
        if add then
            LFT.group[dungeon].damage2 = name
        end
        if not faux then
            --            SendChatMessage('found:damage:' .. dungeon .. ':' .. name, "CHANNEL", DEFAULT_CHAT_FRAME.editBox.languageID, GetChannelName(LFT.channel))
        end
        return true
    elseif LFT.group[dungeon].damage3 == '' then
        if add then
            LFT.group[dungeon].damage3 = name
        end
        if not faux then
            --            SendChatMessage('found:damage:' .. dungeon .. ':' .. name, "CHANNEL", DEFAULT_CHAT_FRAME.editBox.languageID, GetChannelName(LFT.channel))
        end
        return true
    end
    return false --group full on damage
end

function LFT.checkGroupFull()

    for _, data in next, LFT.dungeons do
        if data.queued then
            local members = 0
            if LFT.group[data.code].tank ~= '' then
                members = members + 1
            end
            if LFT.group[data.code].healer ~= '' then
                members = members + 1
            end
            if LFT.group[data.code].damage1 ~= '' then
                members = members + 1
            end
            if LFT.group[data.code].damage2 ~= '' then
                members = members + 1
            end
            if LFT.group[data.code].damage3 ~= '' then
                members = members + 1
            end
            lfdebug('members = ' .. members .. ' (' .. LFT.group[data.code].tank ..
                    ',' .. LFT.group[data.code].healer .. ',' .. LFT.group[data.code].damage1 ..
                    ',' .. LFT.group[data.code].damage2 .. ',' .. LFT.group[data.code].damage3 .. ')')
            if members == LFT.groupSizeMax then
                LFT.oneGroupFull = true
                LFT.group[data.code].full = true

                return true, data.code, LFT.group[data.code].healer, LFT.group[data.code].damage1, LFT.group[data.code].damage2, LFT.group[data.code].damage3
            else
                LFT.group[data.code].full = false
                LFT.oneGroupFull = false
            end
        end
    end

    return false, false, nil, nil, nil, nil
end

function LFT.dungeonNameFromCode(code)
    for name, data in next, LFT.dungeons do
        if data.code == code then
            return name, data.background
        end
    end
    return 'Unknown', 'UnknownBackground'
end

function LFT.dungeonFromCode(code)
    for _, data in next, LFT.dungeons do
        if data.code == code then
            return data
        end
    end
    return false
end

function LFT.AcceptGroupInvite()
    AcceptGroup()
    StaticPopup_Hide("PARTY_INVITE")
    PlaySoundFile("Sound\\Doodad\\BellTollNightElf.wav")
    UIErrorsFrame:AddMessage("[LFT] Group Auto Accept")
end

function LFT.DeclineGroupInvite()
    DeclineGroup()
    StaticPopup_Hide("PARTY_INVITE")
end

function LFT.fuckingSortAlready(t)
    local a = {}
    for n, l in pairs(t) do
        table.insert(a, { ['code'] = l.code, ['minLevel'] = l.minLevel, ['name'] = n })
    end
    table.sort(a, function(a, b)
        return a['minLevel'] < b['minLevel']
    end)
    local i = 0 -- iterator variable
    local iter = function()
        -- iterator function
        i = i + 1
        if a[i] == nil then
            return nil
            --        else return a[i]['code'], t[a[i]['name']]
        else
            return a[i]['name'], t[a[i]['name']]
        end
    end
    return iter
end

function LFT.tableSize(t)
    local size = 0
    for _, _ in next, t do
        size = size + 1
    end
    return size
end

function LFT.checkLFMgroup(someoneDeclined)

    if someoneDeclined then
        if someoneDeclined ~= me then
            lfprint(LFT.classColors[LFT.playerClass(someoneDeclined)].c .. someoneDeclined .. COLOR_WHITE .. ' declined role check.')
            lfdebug('LFTRoleCheck:Hide() in checkLFMgroup someone declined')
            LFTRoleCheck:Hide()
        end
        return false
    end

    if not LFT.isLeader then
        return
    end

    local currentGroupSize = GetNumPartyMembers() + 1
    local readyNumber = 0
    if LFT.LFMGroup.tank ~= '' then
        readyNumber = readyNumber + 1
    end
    if LFT.LFMGroup.healer ~= '' then
        readyNumber = readyNumber + 1
    end
    if LFT.LFMGroup.damage1 ~= '' then
        readyNumber = readyNumber + 1
    end
    if LFT.LFMGroup.damage2 ~= '' then
        readyNumber = readyNumber + 1
    end
    if LFT.LFMGroup.damage3 ~= '' then
        readyNumber = readyNumber + 1
    end

    if currentGroupSize == readyNumber then
        LFT.findingMore = true
        lfdebug('group ready ? ' .. currentGroupSize .. ' = ' .. readyNumber)
        --lfdebug(LFT.LFMGroup.tank)
        --lfdebug(LFT.LFMGroup.healer)
        --lfdebug(LFT.LFMGroup.damage1)
        --lfdebug(LFT.LFMGroup.damage2)
        --lfdebug(LFT.LFMGroup.damage3)
        --everyone is ready / confirmed roles

        LFT.group[LFT.LFMDungeonCode] = {
            tank = LFT.LFMGroup.tank,
            healer = LFT.LFMGroup.healer,
            damage1 = LFT.LFMGroup.damage1,
            damage2 = LFT.LFMGroup.damage2,
            damage3 = LFT.LFMGroup.damage3,
        }
        SendAddonMessage(LFT_ADDON_CHANNEL, "weInQueue:" .. LFT.LFMDungeonCode, "PARTY")
        lfdebug('LFTRoleCheck:Hide() in checkLFMGROUP we ready')
        LFTRoleCheck:Hide()
    end
end

function LFT.weInQueue(code)

    local dungeonName = LFT.dungeonNameFromCode(code)
    LFT.dungeons[dungeonName].queued = true

    lfprint('Your group is in the queue for |cff69ccf0' .. dungeonName)

    LFT.findingGroup = true
    LFT.findingMore = true
    LFT.disableDungeonCheckButtons()

    _G['RoleTank']:Disable()
    _G['RoleHealer']:Disable()
    _G['RoleDamage']:Disable()

    PlaySound('PvpEnterQueue')

    if LFT.isLeader then
        LFT.sendMinimapDataToParty(code)
    else
        LFT.group[code] = {
            tank = '',
            healer = '',
            damage1 = '',
            damage2 = '',
            damage3 = ''
        }
    end

    LFT.oneGroupFull = false
    LFT.queueStartTime = time()
    LFTQueue:Show()
    _G['LFTMain']:Hide()
    LFT.fixMainButton()
end

function LFT.fixMainButton()

    local lfgButton = _G['findGroupButton']
    local lfmButton = _G['findMoreButton']
    local leaveQueueButton = _G['leaveQueueButton']

    lfgButton:Hide()
    lfmButton:Hide()
    leaveQueueButton:Hide()

    lfgButton:Disable()
    lfmButton:Disable()
    leaveQueueButton:Disable()

    LFT.inGroup = GetNumRaidMembers() == 0 and GetNumPartyMembers() > 0

    local queues = 0
    for _, data in next, LFT.dungeons do
        if data.queued then
            queues = queues + 1
        end
    end

    if queues > 0 then
        lfgButton:Enable()
    end

    if LFT.inGroup then
        lfmButton:Show()
        --GetNumPartyMembers() returns party size-1, doesnt count myself
        if GetNumPartyMembers() < (LFT.groupSizeMax - 1) and LFT.isLeader and queues > 0 then
            lfmButton:Enable()
            if LFT.LFMDungeonCode ~= '' then
                LFT.disableDungeonCheckButtons(LFT.LFMDungeonCode)
            end
        end
        if GetNumPartyMembers() == (LFT.groupSizeMax - 1) and LFT.isLeader then
            --group full
            lfmButton:Disable()
            LFT.disableDungeonCheckButtons()
        end
        if not LFT.isLeader then
            lfmButton:Disable()
            LFT.disableDungeonCheckButtons()
        end
    else
        lfgButton:Show()
    end

    if LFT.findingGroup then
        leaveQueueButton:Show()
        leaveQueueButton:Enable()
        if LFT.inGroup then
            if not LFT.isLeader then
                leaveQueueButton:Disable()
            end
        end
        lfgButton:Hide()
        lfmButton:Hide()
    end

    if GetNumRaidMembers() > 0 then
        lfgButton:Disable()
        lfmButton:Disable()
        leaveQueueButton:Disable()
    end
end

function LFT.sendCancelMeMessage()
    ChatThrottleLib:SendChatMessage('ALERT', 'LFT',
            'leftQueue:' .. LFT_ROLE,
            "CHANNEL",
            DEFAULT_CHAT_FRAME.editBox.languageID,
            GetChannelName(LFT.channel))
end

function LFT.sendLFMessage()

    --v1
    --    local keyset = {}
    --    for k in pairs(LFT.group) do
    --        table.insert(keyset, k)
    --    end
    --
    --    local added = {}
    --    local spammedNr = 1
    --    for _, _ in next, LFT.group do
    --        local newD = keyset[math.random(LFT.tableSize(keyset))]
    --        if not added[newD] then
    --            added[newD] = true
    --            if spammedNr <= DEV_MAX_DUNGEONS_TO_SPAM then
    --                SendChatMessage('LFG:' .. newD .. ':' .. LFT_ROLE, "CHANNEL", DEFAULT_CHAT_FRAME.editBox.languageID, GetChannelName(LFT.channel))
    --                spammedNr = spammedNr + 1
    --            end
    --        else
    --        end
    --    end

    --v2
    local lfg_text = ''
    for code, _ in pairs(LFT.group) do
        --        if math.random(0, 1) == 1 then
        --            SendChatMessage('LFG:' .. code .. ':' .. LFT_ROLE, "CHANNEL", DEFAULT_CHAT_FRAME.editBox.languageID, GetChannelName(LFT.channel))
        --        ChatThrottleLib:SendChatMessage('ALERT', 'LFT',
        --            'LFG:' .. code .. ':' .. LFT_ROLE,
        --            "CHANNEL",
        --            DEFAULT_CHAT_FRAME.editBox.languageID,
        --            GetChannelName(LFT.channel))
        --        end
        lfg_text = 'LFG:' .. code .. ':' .. LFT_ROLE .. ' ' .. lfg_text
    end
    lfg_text = string.sub(lfg_text, 1, string.len(lfg_text) - 1)
    ChatThrottleLib:SendChatMessage('ALERT', 'LFT',
            lfg_text,
            "CHANNEL",
            DEFAULT_CHAT_FRAME.editBox.languageID,
            GetChannelName(LFT.channel))
end

function LFT.isNeededInLFMGroup(role, name, code)

    if role == 'tank' and LFT.group[code].tank == '' then
        --        LFT.group[code].tank = name
        return true
    end
    if role == 'healer' and LFT.group[code].healer == '' then
        --        LFT.group[code].healer = name
        return true
    end
    if role == 'damage' then
        if LFT.group[code].damage1 == '' then
            --            LFT.group[code].damage1 = name
            return true
        end
        if LFT.group[code].damage2 == '' then
            --            LFT.group[code].damage2 = name
            return true
        end
        if LFT.group[code].damage3 == '' then
            --            LFT.group[code].damage3 = name
            return true
        end
    end
    return false
end

function LFT.inviteInLFMGroup(name)
    SendChatMessage("[LFT]:" .. LFT.LFMDungeonCode .. ":(LFM):" .. name, "CHANNEL", DEFAULT_CHAT_FRAME.editBox.languageID, GetChannelName(LFT.channel))
    InviteByName(name)
end

function LFT.checkLFMGroupReady(code)
    if not LFT.isLeader then
        return
    end

    local members = 0

    if LFT.group[code].tank ~= '' then
        members = members + 1
    end
    if LFT.group[code].healer ~= '' then
        members = members + 1
    end
    if LFT.group[code].damage1 ~= '' then
        members = members + 1
    end
    if LFT.group[code].damage2 ~= '' then
        members = members + 1
    end
    if LFT.group[code].damage3 ~= '' then
        members = members + 1
    end

    return members == LFT.groupSizeMax
end

function LFT.sendMinimapDataToParty(code)
    lfdebug('send minimap data to party code = ' .. code)
    if code == '' then
        return false
    end
    if not LFT.group[code] then
        return false
    end
    local tank, healer, damage = 0, 0, 0
    if LFT.group[code].tank ~= '' then
        tank = tank + 1
    end
    if LFT.group[code].healer ~= '' then
        healer = healer + 1
    end
    if LFT.group[code].damage1 ~= '' then
        damage = damage + 1
    end
    if LFT.group[code].damage2 ~= '' then
        damage = damage + 1
    end
    if LFT.group[code].damage3 ~= '' then
        damage = damage + 1
    end
    SendAddonMessage(LFT_ADDON_CHANNEL, "minimap:" .. code .. ":" .. tank .. ":" .. healer .. ":" .. damage, "PARTY")
end

function LFT.addOnEnterTooltip(frame, title, text1, text2)
    frame:SetScript("OnEnter", function()
        GameTooltip:SetOwner(this, "ANCHOR_RIGHT", -200, -5)
        GameTooltip:AddLine(title)
        if text1 then
            GameTooltip:AddLine(text1, 1, 1, 1)
        end
        if text2 then
            GameTooltip:AddLine(text2, 1, 1, 1)
        end
        GameTooltip:Show()
    end)
    frame:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
end

function LFT.removeOnEnterTooltip(frame)
    frame:SetScript("OnEnter", function()
    end)
    frame:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
end

function LFT.sendMyVersion()
    SendAddonMessage(LFT_ADDON_CHANNEL, "LFTVersion:" .. addonVer, "PARTY")
    SendAddonMessage(LFT_ADDON_CHANNEL, "LFTVersion:" .. addonVer, "GUILD")
    SendAddonMessage(LFT_ADDON_CHANNEL, "LFTVersion:" .. addonVer, "RAID")
    SendAddonMessage(LFT_ADDON_CHANNEL, "LFTVersion:" .. addonVer, "BATTLEGROUND")
end

function LFT.removePlayerFromVirtualParty(name, mRole)
    if not mRole then
        mRole = 'unknown'
    end
    for dungeonCode, data in next, LFT.group do
        if data.tank == name and (mRole == 'tank' or mRole == 'unknown') then
            LFT.group[dungeonCode].tank = ''
        end
        if data.healer == name and (mRole == 'healer' or mRole == 'unknown') then
            LFT.group[dungeonCode].healer = ''
        end
        if data.damage1 == name and (mRole == 'damage' or mRole == 'unknown') then
            LFT.group[dungeonCode].damage1 = ''
        end
        if data.damage2 == name and (mRole == 'damage' or mRole == 'unknown') then
            LFT.group[dungeonCode].damage2 = ''
        end
        if data.damage3 == name and (mRole == 'damage' or mRole == 'unknown') then
            LFT.group[dungeonCode].damage3 = ''
        end
    end
end

function LFT.deQueueAll()
    for _, data in next, LFT.dungeons do
        if data.queued then
            LFT.dungeons[data.code].queued = false
        end
    end
end

function LFT.resetFormedGroups()
    LFT_FORMED_GROUPS = {}
    for _, data in next, LFT.dungeons do
        LFT_FORMED_GROUPS[data.code] = 0
    end
end

function LFT.readyStatusReset()
    _G['LFTReadyStatusReadyTank']:SetTexture('Interface\\addons\\LFT\\images\\readycheck-waiting')
    _G['LFTReadyStatusReadyHealer']:SetTexture('Interface\\addons\\LFT\\images\\readycheck-waiting')
    _G['LFTReadyStatusReadyDamage1']:SetTexture('Interface\\addons\\LFT\\images\\readycheck-waiting')
    _G['LFTReadyStatusReadyDamage2']:SetTexture('Interface\\addons\\LFT\\images\\readycheck-waiting')
    _G['LFTReadyStatusReadyDamage3']:SetTexture('Interface\\addons\\LFT\\images\\readycheck-waiting')
end

function test_dung_ob(code)
    LFT.showDungeonObjectives(code)
end

--local dungIndex = 1

function LFT.showDungeonObjectives(code)
    --dev
    --    local j = 0
    --    for dungeon, data in next, LFT.dungeons do
    --        j = j + 1
    --        if j == dungIndex then
    --            LFT.groupFullCode = data.code --dev
    --        end
    --    end
    --
    --    local dungeonName, iconCode = LFT.dungeonNameFromCode(LFT.groupFullCode)
    --    _G['LFTDungeonCompleteIcon'):SetTexture('Interface\\addons\\LFT\\images\\icon\\lfgicon-' .. iconCode)
    --    _G['LFTDungeonCompleteDungeonName'):SetText(dungeonName)
    --    LFTDungeonComplete:Show()
    --
    --    dungIndex = dungIndex + 1
    if not code then
        --LFT.groupFullCode = 'scholo' --dev
    else
        --LFT.groupFullCode = code
    end
    --lfdebug(LFT.groupFullCode)
    --    end dev


    local dungeonName = LFT.dungeonNameFromCode(LFT.groupFullCode)
    LFTObjectives.objectivesComplete = 0

    --hideall
    for index, _ in next, LFT.objectivesFrames do
        if _G["LFTObjective" .. index] then
            _G["LFTObjective" .. index]:Hide()
        end
    end

    if LFT.dungeons[dungeonName] then
        if LFT.bosses[LFT.groupFullCode] then
            _G['LFTDungeonStatusDungeonName']:SetText(dungeonName)

            local index = 0
            for _, boss in next, LFT.bosses[LFT.groupFullCode] do
                index = index + 1
                if not LFT.objectivesFrames[index] then
                    LFT.objectivesFrames[index] = CreateFrame("Frame", "LFTObjective" .. index, _G['LFTDungeonStatus'], "LFTObjectiveBossTemplate")
                end
                LFT.objectivesFrames[index]:Show()
                LFT.objectivesFrames[index].name = boss
                LFT.objectivesFrames[index].code = LFT.groupFullCode

                if LFT.objectivesFrames[index].completed == nil then
                    LFT.objectivesFrames[index].completed = false
                end

                _G["LFTObjective" .. index .. 'Swoosh']:SetAlpha(0)
                _G["LFTObjective" .. index .. 'ObjectiveComplete']:Hide()
                _G["LFTObjective" .. index .. 'ObjectivePending']:Show()

                if LFT.objectivesFrames[index].completed then
                    _G["LFTObjective" .. index .. 'ObjectiveComplete']:Show()
                    _G["LFTObjective" .. index .. 'ObjectivePending']:Hide()
                else
                    _G["LFTObjective" .. index .. 'Objective']:SetText(COLOR_DISABLED .. '0/1 ' .. boss .. ' defeated')
                end

                LFT.objectivesFrames[index]:SetPoint("TOPLEFT", _G["LFTDungeonStatus"], "TOPLEFT", 10, -110 - 20 * (index))
            end

            _G["LFTDungeonStatusCollapseButton"]:Show()
            _G["LFTDungeonStatusExpandButton"]:Hide()
            _G["LFTDungeonStatus"]:Show()
        else
            _G["LFTDungeonStatus"]:Hide()
        end
    else
        _G["LFTDungeonStatus"]:Hide()
    end
end

function LFT.getDungeonCompletion()
    local completed = 0
    local total = 0
    for index, _ in next, LFT.objectivesFrames do
        if LFT.objectivesFrames[index].completed then
            completed = completed + 1
        end
        total = total + 1
    end
    if completed == 0 then
        return 0
    end
    return math.floor((completed * 100) / total)
end

-- XML called methods

function lft_replace(s, c, cc)
    return (string.gsub(s, c, cc))
end

function acceptRole()
    SendAddonMessage(LFT_ADDON_CHANNEL, "acceptRole:" .. LFT_ROLE, "PARTY")
    --    _G['LFTRoleCheck'):Hide() --moved in hide
    LFTRoleCheck:Hide()
end

function declineRole()
    SendAddonMessage(LFT_ADDON_CHANNEL, "declineRole:" .. LFT_ROLE, "PARTY")
    --    _G['LFTRoleCheck'):Hide() --move in hide
    LFTRoleCheck:Hide()
end

function LFT_Toggle()

    -- remove channel from every chat frame
    --for windowIndex = 1, 9 do
    --    local DefaultChannels = { GetChatWindowChannels(windowIndex) };
    --    for i, d in DefaultChannels do
    --        if d == LFT.channel then
    --            if getglobal("ChatFrame" .. windowIndex) then
    --                ChatFrame_RemoveChannel(getglobal("ChatFrame" .. windowIndex), LFT.channel); -- DEFAULT_CHAT_FRAME works well, too
    --                lfdebug('LFT channel removed from window ' .. windowIndex)
    --            end
    --        end
    --    end
    --end

    if LFT.level == 0 then
        LFT.level = UnitLevel('player')
    end
    if _G['LFTMain']:IsVisible() then
        _G['LFTMain']:Hide()
    else
        LFT.checkLFTChannel()
        if not LFT.findingGroup then
            LFT.fillAvailableDungeons()
        end

        _G['LFTMain']:Show()
        DungeonListFrame_Update()
    end
end

function sayReady()
    if LFT.inGroup and GetNumPartyMembers() + 1 == LFT.groupSizeMax then
        _G['LFTGroupReady']:Hide()
        SendAddonMessage(LFT_ADDON_CHANNEL, "readyAs:" .. LFT_ROLE, "PARTY")
        _G['LFT_MinimapEye']:SetTexture('Interface\\Addons\\LFT\\images\\eye\\battlenetworking0')
        _G['LFTReadyStatus']:Show()
        LFTGroupReadyFrameCloser.response = 'ready'
        _G['LFTGroupReadyAwesome']:Disable()
    end
end

function debugT()
    LFTGroupReadyFrameCloser:Show()
end

function sayNotReady()
    if LFT.inGroup and GetNumPartyMembers() + 1 == LFT.groupSizeMax then
        _G['LFTGroupReady']:Hide()
        SendAddonMessage(LFT_ADDON_CHANNEL, "notReadyAs:" .. LFT_ROLE, "PARTY")
        _G['LFT_MinimapEye']:SetTexture('Interface\\Addons\\LFT\\images\\eye\\battlenetworking0')
        _G['LFTReadyStatus']:Show()
        LFTGroupReadyFrameCloser.response = 'notReady'
    end
end

function LFTsetRole(role, status, readyCheck)
    local tankCheck = _G['RoleTank']
    local healerCheck = _G['RoleHealer']
    local damageCheck = _G['RoleDamage']

    --ready check window
    local readyCheckTank = _G['roleCheckTank']
    local readyCheckHealer = _G['roleCheckHealer']
    local readyCheckDamage = _G['roleCheckDamage']

    if role == 'tank' then
        readyCheckHealer:SetChecked(false)
        healerCheck:SetChecked(false)

        readyCheckDamage:SetChecked(false)
        damageCheck:SetChecked(false)
        if not status and not readyCheck then
            tankCheck:SetChecked(true)
        end
    end
    if role == 'healer' then
        readyCheckTank:SetChecked(false)
        tankCheck:SetChecked(false)

        readyCheckDamage:SetChecked(false)
        damageCheck:SetChecked(false)
        if not status and not readyCheck then
            healerCheck:SetChecked(true)
        end
    end
    if role == 'damage' then
        readyCheckTank:SetChecked(false)
        tankCheck:SetChecked(false)

        readyCheckHealer:SetChecked(false)
        healerCheck:SetChecked(false)
        if not status and not readyCheck then
            damageCheck:SetChecked(true)
        end
    end

    if readyCheck then
        tankCheck:SetChecked(readyCheckTank:GetChecked())
        healerCheck:SetChecked(readyCheckHealer:GetChecked())
        damageCheck:SetChecked(readyCheckDamage:GetChecked())
    else
        readyCheckTank:SetChecked(tankCheck:GetChecked())
        readyCheckHealer:SetChecked(healerCheck:GetChecked())
        readyCheckDamage:SetChecked(damageCheck:GetChecked())
    end
    LFT_ROLE = role
end

function DungeonListFrame_Update()
    local offset = FauxScrollFrame_GetOffset(_G['DungeonListScrollFrame']);
    LFT.fillAvailableDungeons(offset)
end

function DungeonType_OnLoad()
    UIDropDownMenu_Initialize(this, DungeonType_Initialize);
    UIDropDownMenu_SetWidth(160, LFTTypeSelect);
end

function DungeonType_OnClick(a)
    LFT_TYPE = a
    UIDropDownMenu_SetText(LFT.types[LFT_TYPE], _G['LFTTypeSelect'])
    _G['LFTDungeonsText']:SetText(LFT.types[LFT_TYPE])
    for dungeon, data in next, LFT.dungeons do
        if data.queued then
            if _G["Dungeon_" .. data.code] then
                _G["Dungeon_" .. data.code]:SetChecked(false)
            end
            LFT.dungeons[dungeon].queued = false
        end
    end
    LFT.fillAvailableDungeons()
end

function DungeonType_Initialize()
    for id, type in pairs(LFT.types) do
        local info = {}
        info.text = type
        info.value = id
        info.arg1 = id
        info.checked = LFT_TYPE == id
        info.func = DungeonType_OnClick
        if not LFT.findingGroup then
            UIDropDownMenu_AddButton(info)
        end
    end
end

function LFT_HideMinimap()
    for i, _ in LFT.minimapFrames do
        LFT.minimapFrames[i]:Hide()
    end
    _G['LFTGroupStatus']:Hide()
end

function LFT_ShowMinimap()

    if LFT.findingGroup or LFT.findingMore then
        local dungeonIndex = 0
        for dungeonCode, _ in next, LFT.group do
            local tank = 0
            local healer = 0
            local damage = 0

            if LFT.group[dungeonCode].tank ~= '' or (not LFT.inGroup and LFT_ROLE == 'tank') then
                tank = tank + 1
            end
            if LFT.group[dungeonCode].healer ~= '' or (not LFT.inGroup and LFT_ROLE == 'healer') then
                healer = healer + 1
            end
            if LFT.group[dungeonCode].damage1 ~= '' or (not LFT.inGroup and LFT_ROLE == 'damage') then
                damage = damage + 1
            end
            if LFT.group[dungeonCode].damage2 ~= '' then
                damage = damage + 1
            end
            if LFT.group[dungeonCode].damage3 ~= '' then
                damage = damage + 1
            end

            if not LFT.minimapFrames[dungeonCode] then
                LFT.minimapFrames[dungeonCode] = CreateFrame('Frame', "LFTMinimap_" .. dungeonCode, UIParent, "LFTMinimapDungeonTemplate")
            end

            local background = ''
            local dungeonName = 'unknown'
            for d, data2 in next, LFT.dungeons do
                if data2.code == dungeonCode then
                    background = data2.background
                    dungeonName = d
                end
            end

            LFT.minimapFrames[dungeonCode]:Show()
            LFT.minimapFrames[dungeonCode]:SetPoint("TOP", _G["LFTGroupStatus"], "TOP", 0, -25 - 46 * (dungeonIndex))
            _G['LFTMinimap_' .. dungeonCode .. 'Background']:SetTexture('Interface\\addons\\LFT\\images\\background\\ui-lfg-background-' .. background)
            _G['LFTMinimap_' .. dungeonCode .. 'DungeonName']:SetText(dungeonName)

            _G['LFTMinimap_' .. dungeonCode .. 'MyRole']:SetTexture('Interface\\addons\\LFT\\images\\ready_' .. LFT_ROLE)

            if tank == 0 then
                _G['LFTMinimap_' .. dungeonCode .. 'ReadyIconTank']:SetDesaturated(1)
            end
            if healer == 0 then
                _G['LFTMinimap_' .. dungeonCode .. 'ReadyIconHealer']:SetDesaturated(1)
            end
            if damage == 0 then
                _G['LFTMinimap_' .. dungeonCode .. 'ReadyIconDamage']:SetDesaturated(1)
            end
            _G['LFTMinimap_' .. dungeonCode .. 'NrTank']:SetText(tank .. '/1')
            _G['LFTMinimap_' .. dungeonCode .. 'NrHealer']:SetText(healer .. '/1')
            _G['LFTMinimap_' .. dungeonCode .. 'NrDamage']:SetText(damage .. '/3')

            dungeonIndex = dungeonIndex + 1
        end

        _G['LFTGroupStatus']:SetPoint("TOPRIGHT", _G["LFT_Minimap"], "BOTTOMLEFT", 0, 40)
        _G['LFTGroupStatus']:SetHeight(dungeonIndex * 46 + 95)
        _G['LFTGroupStatusTimeInQueue']:SetText('Time in Queue: ' .. SecondsToTime(time() - LFT.queueStartTime))
        if LFT.averageWaitTime == 0 then
            _G['LFTGroupStatusAverageWaitTime']:SetText('Average Wait Time: Unavailable')
        else
            _G['LFTGroupStatusAverageWaitTime']:SetText('Average Wait Time: ' .. SecondsToTimeAbbrev(LFT.averageWaitTime))
        end
        _G['LFTGroupStatus']:Show()
    else

        GameTooltip:SetOwner(this, "ANCHOR_LEFT", 0, -90)
        GameTooltip:AddLine('Looking For Turtles - LFT', 1, 1, 1)
        GameTooltip:AddLine('Left-click to toggle frame')
        GameTooltip:AddLine('Not queued for any dungeons.')
        GameTooltip:Show()
    end
end

function queueForFromButton(bCode)

    if true then
        return false
    end --dev, disabled for now

    local codeEx = string.split(bCode, '_')
    local qCode = codeEx[2]
    for code, data in next, LFT.availableDungeons do
        if code == qCode and not LFT.findingGroup then
            _G['Dungeon_' .. data.code]:SetChecked(not _G['Dungeon_' .. data.code]:GetChecked())
            queueFor(bCode, _G['Dungeon_' .. data.code]:GetChecked())
        end
    end
end

function queueFor(name, status)
    local dungeonCode = ''
    for dungeon, data in next, LFT.dungeons do
        local dung = string.split(name, '_')
        dungeonCode = dung[2]
        if dungeonCode == data.code then
            if status then
                LFT.dungeons[dungeon].queued = true
            else
                LFT.dungeons[dungeon].queued = false
            end
        end
    end

    local queues = 0
    for _, data in next, LFT.dungeons do
        if data.queued then
            queues = queues + 1
        end
    end

    if queues == 1 and LFT.inGroup then
        LFT.LFMDungeonCode = dungeonCode
        LFT.disableDungeonCheckButtons(dungeonCode)
    else
        LFT.enableDungeonCheckButtons()
        if queues >= LFT.maxDungeonsInQueue then

            for _, frame in next, LFT.availableDungeons do
                local dungeonName = LFT.dungeonNameFromCode(frame.code)
                if not LFT.dungeons[dungeonName].queued then
                    _G["Dungeon_" .. frame.code]:Disable()
                    _G['Dungeon_' .. frame.code .. 'Text']:SetText(COLOR_DISABLED .. dungeonName)
                    _G['Dungeon_' .. frame.code .. 'Levels']:SetText(COLOR_DISABLED .. '(' .. frame.minLevel .. ' - ' .. frame.maxLevel .. ')')
                    LFT.addOnEnterTooltip(_G['Dungeon_' .. frame.code .. '_Button'], 'Queueing for ' .. dungeonName .. ' is unavailable',
                            'Maximum allowed queued dungeons at a time is ' .. LFT.maxDungeonsInQueue .. '.')
                end
            end
        end
    end
    LFT.fixMainButton()
end

function findMore()

    -- find queueing dungeon
    local qDungeon = ''
    for _, frame in next, LFT.availableDungeons do
        if _G["Dungeon_" .. frame.code]:GetChecked() then
            qDungeon = frame.code
        end
    end

    LFT.LFMDungeonCode = qDungeon
    --    LFT.findingMore = true
    SendAddonMessage(LFT_ADDON_CHANNEL, "roleCheck:" .. qDungeon, "PARTY")

    LFT.fixMainButton()

    -- disable the button disable spam clicking it
    _G['findMoreButton']:Disable()
end

function findGroup()

    LFT.resetGroup()
    LFT.findingGroup = true
    LFTQueue:Show()

    LFT.disableDungeonCheckButtons()

    _G['RoleTank']:Disable()
    _G['RoleHealer']:Disable()
    _G['RoleDamage']:Disable()

    PlaySound('PvpEnterQueue')

    local dungeonsText = ''

    local roleColor = ''
    if LFT_ROLE == 'tank' then
        roleColor = COLOR_TANK
    end
    if LFT_ROLE == 'healer' then
        roleColor = COLOR_HEALER
    end
    if LFT_ROLE == 'damage' then
        roleColor = COLOR_DAMAGE
    end

    local lfg_text = ''
    for dungeon, data in next, LFT.dungeons do
        if data.queued then
            dungeonsText = dungeonsText .. dungeon .. ', '
            --            SendChatMessage('LFG:' .. data.code .. ':' .. LFT_ROLE, "CHANNEL", DEFAULT_CHAT_FRAME.editBox.languageID, GetChannelName(LFT.channel))
            --            ChatThrottleLib:SendChatMessage('ALERT', 'LFT',
            --                'LFG:' .. data.code .. ':' .. LFT_ROLE,
            --                "CHANNEL",
            --                DEFAULT_CHAT_FRAME.editBox.languageID,
            --                GetChannelName(LFT.channel))
            lfg_text = 'LFG:' .. data.code .. ':' .. LFT_ROLE .. ' ' .. lfg_text
        end
    end
    lfg_text = string.sub(lfg_text, 1, string.len(lfg_text) - 1)
    ChatThrottleLib:SendChatMessage('ALERT', 'LFT',
            lfg_text,
            "CHANNEL",
            DEFAULT_CHAT_FRAME.editBox.languageID,
            GetChannelName(LFT.channel))

    dungeonsText = string.sub(dungeonsText, 1, string.len(dungeonsText) - 2)
    lfprint('You are in the queue for |cff69ccf0' .. dungeonsText ..
            COLOR_WHITE .. ' as: ' .. roleColor .. LFT.ucFirst(LFT_ROLE))

    LFT.oneGroupFull = false
    LFT.queueStartTime = time()

    LFT.fixMainButton()

    if LFT.channelOwner and LFTTime.second ~= -1 then
        SendChatMessage('timeIs:' .. LFTTime.second, "CHANNEL", DEFAULT_CHAT_FRAME.editBox.languageID, GetChannelName(LFT.channel))
    end
end

function leaveQueue(callData)

    if callData then
        lfdebug('leaveQueue call in : ' .. callData)
    end
    lfdebug('_G[LFTGroupReady]:Hide()')
    _G['LFTGroupReady']:Hide()
    _G["LFTDungeonStatus"]:Hide()
    _G['LFTRoleCheck']:Hide()

    LFTGroupReadyFrameCloser:Hide()
    LFTGroupReadyFrameCloser.response = ''

    LFTQueue:Hide()
    LFTRoleCheck:Hide()
    lfdebug('LFTRoleCheck:Hide() in leaveQueue')

    local dungeonsText = ''

    --local color = COLOR_GREEN
    --if LFT.level == data.minLevel or LFT.level == data.minLevel + 1 then
    --    color = COLOR_RED
    --end
    --if LFT.level == data.minLevel + 2 or LFT.level == data.minLevel + 3 then
    --    color = COLOR_ORANGE
    --end
    --if LFT.level == data.minLevel + 4 or LFT.level == data.maxLevel + 5 then
    --    color = COLOR_GREEN
    --end
    --
    --if LFT.level > data.maxLevel then
    --    color = COLOR_GREEN
    --end

    for dungeon, data in next, LFT.dungeons do
        if data.queued then
            --            if LFT_TYPE == 2 then --random dungeon, dont uncheck if it comes here from the button
            if _G["Dungeon_" .. data.code] then
                _G["Dungeon_" .. data.code]:SetChecked(false)
            end
            LFT.dungeons[dungeon].queued = false
            dungeonsText = dungeonsText .. dungeon .. ', '
        end
    end

    dungeonsText = string.sub(dungeonsText, 1, string.len(dungeonsText) - 2)
    if dungeonsText == '' then
        dungeonsText = LFT.dungeonNameFromCode(LFT.LFMDungeonCode)
    end
    if LFT.findingGroup or LFT.findingMore then
        if LFT.inGroup then
            if LFT.isLeader then
                SendAddonMessage(LFT_ADDON_CHANNEL, "leaveQueue:now", "PARTY")
            end
            lfprint('Your group has left the queue for |cff69ccf0' .. dungeonsText .. COLOR_WHITE .. '.')
        else
            lfprint('You have left the queue for |cff69ccf0' .. dungeonsText .. COLOR_WHITE .. '.')
        end

        LFT.sendCancelMeMessage()
        LFT.findingGroup = false
        LFT.findingMore = false
    end

    LFT.enableDungeonCheckButtons()

    LFT.GetPossibleRoles()
    LFTsetRole(LFT_ROLE)

    if LFT.LFMDungeonCode ~= '' then
        if _G["Dungeon_" .. LFT.LFMDungeonCode] then
            _G["Dungeon_" .. LFT.LFMDungeonCode]:SetChecked(true)
            LFT.dungeons[LFT.dungeonNameFromCode(LFT.LFMDungeonCode)].queued = true
        end
        --        LFT.enableDungeonCheckButtons()
    end

    DungeonListFrame_Update()
    --LFT.fixMainButton() --disabled, DungeonListFrame_Update() fillAvailableDungeons, which calls fixMainButton
end

function LFTObjectives.objectiveComplete(bossName, dontSendToAll)
    local code = ''
    local objectivesString = ''
    for index, _ in next, LFT.objectivesFrames do
        if LFT.objectivesFrames[index].name == bossName then
            if not LFT.objectivesFrames[index].completed then
                LFT.objectivesFrames[index].completed = true

                LFTObjectives.objectivesComplete = LFTObjectives.objectivesComplete + 1

                _G["LFTObjective" .. index .. 'ObjectiveComplete']:Show()
                _G["LFTObjective" .. index .. 'ObjectivePending']:Hide()
                _G["LFTObjective" .. index .. 'Objective']:SetText(COLOR_WHITE .. '1/1 ' .. bossName .. ' defeated')

                LFTObjectives.lastObjective = index
                LFTObjectives:Show()
                code = LFT.objectivesFrames[index].code

            else
            end
        end
        if LFT.objectivesFrames[index].completed then
            objectivesString = objectivesString .. '1-'
        else
            objectivesString = objectivesString .. '0-'
        end
    end

    if code ~= '' then
        if not dontSendToAll then
            --lfdebug("send " .. "objectives:" .. code .. ":" .. objectivesString)
            SendAddonMessage(LFT_ADDON_CHANNEL, "objectives:" .. code .. ":" .. objectivesString, "PARTY")
        end

        --dungeon complete ?
        local dungeonName, iconCode = LFT.dungeonNameFromCode(code)
        if LFTObjectives.objectivesComplete == LFT.tableSize(LFT.objectivesFrames) or
                (code == 'brdarena' and LFTObjectives.objectivesComplete == 1) then
            _G['LFTDungeonCompleteIcon']:SetTexture('Interface\\addons\\LFT\\images\\icon\\lfgicon-' .. iconCode)
            _G['LFTDungeonCompleteDungeonName']:SetText(dungeonName)
            LFTDungeonComplete.dungeonInProgress = false
            LFTDungeonComplete:Show()
            LFTObjectives.closedByUser = false
        else
            LFTDungeonComplete.dungeonInProgress = true
        end
    end
end

function toggleDungeonStatus_OnClick()
    LFTObjectives.collapsed = not LFTObjectives.collapsed
    if LFTObjectives.collapsed then
        _G["LFTDungeonStatusCollapseButton"]:Hide()
        _G["LFTDungeonStatusExpandButton"]:Show()
    else
        _G["LFTDungeonStatusCollapseButton"]:Show()
        _G["LFTDungeonStatusExpandButton"]:Hide()
    end
    for index, _ in next, LFT.objectivesFrames do
        if LFTObjectives.collapsed then
            _G["LFTObjective" .. index]:Hide()
        else
            _G["LFTObjective" .. index]:Show()
        end
    end
end



-- slash commands

SLASH_LFT1 = "/lft"
SlashCmdList["LFT"] = function(cmd)
    if cmd then
        if string.sub(cmd, 1, 3) == 'who' then
            if LFT.channelIndex == 0 then
                lfprint('LFT.channelIndex = 0, please try again in 10 seconds')
                return false
            end
            LFTWhoCounter:Show()
            SendChatMessage('whoLFT:' .. addonVer, "CHANNEL", DEFAULT_CHAT_FRAME.editBox.languageID, GetChannelName(LFT.channel))
        end
        if string.sub(cmd, 1, 17) == 'resetformedgroups' then
            LFT.resetFormedGroups()
            lfprint('Formed groups history reset.')
        end
        if string.sub(cmd, 1, 12) == 'formedgroups' then
            for code, number in next, LFT_FORMED_GROUPS do
                if number ~= 0 then
                    lfprint(number .. ' - ' .. LFT.dungeonNameFromCode(code))
                end
            end
        end
        if string.sub(cmd, 1, 5) == 'debug' then
            LFT_DEBUG = not LFT_DEBUG
            if LFT_DEBUG then
                lfprint('debug enabled')
                _G['LFTTitleTime']:Show()
            else
                lfprint('debug disabled')
                _G['LFTTitleTime']:Hide()
            end
        end
        if string.sub(cmd, 1, 9) == 'advertise' then
            LFT.sendAdvertisement("PARTY")
        end
        if string.sub(cmd, 1, 8) == 'sayguild' then
            LFT.sendAdvertisement("GUILD")
        end
    end
end

function LFT.sendAdvertisement(chan)
    SendChatMessage('I am using LFT - Looking For Turtles - LFG Addon for Turtle WoW v' .. addonVer, chan, DEFAULT_CHAT_FRAME.editBox.languageID)
    SendChatMessage('Get it at: https://github.com/CosminPOP/LFT', chan, DEFAULT_CHAT_FRAME.editBox.languageID)
end

-- dungeons

LFT.dungeons = {
    ['Ragefire Chasm'] = { minLevel = 13, maxLevel = 18, code = 'rfc', queued = false, canQueue = true, background = 'ragefirechasm' },
    ['Wailing Caverns'] = { minLevel = 17, maxLevel = 24, code = 'wc', queued = false, canQueue = true, background = 'wailingcaverns' },
    ['The Deadmines'] = { minLevel = 19, maxLevel = 24, code = 'dm', queued = false, canQueue = true, background = 'deadmines' },
    ['Shadowfang Keep'] = { minLevel = 22, maxLevel = 30, code = 'sfk', queued = false, canQueue = true, background = 'shadowfangkeep' },
    ['The Stockade'] = { minLevel = 22, maxLevel = 30, code = 'stocks', queued = false, canQueue = true, background = 'stormwindstockades' },
    ['Blackfathom Deeps'] = { minLevel = 23, maxLevel = 32, code = 'bfd', queued = false, canQueue = true, background = 'blackfathomdeeps' },
    ['Scarlet Monastery Graveyard'] = { minLevel = 27, maxLevel = 36, code = 'smgy', queued = false, canQueue = true, background = 'scarletmonastery' },
    ['Scarlet Monastery Library'] = { minLevel = 28, maxLevel = 39, code = 'smlib', queued = false, canQueue = true, background = 'scarletmonastery' },
    ['Gnomeregan'] = { minLevel = 29, maxLevel = 38, code = 'gnomer', queued = false, canQueue = true, background = 'gnomeregan' },
    ['Razorfen Kraul'] = { minLevel = 29, maxLevel = 38, code = 'rfk', queued = false, canQueue = true, background = 'razorfenkraul' },
    ['Scarlet Monastery Armory'] = { minLevel = 32, maxLevel = 41, code = 'smarmory', queued = false, canQueue = true, background = 'scarletmonastery' },
    ['Scarlet Monastery Cathedral'] = { minLevel = 35, maxLevel = 45, code = 'smcath', queued = false, canQueue = true, background = 'scarletmonastery' },
    ['Razorfen Downs'] = { minLevel = 36, maxLevel = 46, code = 'rfd', queued = false, canQueue = true, background = 'razorfendowns' },
    ['Zul\'Farrak'] = { minLevel = 44, maxLevel = 54, code = 'zf', queued = false, canQueue = true, background = 'zulfarak' },
    ['Maraudon Orange'] = { minLevel = 47, maxLevel = 55, code = 'maraorange', queued = false, canQueue = true, background = 'maraudon' },
    ['Maraudon Purple'] = { minLevel = 47, maxLevel = 55, code = 'marapurple', queued = false, canQueue = true, background = 'maraudon' },
    ['Maraudon Princess'] = { minLevel = 47, maxLevel = 55, code = 'maraprincess', queued = false, canQueue = true, background = 'maraudon' },
    ['Uldaman'] = { minLevel = 50, maxLevel = 51, code = 'ulda', queued = false, canQueue = true, background = 'uldaman' },
    ['Temple of Atal\'Hakkar'] = { minLevel = 50, maxLevel = 60, code = 'st', queued = false, canQueue = true, background = 'sunkentemple' },
    ['Blackrock Depths'] = { minLevel = 52, maxLevel = 60, code = 'brd', queued = false, canQueue = true, background = 'blackrockdepths' },
    ['Blackrock Depths Arena'] = { minLevel = 52, maxLevel = 60, code = 'brdarena', queued = false, canQueue = true, background = 'blackrockdepths' },
    ['Blackrock Depths Emperor'] = { minLevel = 52, maxLevel = 60, code = 'brdemp', queued = false, canQueue = true, background = 'blackrockdepths' },
    ['Lower Blackrock Spire'] = { minLevel = 55, maxLevel = 60, code = 'lbrs', queued = false, canQueue = true, background = 'blackrockspire' },
    ['Dire Maul East'] = { minLevel = 55, maxLevel = 60, code = 'dme', queued = false, canQueue = true, background = 'diremaul' },
    ['Dire Maul North'] = { minLevel = 57, maxLevel = 60, code = 'dmn', queued = false, canQueue = true, background = 'diremaul' },
    ['Dire Maul West'] = { minLevel = 57, maxLevel = 60, code = 'dmw', queued = false, canQueue = true, background = 'diremaul' },
    ['Scholomance'] = { minLevel = 58, maxLevel = 60, code = 'scholo', queued = false, canQueue = true, background = 'scholomance' },
    ['Stratholme: Undead District'] = { minLevel = 58, maxLevel = 60, code = 'stratud', queued = false, canQueue = true, background = 'stratholme' },
    ['Stratholme: Scarlet Bastion'] = { minLevel = 58, maxLevel = 60, code = 'stratlive', queued = false, canQueue = true, background = 'stratholme' },
    --['GM Test'] = { minLevel = 1, maxLevel = 60, code = 'gmtest', queued = false, canQueue = true, background = 'stratholme' },
}

--needs work
LFT.bosses = {
    ['gmtest'] = {
        'Duros',
        'Draka',
    },
    ['rfc'] = {
        'Oggleflint',
        'Taragaman the Hungerer',
        'Jergosh the Invoker',
        'Bazzalan'
    },
    ['wc'] = {
        'Lord Cobrahn',
        'Lady Anacondra',
        'Kresh',
        'Lord Pythas',
        'Skum',
        'Lord Serpentis',
        'Verdan the Everliving',
        'Mutanus the Devourer',
    },
    ['dm'] = {
        'Rhahk\'zor',
        'Sneed',
        'Gilnid',
        'Mr. Smite',
        'Cookie',
        'Captain Greenskin',
        'Edwin VanCleef',
    },
    ['sfk'] = {
        'Rethilgore',
        'Razorclaw the Butcher',
        'Baron Silverlaine',
        'Commander Springvale',
        'Odo the Blindwatcher',
        'Fenrus the Devourer',
        'Wolf Master Nandos',
        'Archmage Arugal',
    },
    ['bfd'] = {
        'Ghamoo-ra',
        'Lady Sarevess',
        'Gelihast',
        'Lorgus Jett',
        'Baron Aquanis',
        'Twilight Lord Kelris',
        'Old Serra\'kis',
        'Aku\'mai',
    },
    ['stocks'] = {
        'Targorr the Dread',
        'Kam Deepfury',
        'Hamhock',
        'Bazil Thredd',
        'Dextren Ward',
    },
    ['gnomer'] = {
        'Grubbis',
        'Viscous Fallout',
        'Electrocutioner 6000',
        'Crowd Pummeler 9-60',
        'Mekgineer Thermaplugg',
    },
    ['rfk'] = {
        'Roogug',
        'Aggem Thorncurse',
        'Death Speaker Jargba',
        'Overlord Ramtusk',
        'Agathelos the Raging',
        'Charlga Razorflank',
    },
    ['smgy'] = {
        'Interrogator Vishas',
        'Bloodmage Thalnos',
    },
    ['smarmory'] = {
        'Herod'
    },
    ['smcath'] = {
        'High Inquisitor Fairbanks',
        'Scarlet Commander Mograine',
        'High Inquisitor Whitemane'
    },
    ['smlib'] = {
        'Houndmaster Loksey',
        'Arcanist Doan'
    },
    ['rfd'] = {
        'Tuten\'kash',
        'Mordresh Fire Eye',
        'Glutton',
        'Ragglesnout',
        'Amnennar the Coldbringer',
    },
    ['ulda'] = {
        'Revelosh',
        'Ironaya',
        'Obsidian Sentinel',
        'Ancient Stone Keeper',
        'Galgann Firehammer',
        'Grimlok',
        'Archaedas',
    },
    ['zf'] = {
        'Antu\'sul',
        'Theka the Martyr',
        'Witch Doctor Zum\'rah',
        'Sandfury Executioner',
        'Nekrum Gutchewer',
        'Sergeant Bly',
        'Hydromancer Velratha',
        'Ruuzlu',
        'Chief Ukorz Sandscalp',
    },
    ['maraorange'] = {
        'Noxxion',
        'Razorlash',
    },
    ['marapurple'] = {
        'Lord Vyletongue',
        'Celebras the Cursed',
    },
    ['maraprincess'] = {
        'Tinkerer Gizlock',
        'Landslide',
        'Rotgrip',
        'Princess Theradras',
    },
    ['st'] = {
        'Jammal\'an the Prophet',
        'Ogom the Wretched',
        'Dreamscythe',
        'Weaver',
        'Morphaz',
        'Hazzas',
        'Shade of Eranikus',
        'Atal\'alarion',
    },
    ['brd'] = {
        'Lord Roccor',
        'Bael\'Gar',
        'High Interrogator Gerstahn',
        'Houndmaster Grebmar',

        'Pyromancer Loregrain',
        'Fineous Darkvire',

        'General Angerforge',
        'Golem Lord Argelmach',

        'Lord Incendius',

        'Hurley Blackbreath',
        'Plugger Spazzring',
        'Ribbly Screwspigot',
        'Phalanx',

        'Warder Stilgiss',

        'Watchman Doomgrip',
        'Verek',

        'Ambassador Flamelash',
        'Magmus',
        'Emperor Dagran Thaurissan',
    },
    ['brdemp'] = {
        'General Angerforge',
        'Golem Lord Argelmach',
        'Emperor Dagran Thaurissan',
        'Magmus',
        'Ambassador Flamelash',
    },
    ['brdarena'] = {
        'Anub\'shiah-s', --summoned
        'Eviscerator-s', --summoned
        'Gorosh the Dervish-s', --summoned
        'Grizzle-s', --summoned
        'Hedrum the Creeper-s', --summoned
        'Ok\'thor the Breaker-s', --summoned
    },
    ['lbrs'] = {
        'Highlord Omokk',
        'Shadow Hunter Vosh\'gajin',
        'War Master Voone',
        'Mother Smolderweb',
        'Quartermaster Zigris',
        'Halycon',
        'Gizrul the Slavener',
        'Overlord Wyrmthalak',
    },
    ['ubrs'] = {
        'Pyroguard Emberseer',
        'Warchief Rend Blackhand',
        'The Beast',
        'General Drakkisath',
    },
    ['dme'] = {
        'Pusilin',
        'Zevrim Thornhoof',
        'Hydrospawn',
        'Lethtendris',
        'Alzzin the Wildshaper',
    },
    ['dmn'] = {
        'Guard Mol\'dar',
        'Stomper Kreeg',
        'Guard Fengus',
        'Guard Slip\'kik',
        'Captain Kromcrush',
        'King Gordok',
    },
    ['dmw'] = {
        'Tendris Warpwood',
        'Illyanna Ravenoak',
        'Magister Kalendris',
        'Immol\'thar',
        'Prince Tortheldrin',
    },
    ['scholo'] = {
        'Jandice Barov',
        'Rattlegore',
        'Ras Frostwhisper',
        'Instructor Malicia',
        'Doctor Theolen Krastinov',
        'Lorekeeper Polkelt',
        'The Ravenian',
        'Lord Alexei Barov',
        'Lady Illucia Barov',
        'Darkmaster Gandling',
    },
    ['stratlive'] = {
        'The Unforgiven',
        'Timmy the Cruel',
        'Malor the Zealous',
        'Cannon Master Willey',
        'Archivist Galford',
        'Balnazzar',
    },
    ['stratud'] = {
        'Nerub\'enkan',
        'Baroness Anastari',
        'Maleki the Pallid',
        'Magistrate Barthilas',
        'Ramstein the Gorger',
        'Baron Rivendare',
    }
};

-- utils

function LFT.playerClass(name)
    if name == me then
        local _, unitClass = UnitClass('player')
        return string.lower(unitClass)
    end
    for i = 1, GetNumPartyMembers() do
        if UnitName('party' .. i) then
            if name == UnitName('party' .. i) then
                local _, unitClass = UnitClass('party' .. i)
                return string.lower(unitClass)
            end
        end
    end
    return 'priest'
end

function LFT.ver(ver)
    return tonumber(string.sub(ver, 1, 1)) * 1000 +
            tonumber(string.sub(ver, 3, 3)) * 100 +
            tonumber(string.sub(ver, 5, 5)) * 10 +
            tonumber(string.sub(ver, 7, 7)) * 1
end

function LFT.ucFirst(a)
    return string.upper(string.sub(a, 1, 1)) .. string.lower(string.sub(a, 2, string.len(a)))
end

function string:split(delimiter)
    local result = {}
    local from = 1
    local delim_from, delim_to = string.find(self, delimiter, from)
    while delim_from do
        table.insert(result, string.sub(self, from, delim_from - 1))
        from = delim_to + 1
        delim_from, delim_to = string.find(self, delimiter, from)
    end
    table.insert(result, string.sub(self, from))
    return result
end
