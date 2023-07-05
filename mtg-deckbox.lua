DECKLIST_URI='https://raw.githubusercontent.com/r15ch13/tts/main/decks.json'
CARDSYMBOL_URI='https://raw.githubusercontent.com/r15ch13/tts/main/card-symbols/'
VERSION='2.0.0'
DEBUG=true

local STANDARD_COLORS = {R='Red', G='Green', U='Blue', B='Black', W='White', X='Multi', C='Colorless'}

function onLoad()
    self.setName('MTG Deckbox')
    self.setDescription('[i]MTG Deckbox[/i] v'..VERSION)
    self.addContextMenuItem('Reload', fetchDecks)
    local assets = {}
    local cardSymbols = {'WU', 'WB', 'BR', 'BG', 'UB', 'UR', 'RG', 'RW', 'GW', 'GU' }

    -- add standard colors to symbols
    for k,_ in pairs(STANDARD_COLORS) do
        table.insert(cardSymbols, k)
    end

    -- add symbol assets
    for _,symbol in pairs(cardSymbols) do
        table.insert(assets, {
            name = symbol,
            url = CARDSYMBOL_URI .. symbol ..'.png'
        })
    end

    self.UI.setCustomAssets(assets)
    drawUI()
    Wait.frames(function() fetchDecks() end, 2)
end

function drawUI(deckTable)
    local ui = {
        {
            tag='Panel',
            attributes={
                id='MTGDeckListe',
                position='0 80 215',
                rotation='180 180 0',
                width=1400,
                height=10
            },
            children={
                {
                    tag='TableLayout',
                    children=(deckTable or {})
                }
            }
        }
    }

    self.UI.setXmlTable(ui)
    return ui
end

function showStuff()
    self.UI.show('MTGDeckListe')
end

function fetchDecks()
    WebRequest.get(DECKLIST_URI, self, 'createDeckButtons')
end

---- This method has to be added to 'MTG Deck Loader' in order make this work!
-- function onLoadDeckURLButtonExternal(pc)
--     onLoadDeckURLButton(nil, pc, nil)
-- end

function getMTGDeckLoaderGuid()
    for i, o in pairs(getObjects()) do
        if(o.getName() == 'MTG Deck Loader [i]r15ch13[/i]') then
            return o.guid
        end
    end
    return nil
end

function createDeckButtons(response)
    if not(response.text) or response.text == '' then
        printToAll('[FF0000][i]MTG Deckbox[/i]: Could not load Deckbox! List is empty!')
        return
    end

    if response.response_code != 200 or response.is_error or not(response.text) then
        printToAll('[FF0000][i]MTG Deckbox[/i]: Could not load Deckbox!\nError: '..response.error..'\nURL: '..DECKLIST_URI)
        return
    end

    local ok, json = pcall(function () return JSON.decode(response.text) end)
    if not(ok) or json == nil then
        printToAll('[FF0000][i]MTG Deckbox[/i]: Could not read JSON Decklist! Formating issue?')
    end

    local maxDeckCount = 0
    local header = {
        tag='Row',
        id='deck-header',
        children={},
        attributes={
            preferredHeight=30
        }
    }

    for symbol,name in pairs(STANDARD_COLORS) do

        table.insert(header.children, {
            tag='Cell',
            children={
                {
                    tag='Button',
                    attributes={
                        icon=symbol,
                        text=name,
                        fontSize=20,
                        iconWidth=20,
                        textAlignment='MiddleLeft',
                        interactable=false,
                        colors='#C8C8C8|#C8C8C8|#C8C8C8'
                    }
                }
            }
        })

        print('MTG Deckbox: Loaded '..#json[symbol]..' '..name..' ('..symbol..') decks')
        -- get color with the most decks
        if #json[symbol] > maxDeckCount then
            maxDeckCount = #json[symbol]
        end

        -- sort each color by name
        table.sort(json[symbol], function (a, b)
            return a['name'] < b['name']
        end)
    end

    local deckTable = {header}

    for i=1,maxDeckCount do
        local row = {
            tag='Row',
            id='deck-row-'..i,
            children={},
            attributes={
                preferredHeight=30
            }
        }
        for symbol,name in pairs(STANDARD_COLORS) do
            local deck = json[symbol][i]
            if deck then
                table.insert(row.children, {
                    tag='Cell',
                    children={
                        {
                            tag='Button',
                            attributes={
                                icon=deck['color'],
                                text=deck['name'],
                                fontSize=20,
                                iconWidth=20,
                                textAlignment='MiddleLeft',
                                id='deck-cell-'..i..'-'..deck['color'],
                                url=deck['url'],
                                onClick=string.format('loadDeck', deck['url'])
                            }
                        }
                    }
                })
            else
                table.insert(row.children, {tag='Cell'})
            end
        end
        table.insert(deckTable, row)
    end

    Wait.frames(function() drawUI(deckTable) end, 2)
    Wait.frames(function() self.UI.show('MTGDeckListe') end, 2)
end

function loadDeck(player, btn, id)
    if(btn != '-1') then
        return
    end

    local url = self.UI.getAttribute(id, 'url')

    mtgimp_guid = getMTGDeckLoaderGuid()
    if(mtgimp_guid == nil) then
        broadcastToAll('Please add a \'MTG Deck Loader [i]r15ch13[/i]\' to the table!')
        return
    end

    mtgimp = getObjectFromGUID(mtgimp_guid)

    for i, input in pairs(mtgimp.getInputs()) do
        if input.label == 'Enter deck URL, or load from Notebook.' then
            mtgimp.editInput({
                index = input.index,
                value = url
            })
            mtgimp.call('onLoadDeckURLButtonExternal', player.color)
            mtgimp.editInput({
                index = input.index,
                value = ''
            })
        end
    end

end