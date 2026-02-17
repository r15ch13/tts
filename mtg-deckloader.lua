-- this thingy has been modified by π for his table
-- if you take it and try to use it AS-IS it might not work and break other stuff on your table
-- get the vanilla version from the original un-modified mod here, by Omes:
-- https://steamcommunity.com/sharedfiles/filedetails/?id=2163084841
-- if you do take my modified version, please let me know

------ CONSTANTS
TAPPEDOUT_BASE_URL = "https://tappedout.net/mtg-decks/"
TAPPEDOUT_URL_SUFFIX = "/"
TAPPEDOUT_URL_MATCH = "tappedout%.net"

ARCHIDEKT_BASE_URL = "https://archidekt.com/api/decks/"
ARCHIDEKT_URL_SUFFIX = "/small/"
ARCHIDEKT_URL_MATCH = "archidekt%.com"

GOLDFISH_BASE_URL = 'https://www.mtggoldfish.com/deck/arena_download/'
GOLDFISH_URL_SUFFIX = '/'
GOLDFISH_URL_MATCH = "mtggoldfish%.com"

MOXFIELD_BASE_URL = "https://api.moxfield.com/v2/decks/all/"
MOXFIELD_URL_SUFFIX = "/"
MOXFIELD_URL_MATCH = "moxfield%.com"

DECKSTATS_URL_SUFFIX = "?include_comments=1&export_mtgarena=1"
DECKSTATS_URL_MATCH = "deckstats%.net"

SCRYFALL_URL_MATCH = "scryfall%.com"

SCRYFALL_ID_BASE_URL = "https://api.scryfall.com/cards/"
SCRYFALL_MULTIVERSE_BASE_URL = "https://api.scryfall.com/cards/multiverse/"
SCRYFALL_SET_NUM_BASE_URL = "https://api.scryfall.com/cards/"
SCRYFALL_SEARCH_BASE_URL = "https://api.scryfall.com/cards/search/?q="
SCRYFALL_NAME_BASE_URL = "https://api.scryfall.com/cards/named/?exact="

DECK_SOURCE_URL = "url"
DECK_SOURCE_NOTEBOOK = "notebook"

USER_AGENT = "Tabletop Simulator/1.0 MTG-Deckloader/1.0"

MAINDECK_POSITION_OFFSET = {0.0, 1, 0.1286}
DOUBLEFACE_POSITION_OFFSET = {1.47, 1, 0.1286}
SIDEBOARD_POSITION_OFFSET = {-1.47, 1, 0.1286}
COMMANDER_POSITION_OFFSET = {0.7286, 1, -0.8257}
TOKENS_POSITION_OFFSET = {-0.7286, 1, -0.8257}

-- pieHere, swapped for "my" cardBack
DEFAULT_CARDBACK = "https://steamusercontent-a.akamaihd.net/ugc/1647720103762682461/35EF6E87970E2A5D6581E7D96A99F8A575B7A15F/"
DEFAULT_LANGUAGE = "en"

DEFAULT_QUALITY = "large"

-- image_uris_keys={
--   'small',
--   'normal',
--   'large',
--   'png'
-- }

LANGUAGES = {
    ["en"] = "en",
    ["es"] = "es",
    ["sp"] = "sp",
    ["fr"] = "fr",
    ["de"] = "de",
    ["it"] = "it",
    ["pt"] = "pt",
    ["ja"] = "ja",
    ["jp"] = "ja",
    ["ko"] = "ko",
    ["kr"] = "ko",
    ["ru"] = "ru",
    ["zcs"] = "zcs",
    ["cs"] = "zcs",
    ["zht"] = "zht",
    ["ph"] = "ph",
    ["english"] = "en",
    ["spanish"] = "es",
    ["french"] = "fr",
    ["german"] = "de",
    ["italian"] = "it",
    ["portugese"] = "pt",
    ["japanese"] = "ja",
    ["korean"] = "ko",
    ["russian"] = "ru",
    ["chinese"] = "zhs",
    ["simplified chinese"] = "zhs",
    ["traditional chinese"] = "zht",
    ["phyrexian"] = "ph"
}

------ UI IDs
UI_ADVANCED_PANEL = "MTGDeckLoaderAdvancedPanel"
UI_CARD_BACK_INPUT = "MTGDeckLoaderCardBackInput"
UI_LANGUAGE_INPUT = "MTGDeckLoaderLanguageInput"
UI_FORCE_LANGUAGE_TOGGLE = "MTGDeckLoaderForceLanguageToggleID"
UI_COMBINE_DFC = "MTGDeckLoaderDFCStateToggleID"

------ GLOBAL STATE
lock = false
playerColor = nil
deckSource = nil
advanced = false
cardBackInput = ""
languageInput = ""
forceLanguage = false
combineStates = true
cardTokenDat = true

------ UTILITY
local function trim(s)
    if not s then return "" end

    local n = s:find"%S"
    return n and s:match(".*%S", n) or ""
end

local function iterateLines(s)
    if not s or string.len(s) == 0 then
        return ipairs({})
    end

    if s:sub(-1) ~= '\n' then
        s = s .. '\n'
    end

    local pos = 1
    return function ()
        if not pos then return nil end

        local p1, p2 = s:find("\r?\n", pos)

        local line
        if p1 then
            line = s:sub(pos, p1 - 1)
            pos = p2 + 1
        else
            line = s:sub(pos)
            pos = nil
        end

        return line
    end
end

local function underline(s)
    if not s or string.len(s) == 0 then
        return ""
    end

    return s .. '\n' .. string.rep('-', string.len(s)) .. '\n'
end

local function shallowCopyTable(t)
    if type(t) == 'table' then
        local copy = {}
        for key, val in pairs(t) do
            copy[key] = val
        end

        return copy
    end

    return {}
end

local function readNotebookForColor(playerColor)
    for i, tab in ipairs(Notes.getNotebookTabs()) do
        if tab.title == playerColor and tab.color == playerColor then
            return tab.body
        end
    end

    return nil
end

local function vecSum(v1, v2)
    return {v1[1] + v2[1], v1[2] + v2[2], v1[3] + v2[3]}
end

local function vecMult(v, s)
    return {v[1] * s, v[2] * s, v[3] * s}
end

local function valInTable(table, v)
    for _, value in ipairs(table) do
        if value == v then
            return true
        end
    end

    return false
end

local function printErr(s)
    printToColor(s, playerColor, {r=1, g=0, b=0})
end

local function printInfo(s)
    printToColor(s, playerColor)
end

------ CARD SPAWNING

-- Spawns a deck named [name] containing the given [cards] at [position].
-- Deck will be face down if [flipped].
-- Calls [onFullySpawned] when the object is spawned.
local function spawnDeck(cards, name, position, flipped, onFullySpawned, onError)

    local rotation
    if flipped then
        rotation = vecSum(self.getRotation(), {0, 0, 180})
    else
        rotation = self.getRotation()
    end

    local cardObjects = {}
    local sem = 0
    local function incSem() sem = sem + 1 end
    local function decSem() sem = sem - 1 end

    local n=0
    for _, card in ipairs(cards) do
        for i=1,(card.count or 1) do
            if not card.faces or not card.faces[1] then
                card.faces = {{
                    name = card.name,
                    oracleText = "Card not found",
                    imageURI = "https://vignette.wikia.nocookie.net/yugioh/images/9/94/Back-Anime-2.png/revision/latest?cb=20110624090942",
                }}
            end
            incSem()
            n=n+1
            local cardDat={
              Transform={posX=0,posY=0,posZ=0,rotX=0,rotY=0,rotZ=0,scaleX=1,scaleY=1,scaleZ=1},
              Name="Card",
              Nickname=card.faces[1].name,
              Description=card.faces[1].oracleText,
              Memo=card.oracleID,
              CardID=n*100,
              CustomDeck={[n]={FaceURL=card.faces[1].imageURI,BackURL=getCardBack(),NumWidth=1,NumHeight=1,Type=0,BackIsHidden=true,UniqueBack=false}},
              LuaScriptState=card.all_parts_json,
              LuaScript=card.all_parts_json=='' and '' or cardScript
            }

            local type_line = card.faces[1].name:match("\n(.*)\n")
            if type_line:match('[Bb]attle') then
              cardDat.AltLookAngle={0,180,270}
            end

            if card.faces[2] then
              n=n+1
              local backDat={
                Transform={posX=0,posY=0,posZ=0,rotX=0,rotY=0,rotZ=0,scaleX=1,scaleY=1,scaleZ=1},
                Name="Card",
                Nickname=card.faces[2].name,
                Description=card.faces[2].oracleText,
                Memo=card.oracleID,
                CardID=n*100,
                CustomDeck={[n]={FaceURL=card.faces[2].imageURI,BackURL=getCardBack(),NumWidth=1,NumHeight=1,Type=0,BackIsHidden=true,UniqueBack=false}},
                LuaScriptState=card.all_parts_json,
                LuaScript=card.all_parts_json=='' and '' or cardScript
              }
              if combineStates then    -- set card state
                cardDat.States={[2]=backDat}
                table.insert(cardObjects,cardDat)
              else
                table.insert(cardObjects,cardDat)
                table.insert(cardObjects,backDat)
              end
            else
              table.insert(cardObjects,cardDat)
            end
            decSem()
        end
    end

    if #cardObjects==1 then
        spawnDat={
            data = cardObjects[1],
            position = position,
            rotation = rotation,
        }
        spawnObjectData(spawnDat)
    elseif #cardObjects>1 then
        local deckDat={
            Transform={posX=0,posY=0,posZ=0,rotX=0,rotY=0,rotZ=0,scaleX=1,scaleY=1,scaleZ=1},
            Name="Deck",
            Nickname=name,
            Description="",
            DeckIDs={},
            CustomDeck={},
            ContainedObjects={},
        }
        for i,cardDat in ipairs(cardObjects) do
            local n=cardDat.CardID/100
            deckDat.DeckIDs[i]=cardDat.CardID
            deckDat.CustomDeck[n]=cardDat.CustomDeck[n]
            deckDat.ContainedObjects[i]=cardDat
        end
        spawnDat={
            data = deckDat,
            position = position,
            rotation = rotation,
        }
        deckObject=spawnObjectData(spawnDat)
    end
    onFullySpawned(deckObject)

end

------ SCRYFALL
local function stripScryfallImageURI(uri)
    if not uri or string.len(uri) == 0 then
        return ""
    end

    return uri:match("(.*)%?") or ""
end

-- Returns a nicely formatted card name with type_line and cmc
local function getAugmentedName(cardData,i)

    local cmc = cardData.cmc

    if not cardData.cmc and cardData.card_faces[1].cmc then
      cmc = cardData.card_faces[1].cmc
    end

    if i then
      cardData=cardData.card_faces[i]
    end

    local name = cardData.name:gsub('"', '') or ""
    local type_line = cardData.type_line

    if not cardData.type_line then
      type_line = cardData.card_faces[1].type_line
    end

    name = name .. '\n' .. type_line
    name = name .. '\n' .. cmc .. ' CMC'

    return name
end

-- Returns a nicely formatted oracle text with power/toughness or loyalty
-- if present
local function getAugmentedOracleText(cardData,i)
    local oracleText = cardData.oracle_text

    if cardData.power and cardData.toughness then
        oracleText = oracleText .. '\n[b]' .. cardData.power .. '/' .. cardData.toughness .. '[/b]'
    elseif cardData.loyalty then
        oracleText = oracleText .. '\n[b]' .. tostring(cardData.loyalty) .. '[/b]'
    elseif cardData.defense then
        oracleText = oracleText .. '\n[b]' .. tostring(cardData.defense) .. '[/b]'
    end

    return oracleText
end

-- Collects oracle text from multiple faces if present
local function collectOracleText(cardData,ii)
    local oracleText = ""

    if cardData.card_faces then
        if ii then
            oracleText = getAugmentedOracleText(cardData.card_faces[ii])
        else
            for i, face in ipairs(cardData.card_faces) do
                oracleText = oracleText .. underline(face.name) .. getAugmentedOracleText(face)

                if i < #cardData.card_faces then
                    oracleText = oracleText .. '\n\n'
                end
            end
        end
    else
        oracleText = getAugmentedOracleText(cardData)
    end

    return oracleText
end


function parseForToken(oracle)

  oracle=oracle:lower()
  oracle=oracle:gsub(' and ',' ')     -- easier parsing without this
  oracle=oracle:gsub('%."','".')      -- move periods outside of quotes

  local token_uris={}
  local nSpawned=0

  if not((oracle:find('create') and oracle:find(' token')) or oracle:find(' emblem')) then
    return token_uris
  end

  ------------------------------------------------------------------------------
  -- emblem parsing
  local in1=oracle:find('emblem with "')
  if in1~=nil then
    in1=in1+12
    in2=oracle:find('"',in1+1)
    local eOracle=oracle:sub(in1,in2)
    nSpawned=nSpawned+1
    table.insert(token_uris,'https://api.scryfall.com/cards/search?q=t:emblem+oracle:'..eOracle)
  end

  ------------------------------------------------------------------------------
  -- token parsing

  -- indoracle: processed oracle text to look for indexes, start and end of token description chunk
  local indoracle=oracle

  while indoracle:find('"') do            -- 1. blank out text within quotes
    i1=indoracle:find('"')
    i2=indoracle:find('"',i1+1)
    indoracle=indoracle:sub(1,i1-1)
    for i=i1,i2 do
      indoracle=indoracle..'_'
    end
    indoracle=indoracle..oracle:sub(i2+1,-1)
  end
  indoracle:gsub('. it has','  it has')   -- 2. combine sentences if a sentence starts with "It has"


  local ind1,ind2,ind3=nil,nil,0
  ind3=indoracle:find('create[sd]?')      -- 'create' must appear first
  -- the following words always start (or end) a token description chunk
  local startWords={'create[sd]?','that many','or more','tapped','a number of','a','an','twice','x',
                  'one','two','three','four','five','six','seven','eight','nine','ten'}
  local keepParsing=true

  while keepParsing do

    ind1=nil
    ind2=indoracle:find('token',ind3)   -- find 'token'
    if ind2 then
      ind1=ind3                         -- start of chunk is the end of the previous one
      ind3=indoracle:find('%.',ind2)    -- default end of chunk is a period

      local rind1=indoracle:len()-ind1+1    --reverse string ind1
      local rind2=indoracle:len()-ind2+1    --reverse string ind2

      for _,word in ipairs(startWords) do

        -- ind1: look for a starting word, searching *back* from 'token'
        local r1=indoracle:reverse():find(' '..word:reverse()..' ',rind2)
        if r1 and r1<rind1 then
          rind1=r1
          ind1=indoracle:len()-rind1+1
          ind1=indoracle:find(' ',ind1)
        end

        -- ind2: look for a starting word, searching *forward* from 'token'
        local i3=indoracle:find(' '..word..' ',ind2)
        if i3 and i3<ind3 then
          ind3=i3
        end
      end

    end

    if not(ind1 and ind2 and ind3) then
      keepParsing=false
    else

     local searchStr='t:token+-is:dfc'   -- don't want dfc tokens
      local foundType=false
      local preToken = oracle:sub(ind1,ind2-1)
      local postToken = oracle:sub(ind2,ind3)

      -- remove any descriptive/count words in prefix, only want color,type and pow/tou
      for _,div in pairs(startWords) do
        preToken=preToken:gsub(' '..div..' ',' ')
      end

      -- are there colors listsed in prefix?
      local colors=''
      for k,v in pairs({w='white',u='blue',b='black',r='red',g='green',c='colorless'})do
        if preToken:find(v)then
          preToken=preToken:gsub(v,'')
          colors=colors..k
        end
      end
      if colors~='' then
        searchStr=searchStr..'+c='..colors
      end

      -- is there pow/tou in prefix?
      local power,toughness=nil,nil
      if preToken:find('%d/%d')then
        power,toughness=preToken:match('(%d+)/(%d+)')
        preToken=preToken:gsub('%d+/%d+','')
        searchStr=searchStr..'+pow='..power..'+tou='..toughness
      end
      if preToken:find('x/x')then
        power,toughness='x','x'
        searchStr=searchStr..'+pow='..power..'+tou='..toughness
        preToken=preToken:gsub('x/x','')
      end

      -- all remaining words in prefix should be type
      local crOn,enOn,arOn=false,false,false
      for type in preToken:gmatch('%S+') do
        success,errorMSG=pcall(function()
          preToken=preToken:gsub(type,'')
        end)
        if success then
          searchStr=searchStr..'+t:'..type
          if type=='creature' then crOn=true end
          if type=='enchantment' then enOn=true end
          if type=='artifact' then arOn=true end
          foundType=true   -- only do the search if some sort of type is detected
        end
      end
      if crOn then      -- it's a creature, specify if it's also an artifact or enchantment
        if not(enOn) then
          searchStr=searchStr..'+-t:enchantment'
        end
        if not(arOn) then
          searchStr=searchStr..'+-t:artifact'
        end
      else
        searchStr=searchStr..'+-t:creature'
      end

      -- is there a name for the token?
      if postToken:find('named ') then
        local st=postToken:find('named ')+6
        local en=postToken:find('%.',st)
        if en==nil then
          en=postToken:find('%,',st)
        end
        local en2=postToken:find(' with ',st)
        if en2 and en2<en then en=en2 end
        local name=nil
        if st and en then
          name=postToken:sub(st,en-1)
        end
        if name then
          searchStr=searchStr..'+name:"'..name..'"'
          if name:find('festering goblin') or name:find('goldmeadow harrier') then
            searchStr=searchStr:gsub('t:token+','')
          end
        end
      end

      -- is there a quote of text after 'token', e.g. token with "this creature gets +1/+1"
      if postToken:find('"') then
        local q1=postToken:find('"')
        local q2=postToken:find('"',q1+1)
        if q1 and q2 then
          local tOracle=postToken:sub(q1,q2)
          -- searchStr=searchStr..'+oracle:'..tOracle   -- can't get this to work

          -- look for each word in oracle text separately
          tOracle=tOracle:sub(2,-2):gsub('%{.-%}','')..'.'
          for word in tOracle:gmatch('(%a+)%A') do
            searchStr=searchStr..'+oracle:'..word
          end
        end
      end

      -- look for any keywords in stuff after 'token'
      local keywords={'deathtouch','defender','devour','double strike','flying','haste','infect',
          'hexproof','indestructible','lifelink','menace','reach','trample','vigilance','decayed','training'}
      for _,v in pairs(keywords)do
        if postToken:find(v) then
          searchStr=searchStr..'+keyword:"'..v..'"'
          postToken:gsub(v,'')
        else
          searchStr=searchStr..'+-keyword:"'..v..'"'
        end
      end

      -- creature with no other data at all?
      local badStr='t:token+-is:dfc+t:creature+-t:enchantment+-t:artifact+-keyword:"deathtouch"+-keyword:"defender"+-keyword:"devour"+-keyword:"double strike"+-keyword:"flying"+-keyword:"haste"+-keyword:"infect"+-keyword:"hexproof"+-keyword:"indestructible"+-keyword:"lifelink"+-keyword:"menace"+-keyword:"reach"+-keyword:"trample"+-keyword:"vigilance"+-keyword:"decayed"+-keyword:"training"'

      if searchStr:match('zombie') or searchStr:match('treasure') or searchStr:match('clue') then
 searchStr=searchStr..'-set:sld'
 end
 if foundType and searchStr~=badStr then
        -- addNotebookTab({title='token',body='https://api.scryfall.com/cards/search?q='..searchStr})
        nSpawned=nSpawned+1
        table.insert(token_uris,'https://api.scryfall.com/cards/search?q='..searchStr)
      end
    end
  end

  return token_uris

end

-- Parses scryfall reseponse data for a card.
-- Returns a populated card table and a list of tokens.
local function parseCardData(cardID, data)
    local tokens = {}
    local oracle=''
    if data.card_faces then
      oracle=oracle..'\n'..data.card_faces[1].oracle_text
      oracle=oracle..'\n'..data.card_faces[2].oracle_text
    else
      oracle=data.oracle_text
    end
    oracle=oracle:lower()
    if data.all_parts and not (data.layout == "token") then
        for _, part in ipairs(data.all_parts) do
            if part.type_line:lower():find('emblem') or (part.component and part.component == "token") then
                table.insert(tokens, {
                    name = part.name,
                    scryfallID = part.id,
                    uri = part.uri
                })
            end
        end
    elseif not(data.all_parts) and ((oracle:find('create') and oracle:find(' token')) or oracle:find(' emblem')) then
      local tokenURLs=parseForToken(oracle)
      for _,url in ipairs(tokenURLs) do
        -- addNotebookTab({title='url',body=url})
        table.insert(tokens, {
            uri = url
        })
      end
    end

    -- pieHere: non-en languages have their own fields for these
    if data.lang~='en' then
      data.name = data.printed_name or data.name
      data.type_line = data.printed_type_line or data.type_line
      data.oracle_text = data.printed_text or data.oracle_text
      if data.card_faces then
        for i, face in ipairs(data.card_faces) do
          data.card_faces[i].name=data.card_faces[i].printed_name or data.card_faces[i].name
          data.card_faces[i].type_line=data.card_faces[i].printed_type_line or data.card_faces[i].type_line
          data.card_faces[i].oracle_text=data.card_faces[i].printed_text or data.card_faces[i].oracle_text
        end
      end
    end

    local imagesuffix=''
    if cacheBuster or data.image_status~='highres_scan' then
      imagesuffix='?'..tostring(os.date("%x")):gsub('/', '')
    end

    local card = shallowCopyTable(cardID)
    card.name = getAugmentedName(data)
    card.oracleText = collectOracleText(data)
    card.faces = {}
    card.scryfallID = data.id
    card.oracleID = data.oracle_id
    card.language = data.lang
    card.setCode = data.set
    card.collectorNum = data.collector_number
    card.all_parts_json = all_parts_json
    if data.layout == "reversible_card" or data.layout == "transform" or data.layout == "art_series" or data.layout == "double_sided" or data.layout == "modal_dfc" then
        for i, face in ipairs(data.card_faces) do
            card['faces'][i] = {
                imageURI = stripScryfallImageURI(face.image_uris[getQuality()])..imagesuffix,
                name = getAugmentedName(data,i),
                oracleText = collectOracleText(data,i),
            }
        end
        card['doubleface'] = true
        if combineStates then
          DFCloaded=true
          card['doubleface'] = false
        end
    elseif data.layout == "double_faced_token" then
        for i, face in ipairs(data.card_faces) do
            card['faces'][i] = {
                imageURI = stripScryfallImageURI(face.image_uris[getQuality()])..imagesuffix,
                name = getAugmentedName(data,i),
                oracleText = collectOracleText(data,i),
            }
        end
        card['doubleface'] = false -- Not putting double-face tokens in double-face cards pile
    else
        card['faces'][1] = {
            imageURI = stripScryfallImageURI(data.image_uris[getQuality()])..imagesuffix,
            name = card.name,
            oracleText = card.oracleText,
        }
        card['doubleface'] = false
    end

    return card, tokens
end

-- Queries scryfall by the [cardID].
-- cardID must define at least one of scryfallID, multiverseID, or name.
-- if forceNameQuery is true, will query scryfall by card name ignoring other data.
-- onSuccess is called with a populated card table, and a table of associated token cardIDs.
local function queryCard(cardID, forceNameQuery, forceSetNumLangQuery, onSuccess, onError)

    local query_url
    local language_code = getLanguageCode()

    if cardID.name then
      cardID.name= cardID.name:gsub('%A','')
    end

    if cardID.name and string.find('plains island mountain swamp forest',cardID.name:lower()) and not(cardID.setCode) then
      cardID.setCode='znr'
    end

    if cardID.uri then
        query_url = cardID.uri
    elseif forceNameQuery then
        query_url = SCRYFALL_NAME_BASE_URL .. cardID.name
    elseif cardID.scryfallID and string.len(cardID.scryfallID) > 0 then
        query_url = SCRYFALL_ID_BASE_URL .. cardID.scryfallID
    elseif cardID.multiverseID and string.len(cardID.multiverseID) > 0 then
        query_url = SCRYFALL_MULTIVERSE_BASE_URL .. cardID.multiverseID
    elseif cardID.setCode and string.len(cardID.setCode) > 0 and cardID.collectorNum and string.len(cardID.collectorNum) > 0 then
        query_url = SCRYFALL_SET_NUM_BASE_URL .. string.lower(cardID.setCode) .. "/" .. cardID.collectorNum .. "/" .. language_code
    elseif cardID.setCode and string.len(cardID.setCode) > 0 then
        query_string = "order:released s:" .. string.lower(cardID.setCode) .. " !" .. cardID.name
        query_url = SCRYFALL_SEARCH_BASE_URL .. query_string
    else
        query_url = SCRYFALL_NAME_BASE_URL .. cardID.name
    end

    local headers = {
        ["Content-Type"] = "application/json",
        Accept = "application/json",
        ["User-Agent"] = USER_AGENT,
    }
    local body = JSON.encode({})
    webRequest = WebRequest.custom(query_url, "GET", true, body, headers, function(webReturn)

        if webReturn.is_error or webReturn.error then
            onError(query_url.."\nWeb request error: " .. webReturn.error or "unknown")
            return
        elseif string.len(webReturn.text) == 0 then
            onError(query_url.."\nempty response")
            return
        end

        local success,data
        if webReturn.text:sub(1,16)=='{"object":"list"' then
          success,data = pcall(function() return getNextCardDatFromList(webReturn.text,1) end)
          if not success then
            onError(query_url.."\nsomething went wrong with Pie's the getNextCardDatFromList")
            return
          end
        elseif webReturn.text:sub(1,16)=='{"object":"card"' then
          success, data = pcall(function() return JSONdecode(webReturn.text) end)
          -- log(query_url,success)
          if not success then
              onError(query_url.."\nfailed to parse JSON response")
              return
          elseif not data then
              onError(query_url.."\nempty JSON response")
              return
          elseif data.object == "error" then
              onError(query_url.."\nfailed to find card")
              return
          end
        else
          onError(query_url.."\nPie's parser somehow got a webReturn that is not a card or a list")
          return
        end

        -- language-support rework
        if data.lang==language_code or (cardID.scryfallID and string.len(cardID.scryfallID)>0) then
          local card, tokens = parseCardData(cardID, data)
          onSuccess(card, tokens)
        else

          -- try 1: look for the language-specific card from the same set
          local lang_url1=SCRYFALL_SET_NUM_BASE_URL .. data.set .. "/" .. data.collector_number .. "/" .. language_code
          WebRequest.get(lang_url1, function(webReturn)
            success,lang_data = pcall(function() return JSONdecode(webReturn.text) end)
            -- log(lang_url1,success)
            if success and lang_data~=nil and lang_data.object~='error' and lang_data.image_status~='placeholder' then
              data=lang_data
              local card, tokens = parseCardData(cardID, data)
              onSuccess(card, tokens)
            else
              -- try 2: look for the language specific card from any set
              local lang_url2=SCRYFALL_SEARCH_BASE_URL..'!'..data.name:gsub('%A','') .. '+lang%3A' .. language_code
              WebRequest.get(lang_url2, function(webReturn)
                success,lang_data = pcall(function() return getNextCardDatFromList(webReturn.text,1) end)
                -- log(lang_url2,success)
                if success and lang_data~=nil and lang_data.object~='error' and lang_data.image_status~='placeholder' then
                  -- if lang_data.image_status=='placeholder' then    -- if no image, but the rest of the data is present?
                  --   if data.card_faces then
                  --     lang_data.card_faces[1].image_uris.large=data.card_faces[1].image_uris.large
                  --     lang_data.card_faces[2].image_uris.large=data.card_faces[2].image_uris.large
                  --   elseif data.image_uris then
                  --     lang_data.image_uris.large=data.image_uris.large
                  --   end
                  -- end
                  data=lang_data
                else
                  printToColor("Could not find "..language_code:upper().." version for: "..data.name,playerColor,{1,1,0})
                end
                local card, tokens = parseCardData(cardID, data)  -- use original data if lang-specific card was not found
                onSuccess(card, tokens)
              end)
            end
          end)
        end

    end)
end

-- Queries card data for all cards.
-- TO-DO use the bulk api
-- PieHere: bulk API is crazy, the minimum would be parsing an ~80MB file, no way TTS's JSON.decode would handle that
-- at this size I feel parsing the text manually would also be kinda nuts... but possible ;-)
local function fetchCardData(cards, onComplete, onError)
    local sem = 0
    local function incSem() sem = sem + 1 end
    local function decSem() sem = sem - 1 end

    local cardData = {}
    local tokenIDs = {}

    local function onQuerySuccess(card, tokens)

        local rmfields={'multiverse_ids','colors','color_identity','keywords',
                  'all_parts','legalities','games','artist_ids','promo_types',
                  'prices','related_uris','purchase_uris'}
        local ntp=0
        local ntd=0
        local all_parts_json=''
        if cardTokenDat then
          for iii,t in ipairs(tokens) do
            ntp=ntp+1
            WebRequest.get(t.uri,function(wrt)
              local txt=wrt.text
              local cardStart=string.find(txt,'{"object":"card"',0)
              local cardEnd = findClosingBracket(txt,cardStart)
              if cardStart~=nil and cardEnd~=nil then
                txt=txt:sub(cardStart,cardEnd)
                for _,rmfield in ipairs(rmfields) do
                  local st=txt:find('"'..rmfield..'"'..':')
                  if st~=nil then
                    local en=findClosingBracket(txt,st+string.len('"'..rmfield..'"'..':'))
                    txt=txt:sub(1,st-1)..txt:sub(en+2,-1)
                  end
                end
                txt=txt:sub(1,-2)..'}'
                local comma=''
                if ntd>0 then
                  comma=','
                end
                all_parts_json=all_parts_json..comma..txt
                ntd=ntd+1
              else
                ntp=ntp-1
              end
              if ntd==ntp and ntp>0 then
                all_parts_json='{"object":"list","total_cards":'..ntd..',"data":['..all_parts_json..']}'
              end
            end)
            if iii>5 then break end
          end
        end

        Wait.condition(function()
          card.all_parts_json=all_parts_json
          table.insert(cardData, card)
          for _, token in ipairs(tokens) do
              table.insert(tokenIDs, token)
          end
          decSem()
        end,function() return ntp==ntd end)

    end

    local function onQueryFailed(e)
        -- printErr("Error querying scryfall: " .. e)
        decSem()
    end

    for _, cardID in ipairs(cards) do
        incSem()
        queryCard(
            cardID,
            false,
            false,
            onQuerySuccess,
            function(e) -- onError
                -- try again, forcing query-by-name.
                queryCard(
                    cardID,
                    true,
                    false,
                    onQuerySuccess,
                    onQueryFailed
                )
            end
        )
    end

    Wait.condition(
        function() onComplete(cardData, tokenIDs) end,
        function() return (sem == 0) end,
        30,
        function() onError("Error loading card images... timed out.") end
    )
end

-- Queries for the given card IDs, collates deck, and spawns objects.
local function loadDeck(cardIDs, deckName, onComplete, onError)
    local maindeckPosition = self.positionToWorld(MAINDECK_POSITION_OFFSET)
    local doublefacePosition = self.positionToWorld(DOUBLEFACE_POSITION_OFFSET)
    local sideboardPosition = self.positionToWorld(SIDEBOARD_POSITION_OFFSET)
    local commanderPosition = self.positionToWorld(COMMANDER_POSITION_OFFSET)
    local tokensPosition = self.positionToWorld(TOKENS_POSITION_OFFSET)

    printInfo("Querying Scryfall for card data...")

    fetchCardData(cardIDs, function(cards, tokenIDs)
        if tokenIDs and tokenIDs[1] then
            printInfo("Querying Scryfall for tokens...")
        end

        fetchCardData(tokenIDs, function(tokens, _)
            local maindeck = {}
            local sideboard = {}
            local commander = {}
            local doubleface = {}

            for _, card in ipairs(cards) do
                if card.sideboard then
                    table.insert(sideboard, card)
                elseif card.commander then
                    table.insert(commander, card)
                elseif card.doubleface then
                    table.insert(doubleface, card)
                else
                    table.insert(maindeck, card)
                end
            end

            printInfo("Spawning deck...")

            local sem = 5
            local function decSem() sem = sem - 1 end

            local flipped=false

            spawnDeck(maindeck, deckName .. "\n[i]Maindeck[/i]", maindeckPosition, flipped,
                function() -- onSuccess
                    decSem()
                end,
                function(e) -- onError
                    printErr(e)
                    decSem()
                end
            )

            spawnDeck(doubleface, deckName .. "\n[i]Double Face Cards[/i]", doublefacePosition, flipped,
                function() -- onSuccess
                    decSem()
                end,
                function(e) -- onError
                    printErr(e)
                    decSem()
                end
            )

            spawnDeck(sideboard, deckName .. "\n[i]Sideboard[/i]", sideboardPosition, flipped,
                function() -- onSuccess
                    decSem()
                end,
                function(e) -- onError
                    printErr(e)
                    decSem()
                end
            )

            spawnDeck(commander, deckName .. "\n[i]Commanders[/i]", commanderPosition, flipped,
                function() -- onSuccess
                    decSem()
                end,
                function(e) -- onError
                    printErr(e)
                    decSem()
                end
            )

            spawnDeck(tokens, deckName .. "\n[i]Tokens[/i]", tokensPosition, flipped,
                function() -- onSuccess
                    decSem()
                end,
                function(e) -- onError
                    printErr(e)
                    decSem()
                end
            )

            Wait.condition(
                function() onComplete() end,
                function() return (sem == 0) end,
                30,
                function() onError("Error spawning deck objects... timed out.") end
            )
        end, onError)
    end, onError)
end

------ DECK BUILDER SCRAPING
local function parseMTGALine(line)
    -- Parse out card count if present
    local count, countIndex = string.match(line, "^%s*(%d+)[x%*]?%s+()")
    if count and countIndex then
        line = string.sub(line, countIndex)
    else
        count = 1
    end

    local name, setCode, collectorNum = string.match(line, "([^%(%)]+) %(([%d%l%u]+)%) ([%d%l%u]+)")

    if not name then
        name, setCode = string.match(line, "([^%(%)]+) %(([%d%l%u]+)%)")
    end

    if not name then
       name = string.match(line, "([^%(%)]+)")
    end

    -- MTGA format uses DAR for dominaria for some reason, which scryfall can't find.
    if setCode == "DAR" then
        setCode = "DOM"
    end

    return name, count, setCode, collectorNum
end

local function queryDeckNotebook(_, onSuccess, onError)
    local bookContents = readNotebookForColor(playerColor)

    if bookContents == nil then
        onError("Notebook not found: " .. playerColor)
        return
    elseif string.len(bookContents) == 0 then
        onError("Notebook is empty. Please paste your decklist into your notebook (" .. playerColor .. ").")
        return
    end

    local cards = {}

    local i = 1
    local mode = "deck"
    for line in iterateLines(bookContents) do
        if string.len(line) > 0 then
            if line:gsub('%A',''):lower() == "commander" then
                mode = "commander"
            elseif line:gsub('%A',''):lower() == "sideboard" then
                mode = "sideboard"
            elseif line:gsub('%A',''):lower() == "deck" then
                mode = "deck"
            else
                local name, count, setCode, collectorNum = parseMTGALine(line)

                if name then
                    cards[i] = {
                        count = count,
                        name = name,
                        setCode = setCode,
                        collectorNum = collectorNum,
                        sideboard = (mode == "sideboard"),
                        commander = (mode == "commander")
                    }

                    i = i + 1
                end
            end
        end
    end

    onSuccess(cards, "Notebook Deck")
end

local function parseDeckIDTappedout(s)
    -- NOTE: need to do this in multiple parts because TTS uses an old version
    -- of lua with hilariously sad pattern matching

    local urlSuffix = s:match("tappedout%.net/mtg%-decks/(.*)")
    if urlSuffix then
        return urlSuffix:match("([^%s%?/$]*)")
    else
        return nil
    end
end

local function queryDeckTappedout(slug, onSuccess, onError)
    if not slug or string.len(slug) == 0 then
        onError("Invalid tappedout deck slug: " .. slug)
        return
    end

    local url = TAPPEDOUT_BASE_URL .. slug .. TAPPEDOUT_URL_SUFFIX
    printInfo("Fetching decklist from tappedout...")

    local deckName=nil      -- get original deck name
    WebRequest.get('https://tappedout.net/mtg-decks/'..slug..'/',function(webReturn)
        local st=webReturn.text:find('<title>')+7
        local en=webReturn.text:find('</title>')-1
        deckName=webReturn.text:sub(st,en):gsub('&#x(%x%x);',function (x) return string.char(tonumber(x,16)) end):gsub('( %(.-%))','')
    end)

    Wait.condition(function()
        WebRequest.get(url .. "?fmt=csv", function(webReturn)
            if webReturn.error then
                if string.match(webReturn.error, "(404)") then
                    onError("Deck not found. Is it public?")
                else
                    onError("Web request error: " .. webReturn.error)
                end
                return
            elseif webReturn.is_error then
                onError("Web request error: unknown")
                return
            elseif string.len(webReturn.text) == 0 then
                onError("Web request error: empty response")
                return
            end

            cvsData = webReturn.text

            local cards = {}

            local i = 1
            local lineN=1
            for line in iterateLines(cvsData) do
              if string.len(line) > 0 then
                -- Amuzet's "remove commas in card name regex" (I can't fully follow it.. but I can copy it)
                line=', '..line:gsub(',("[^"]+"),',function(g)return','..g:gsub(',',''):gsub('"','')..','end):gsub(',',', ')
                if lineN>1 then
                  -- Board,Qty,Name,Printing,Foil,Alter,Signed,Condition,Language,Commander
                  rowdat={}
                  for dat in line:gmatch(',([^,]+)') do
                    table.insert(rowdat,dat:sub(2))
                  end
                  if rowdat[1]~='maybe' and rowdat[1]~='acquire' then
                    cards[i] = {
                        count = tonumber(rowdat[2]),
                        name = rowdat[3],
                        setCode = rowdat[4],
                        sideboard = (rowdat[1] == 'side'),
                        commander = (rowdat[10] == 'True')
                    }
                    i=i+1
                  end
                end
              end
              lineN=lineN+1
            end
            onSuccess(cards, deckName)
        end)
    end, function() return deckName~=nil end)
end

local function parseDeckIDArchidekt(s)
    return s:match("archidekt%.com/decks/(%d*)")
end

local function queryDeckArchidekt(deckID, onSuccess, onError)
    if not deckID or string.len(deckID) == 0 then
        onError("Invalid archidekt deck: " .. deckID)
        return
    end

    local url = ARCHIDEKT_BASE_URL .. deckID .. ARCHIDEKT_URL_SUFFIX

    printInfo("Fetching decklist from archidekt...")

    WebRequest.get(url, function(webReturn)
        if webReturn.error then
            if string.match(webReturn.error, "(404)") then
                onError("Deck not found. Is it public?")
            else
                onError("Web request error: " .. webReturn.error)
            end
            return
        elseif webReturn.is_error then
            onError("Web request error: unknown")
            return
        elseif string.len(webReturn.text) == 0 then
            onError("Web request error: empty response")
            return
        end

        -- pieHere: manual archidekt parsing
        local success, data = pcall(function()

          local startInd=1
          local endInd
          local keepGoing=true
          local cards={}
          local categories={}
          local catSt=webReturn.text:find('"categories":%[{"id"')
          catSt=catSt+13
          local catEn=findClosingBracket(webReturn.text,catSt)
          local categoriesSnip=webReturn.text:sub(catSt,catEn)
          local st,en=0,0
          n=0
          while keepGoing do
            st=categoriesSnip:find('{',en)
            if st==nil then keepGoing=false break end
            en=categoriesSnip:find('}',st)
            if en==nil then keepGoing=false break end
            local name=categoriesSnip:sub(st,en):match('"name":"(.-)"')
            local include=categoriesSnip:sub(st,en):match('"includedInDeck":(.-),')
            categories[name]=include~='false'
          end

          local keepGoing=true
          n=0
          while keepGoing do
            n=n+1
            if n==1 then
              startInd=webReturn.text:find('"cards":%[{"id":',startInd)
            else
              startInd=webReturn.text:find(',{"id":',startInd)
            end
            if startInd==nil then keepGoing=false break end
            if n==1 then
              startInd=startInd+9
            else
              startInd=startInd+1
            end
            endInd=findClosingBracket(webReturn.text,startInd)
            if endInd==nil then keepGoing=false break end

            local cardSnip = webReturn.text:sub(startInd,endInd)
            if not(cardSnip:match('"card":')) then
              keepGoing=false break
            end

            card={
              quantity=cardSnip:match('"quantity":(%d+)'),
              name=cardSnip:match('"name":"(.-)"'):gsub("\\u(%x%x%x%x)",function (x) return string.char(tonumber(x,16)) end),
              scryfall_id=cardSnip:match('"uid":"(.-)"'),
              category=cardSnip:match('"categories":%["(.-)"')
            }
            table.insert(cards,card)
            startInd=endInd+1
          end
          local deckName
          local rm = webReturn.text:sub(endInd,-1)
          while rm:find('"name":') do
            ind=rm:find('"name":')
            deckName=rm:match('"name":"(.-)"')
            rm=rm:sub(ind+6,-1)
          end
          data={cards=cards,categories=categories,deckName=deckName}
          return data
        end)
        ------------------------------------------------------------------------

        if not success then
            onError("Failed to parse JSON response from archidekt.")
            print(data)
            return
        elseif not data then
            onError("Empty response from archidekt.")
            return
        elseif not data.cards then
            onError("Empty response from archidekt. Did you enter a valid deck URL?")
            return
        end

        local deckName = data.deckName
        local cards = {}

        for i, card in ipairs(data.cards) do
            if card.category~="Maybeboard" then
                cards[#cards+1] = {
                    count = card.quantity,
                    sideboard = card.category~=nil and not(data.categories[card.category]),
                    commander = card.category=="Commander",
                    name = card.name,
                    scryfallID = card.scryfall_id,
                }
            end
        end

        onSuccess(cards, deckName)
    end)
end

local function parseDeckIDMoxfield(s)
    local urlSuffix = s:match("moxfield%.com/decks/(.*)")
    if urlSuffix then
        return urlSuffix:match("([^%s%?/$]*)")
    else
        return nil
    end
end

local function queryDeckMoxfield(deckID, onSuccess, onError)
    if not deckID or string.len(deckID) == 0 then
        onError("Invalid moxfield deck: " .. deckID)
        return
    end

    local url = MOXFIELD_BASE_URL .. deckID .. MOXFIELD_URL_SUFFIX

    printInfo("Fetching decklist from moxfield...")

    WebRequest.get(url, function(webReturn)
        if webReturn.error then
            if string.match(webReturn.error, "(404)") then
                onError("Deck not found. Is it public?")
            else
                onError("Web request error: " .. webReturn.error)
            end
            return
        elseif webReturn.is_error then
            onError("Web request error: unknown")
            return
        elseif string.len(webReturn.text) == 0 then
            onError("Web request error: empty response")
            return
        end

        ------------------------------------------------------------------------
        -- pieHere, manual moxfield parser
        -- could/should move it to a separate function and use pcall?
        local deckName = getKeyValue(webReturn.text,'name',1)
        local commanderIDs = {}
        local cards = {}
        local data={}
        local sections={'mainboard','commanders','companions','signatureSpells','sideboard'}
        for _,section in ipairs(sections) do
          -- section text extraction
          local sectionSearch='"'..section..'":{'
          local bracketShift=string.len(sectionSearch)
          local sectionStart=string.find(webReturn.text,sectionSearch)+bracketShift-1
          local sectionEnd=findClosingBracket(webReturn.text,sectionStart)
          local sectionTxt = webReturn.text:sub(sectionStart,sectionEnd)

          -- extracting cardDats from each section
          local sectionDat={}
          local st=1
          local en=1
          local keepGoing=true
          while keepGoing do
            st=string.find(sectionTxt,'{"quantity":',st)    -- it appears every card section starts with quantity?
            if st==nil then keepGoing=false break end

            en=findClosingBracket(sectionTxt,st)
            if en==nil then keepGoing=false break end

            local cardTxt=sectionTxt:sub(st,en)
            local dat={quantity=nil,card={id=nil,name=nil}}
            dat.quantity  = getKeyValue(cardTxt,'quantity',1)
            dat.card.id   = getKeyValue(cardTxt,'scryfall_id',1)
            dat.card.name = getKeyValue(cardTxt,'name',1)

            table.insert(sectionDat,dat)    -- populate sectionDat
            st=en+1
          end
          data[section]=sectionDat
        end
        ------------------------------------------------------------------------

        for name, cardData in pairs(data.commanders or {}) do
            if cardData.card then
                commanderIDs[cardData.card.id] = true
                table.insert(cards, {
                    name = cardData.card.name,
                    count = cardData.quantity,
                    scryfallID = cardData.card.id,
                    sideboard = false,
                    commander = true,
                })
            end
        end

        for name, cardData in pairs(data.companions or {}) do
            if cardData.card then
                commanderIDs[cardData.card.id] = true
                table.insert(cards, {
                    name = cardData.card.name,
                    count = cardData.quantity,
                    scryfallID = cardData.card.id,
                    sideboard = false,
                    commander = true,
                })
            end
        end

        for name, cardData in pairs(data.signatureSpells or {}) do
            if cardData.card then
                commanderIDs[cardData.card.id] = true
                table.insert(cards, {
                    name = cardData.card.name,
                    count = cardData.quantity,
                    scryfallID = cardData.card.id,
                    sideboard = false,
                    commander = true,
                })
            end
        end

        for name, cardData in pairs(data.mainboard) do
            if cardData.card and not commanderIDs[cardData.card.id] then
                table.insert(cards, {
                    name = cardData.card.name,
                    count = cardData.quantity,
                    scryfallID = cardData.card.id,
                    sideboard = false,
                    commander = false,
                })
            end
        end

        for name, cardData in pairs(data.sideboard or {}) do
            if cardData.card and not commanderIDs[cardData.card.id] then
                table.insert(cards, {
                    name = cardData.card.name,
                    count = cardData.quantity,
                    scryfallID = cardData.card.id,
                    sideboard = true,
                    commander = false,
                })
            end
        end

        onSuccess(cards, deckName)
    end)
end

local function parseDeckIDDeckstats(s)
    local deckURL = s:match("(deckstats%.net/decks/%d*/[^/]*)")
    return deckURL
end

local function queryDeckDeckstats(deckURL, onSuccess, onError)
    if not deckURL or string.len(deckURL) == 0 then
        onError("Invalid deckstats URL: " .. deckURL)
        return
    end

    local url = deckURL .. DECKSTATS_URL_SUFFIX
    local url0= deckURL .. '?include_comments=1&export_dec=1'

    printInfo("Fetching decklist from deckstats...")

    -- grab commander from '?include_comments=1&export_dec=1'
    local commanderParsed=false
    local commanders={}
    local deckName = deckURL:match("deckstats%.net/decks/%d*/%d*-([^/?]*)"):gsub('-',' ')
    WebRequest.get(url0, function(webReturn)
        if webReturn.error then
            if string.match(webReturn.error, "(404)") then
                onError("Deck not found. Is it public?")
            else
                onError("Web request error: " .. webReturn.error)
            end
            return
        elseif webReturn.is_error then
            onError("Web request error: unknown")
            return
        elseif string.len(webReturn.text) == 0 then
            onError("Web request error: empty response")
            return
        end

        for line in iterateLines(webReturn.text) do
            if line:match('//NAME:') then
                deckName=line:match('//NAME: (.-) from deckstats.net')
            end
            if line:match('# !Commander') then
                local cmdname=line:gsub('%d',''):gsub('//.+',''):gsub('#.*',''):gsub('%W',''):lower()
                table.insert(commanders,cmdname)
            end
        end
        commanderParsed=true
    end)

    -- use '?include_comments=1&export_mtgarena=1' to get the listed printing of each card
    Wait.condition(function()
        WebRequest.get(url, function(webReturn)
            if webReturn.error then
                if string.match(webReturn.error, "(404)") then
                    onError("Deck not found. Is it public?")
                else
                    onError("Web request error: " .. webReturn.error)
                end
                return
            elseif webReturn.is_error then
                onError("Web request error: unknown")
                return
            elseif string.len(webReturn.text) == 0 then
                onError("Web request error: empty response")
                return
            end

            local cards = {}

            local i = 1
            local mode = "deck"
            for line in iterateLines(webReturn.text) do
                if string.len(line) == 0 then
                    mode = "sideboard"
                else
                    local commentPos = line:find("#")
                    if commentPos then
                        line = line:sub(1, commentPos)
                    end

                    local name, count, setCode, collectorNum = parseMTGALine(line)

                    for _,cmdname in pairs(commanders) do
                        if name:gsub('%d',''):gsub('//.+',''):gsub('#.*',''):gsub('%W',''):lower()==cmdname then
                            isCommander=true
                        else
                            isCommander=false
                        end
                    end

                    if name then
                        cards[i] = {
                          count = count,
                          name = name,
                          setCode = setCode,
                          collectorNum = collectorNum,
                          sideboard = (mode == "sideboard"),
                          commander = isCommander
                        }

                        i = i + 1
                    end
                end
            end

            onSuccess(cards, deckName)
        end)
    end, function() return commanderParsed end)
end


local function queryDeckGoldfish(deckID, onSuccess, onError)

    if not deckID or string.len(deckID) == 0 then
        onError("Invalid mtggoldfish deck: " .. deckID)
        return
    end

    local url = 'https://www.mtggoldfish.com/deck/arena_download/' .. deckID .. '/'
    local url0= 'https://www.mtggoldfish.com/deck/download/' .. deckID .. '/'

    printInfo("Fetching decklist from mtggoldfish...")

    deckName=nil

    WebRequest.get(url0, function(webReturn)      -- this here is just to get the deck name
      local contentDisposition = webReturn.getResponseHeader("Content-Disposition")
      local _, _, filename = string.find(contentDisposition, "filename=\"(.+)\"")
      deckName = filename:gsub('Deck - ',''):gsub('.txt','')
    end)

    Wait.condition(function()   -- wait until deckName is parsed from other url
      WebRequest.get(url, function(webReturn)
          if webReturn.error then
              if string.match(webReturn.error, "(404)") then
                  onError("Deck not found. Is it public?")
              else
                  onError("Web request error: " .. webReturn.error)
              end
              return
          elseif webReturn.is_error then
              onError("Web request error: unknown")
              return
          elseif string.len(webReturn.text) == 0 then
              onError("Web request error: empty response")
              return
          end

          -- I just couldn't find which string to match to get startInd.. but endInd is there ;-)
          local startInd
          local endStr="</textarea>"
          local endInd  =webReturn.text:find(endStr,startInd)-1
          for i=endInd,1,-1 do
            if webReturn.text:sub(i,i)=='>' then
              startInd=i+1
              break
            end
          end

          local deckTxt = webReturn.text:sub(startInd,endInd)

          local cards = {}

          local i = 1
          local mode = "deck"
          for line in iterateLines(deckTxt) do
              if line=="Commander" then
                  mode = "commander"
              elseif line=="Deck" then
                  mode = "deck"
              elseif line=="Sideboard" then
                  mode = "sideboard"
              else
                  local name, count, setCode, collectorNum = parseMTGALine(line)
                  if name then
                      name=name:gsub('&#(%d%d);',function (x) return string.char(tonumber(x)) end)  -- html ascii codes
                      cards[i] = {
                        count = count,
                        name = name,
                        sideboard = (mode == "sideboard"),
                        commander = (mode == "commander")
                      }
                      i = i + 1
                  end
              end
          end
          onSuccess(cards, deckName)
      end)
    end, function() return deckName~=nil end)

end

local function queryDeckScryfall(deckID, onSuccess, onError)
    if not deckID or string.len(deckID) == 0 then
        onError("Invalid Scryfall deck: " .. deckID)
        return
    end

    local url = 'https://api.scryfall.com/decks/' .. deckID .. '/export/json'

    printInfo("Fetching decklist from scryfall...")
    local headers = {
        ["Content-Type"] = "application/json",
        Accept = "application/json",
        ["User-Agent"] = USER_AGENT,
    }
    local body = JSON.encode({})

    WebRequest.custom(url, "GET", true, body, headers, function(webReturn)
        if webReturn.error then
            if string.match(webReturn.error, "(404)") then
                onError("Deck not found. Is it public?")
            else
                onError("Web request error: " .. webReturn.error)
            end
            return
        elseif webReturn.is_error then
            onError("Web request error: unknown")
            return
        elseif string.len(webReturn.text) == 0 then
            onError("Web request error: empty response")
            return
        end

        local deckName = webReturn.text:match('"name": "(.-)"')
        local cards={}
        local i = 1

        local st=1
        local en=1
        local keepGoing=true
        while keepGoing do
          st=string.find(webReturn.text,'{%s-"object": "deck_entry"',st)    -- it appears every card section starts with quantity?
          if st==nil then keepGoing=false break end
          en=findClosingBracket(webReturn.text,st)
          if en==nil then keepGoing=false break end
          local cardSnip = webReturn.text:sub(st,en)
          st=en+1
          if not(cardSnip:match('"card_digest": null')) then
            local section = cardSnip:match('"section": "(%a+)"')
            if section~="maybeboard" then
              local digestSt=cardSnip:find('"card_digest": {')+15
              local digestEn=findClosingBracket(cardSnip,digestSt)
              local card_digest = cardSnip:sub(digestSt,digestEn)
              local count = cardSnip:match('"count": (%d+)')
              local scryfallID = card_digest:match('"id": "(.-)"')
              local name = card_digest:match('"name": "(.-)"')
              local setCode = card_digest:match('"set": "(.-)"')
              local collectorNum = card_digest:match('"collector_number": "(%d+)"')
              cards[i] = {
                count = count,
                scryfallID = scryfallID,
                name = name,
                setCode = setCode,
                collectorNum = collectorNum,
                sideboard = (section == "sideboard") or (section == "outside") or (section == "maybeboard"),
                commander = (section == "commanders"),
              }
              i=i+1
            end
          end
        end

        return

        onSuccess(cards, deckName)
    end)
end


local function queryDeckFrogtown(deckURL, onSuccess, onError)

  printInfo("Fetching decklist from frogtown...")

  WebRequest.get(deckURL, function(wr)
    if wr.error then
        if string.match(wr.error, "(404)") then
            onError("Deck not found. Is it public?")
        else
            onError("Web request error: " .. wr.error)
        end
        return
    elseif wr.is_error then
        onError("Web request error: unknown")
        return
    elseif string.len(wr.text) == 0 then
        onError("Web request error: empty response")
        return
    end

    local st=wr.text:find("<script>")
    local en=wr.text:find("</script>")
    local txt=wr.text:sub(st,en)
    st=txt:find('{')
    en=findClosingBracket(txt,st)
    txt=txt:sub(st,en)

    local keyID=txt:match('"keyCard":"(.-)"')
    local deckName=txt:match('"name":"(.-)"')

    local mst=txt:find('"mainboard":%[')+12
    local men=txt:find(']',mst)
    local main=txt:sub(mst,men)
    local mainIDs={}
    local st,en=0,0
    local keepGoing=true
    while keepGoing do
      st=main:find('"',en+1)
      if st==nil then keepGoing=false break end
      en=main:find('"',st+1)
      if en==nil then keepGoing=false break end
      local cardID=main:sub(st+1,en-1)
      if not(mainIDs[cardID]) then
        mainIDs[cardID]=1
      else
        mainIDs[cardID]=mainIDs[cardID]+1
      end
    end

    local sst=txt:find('"sideboard":%[')+12
    local sen=txt:find(']',sst)
    local side=txt:sub(sst,sen)
    local sideIDs={}
    local st,en=0,0
    local keepGoing=true
    while keepGoing do
      st=side:find('"',en+1)
      if st==nil then keepGoing=false break end
      en=side:find('"',st+1)
      if en==nil then keepGoing=false break end
      local cardID=side:sub(st+1,en-1)
      if not(sideIDs[cardID]) then
        sideIDs[cardID]=1
      else
        sideIDs[cardID]=sideIDs[cardID]+1
      end
    end

    local i=0
    local cards={}
    for cardID,nCards in pairs(mainIDs) do
      i=i+1
      cards[i] = {
        count = nCards,
        scryfallID = cardID,
        sideboard = false,
        commander = cardID==keyID,
      }
    end
    for cardID,nCards in pairs(sideIDs) do
      i=i+1
      cards[i] = {
        count = nCards,
        scryfallID = cardID,
        sideboard = true,
        commander = cardID==keyID,
      }
    end

    onSuccess(cards, deckName)

  end)

end



function importDeck()
    if lock then
        printErr("Error: Deck import started while importer locked.")
    end
    self.setLock(true)

    local deckURL = getDeckInputValue()

    local deckID, queryDeckFunc
    if deckSource == DECK_SOURCE_URL then
        if string.len(deckURL) == 0 then
            printInfo("Please enter a deck URL.")
            return 1
        end

        if string.match(deckURL, TAPPEDOUT_URL_MATCH) then
            queryDeckFunc = queryDeckTappedout
            deckID = parseDeckIDTappedout(deckURL)
        elseif string.match(deckURL, ARCHIDEKT_URL_MATCH) then
            queryDeckFunc = queryDeckArchidekt
            deckID = parseDeckIDArchidekt(deckURL)
        elseif string.match(deckURL, GOLDFISH_URL_MATCH) then
            if deckURL:find('/archetype/') then
              printInfo("Can't load archetype decks from mtggoldfish :( Please spawn a user made Deck.")
              return 1
            end
            queryDeckFunc = queryDeckGoldfish
            deckID = deckURL:match('deck/(%d+)#')
        elseif string.match(deckURL, MOXFIELD_URL_MATCH) then
            queryDeckFunc = queryDeckMoxfield
            deckID = parseDeckIDMoxfield(deckURL)
        elseif string.match(deckURL, DECKSTATS_URL_MATCH) then
            queryDeckFunc = queryDeckDeckstats
            deckID = parseDeckIDDeckstats(deckURL)
        elseif string.match(deckURL, SCRYFALL_URL_MATCH) then
            queryDeckFunc = queryDeckScryfall
            deckID = deckURL:match('/decks/(.*)'):gsub('?.+','')
        elseif string.match(deckURL, 'frogtown.me') then
            queryDeckFunc = queryDeckFrogtown
            deckID = deckURL:gsub('#','')
        else
            printInfo("Unknown deck site, sorry! Please export to MTG Arena and use notebook import.")
            return 1
        end
    elseif deckSource == DECK_SOURCE_NOTEBOOK then
        queryDeckFunc = queryDeckNotebook
        deckID = nil
    else
        printErr("Error. Unknown deck source: " .. deckSource or "nil")
        return 1
    end

    lock = true
    printToAll("Starting deck import...")

    local function onError(e)
        printErr(e)
        printToAll("Deck import failed.")
        lock = false
        self.setLock(false)
        self.reload()
    end
    DFCloaded=false
    queryDeckFunc(deckID,
        function(cardIDs, deckName)
            loadDeck(cardIDs, deckName,
                function()
                    printToAll("Deck import complete!")
                    -- if combineStates and DFCloaded then
                    --     broadcastToColor("Double-faced-cards combined into states and added to Maindeck.\n(see advanced menu [b][...][/b] to change behaviour)",playerColor,{1,0.7,0,7})
                    -- end
                    lock = false
                    Wait.time(function() self.setLock(false) end, 2)
                end,
                onError
            )
        end,
        onError
    )

    return 1
end

------ UI
local function drawUI()
    local _inputs = self.getInputs()
    local deckURL = ""

    if _inputs ~= nil then
        for i, input in pairs(self.getInputs()) do
            if input.label == "Enter deck URL, or load from Notebook." then
                deckURL = input.value
            end
        end
    end
    self.clearInputs()
    self.clearButtons()
    self.createInput({
        input_function = "onLoadDeckInput",
        function_owner = self,
        label          = "Enter deck URL, or load from Notebook.",
        alignment      = 2,
        position       = {x=0, y=0.1, z=0.78},
        width          = 2000,
        height         = 100,
        font_size      = 75,
        validation     = 1,
        value = deckURL,
    })

    self.createButton({
        click_function = "onLoadDeckURLButton",
        function_owner = self,
        label          = "Load Deck (URL)",
        position       = {-1, 0.1, 1.15},
        rotation       = {0, 0, 0},
        width          = 850,
        height         = 160,
        font_size      = 80,
        color          = {0.5, 0.5, 0.5},
        font_color     = {r=1, b=1, g=1},
        tooltip        = "Click to load deck from URL",
    })

    self.createButton({
        click_function = "onLoadDeckNotebookButton",
        function_owner = self,
        label          = "Load Deck (Notebook)",
        position       = {1, 0.1, 1.15},
        rotation       = {0, 0, 0},
        width          = 850,
        height         = 160,
        font_size      = 80,
        color          = {0.5, 0.5, 0.5},
        font_color     = {r=1, b=1, g=1},
        tooltip        = "Click to load deck from notebook",
    })

    self.createButton({
        click_function = "onToggleAdvancedButton",
        function_owner = self,
        label          = "...",
        position       = {2.25, 0.1, 1.15},
        rotation       = {0, 0, 0},
        width          = 160,
        height         = 160,
        font_size      = 100,
        color          = {0.5, 0.5, 0.5},
        font_color     = {r=1, b=1, g=1},
        tooltip        = "Click to open advanced menu",
    })

    -- pieHere, load UI attributes
    -- allows entered info to be saved/loaded per object, such that folks don't have to re-enter their preferences every time
    local UIxml=self.UI.getXml()
    local delayShowUI=false

    if languageInput==nil then languageInput='en' end
    if qualityInput==nil then qualityInput='large' end

    local langCheck = languageInput~='' and UIxml:find('<Option selected="false">'..languageInput:upper())
    local qualCheck = qualityInput~='' and UIxml:find('<Option selected="false">'..qualityInput)

    if langCheck or qualCheck then
      UIxml=UIxml:gsub('<Option selected="true">','<Option selected="false">')
      -- if langCheck then
        UIxml=UIxml:gsub('"false">'..languageInput:upper(),'"true">'..languageInput:upper())
      -- end
      -- if qualCheck then
        UIxml=UIxml:gsub('"false">'..qualityInput,'"true">'..qualityInput)
      -- end
      self.UI.setXml(UIxml)
      delayShowUI=true    -- need to give it a few frames for the XML code to update
    end

    self.UI.setAttribute("UIcardBackInput", "text", cardBackInput)
    self.UI.setAttribute("UIcombineStateToggle", "isOn", tostring(combineStates))
    self.UI.setAttribute("UIcacheBusterToggle", "isOn", tostring(cacheBuster))

    if advanced then
      if delayShowUI then
        Wait.frames(function() self.UI.show("MTGDeckLoaderAdvancedPanel") end, 2)
      else
        self.UI.show("MTGDeckLoaderAdvancedPanel")
      end
    else
        self.UI.hide("MTGDeckLoaderAdvancedPanel")
    end
end

function getDeckInputValue()
    for i, input in pairs(self.getInputs()) do
        if input.label == "Enter deck URL, or load from Notebook." then
            return trim(input.value)
        end
    end

    return ""
end

function onLoadDeckInput(_, _, _) end

-- r15ch13
function onLoadDeckURLButtonExternal(pc)
  onLoadDeckURLButton(nil, pc, nil)
end
-- /r15ch13

function onLoadDeckURLButton(_, pc, _)
    if lock then
        printToColor("Another deck is currently being imported. Please wait for that to finish.", pc)
        return
    end

    playerColor = pc
    deckSource = DECK_SOURCE_URL

    startLuaCoroutine(self, "importDeck")
end

function onLoadDeckNotebookButton(_, pc, _)
    if lock then
        printToColor("Another deck is currently being imported. Please wait for that to finish.", pc)
        return
    end

    playerColor = pc
    deckSource = DECK_SOURCE_NOTEBOOK

    startLuaCoroutine(self, "importDeck")
end

function onToggleAdvancedButton(_, _, _)
    advanced = not advanced
    drawUI()
end

function getCardBack()
    if not cardBackInput or string.len(cardBackInput) == 0 then
        return DEFAULT_CARDBACK
    else
        return cardBackInput
    end
end

function mtgdl__onCardBackInput(_, value, _)
    cardBackInput = value
    updateSave()
end

function getLanguageCode()
    if not languageInput or string.len(languageInput) == 0 then
        return DEFAULT_LANGUAGE
    else
        local code = LANGUAGES[string.lower(trim(languageInput))]
        return (code or DEFAULT_LANGUAGE)
    end
end

function getQuality()
  if not qualityInput or string.len(qualityInput) == 0 then
      return DEFAULT_QUALITY
  else
      return (qualityInput or DEFAULT_LANGUAGE)
  end
end

function mtgdl__onLanguageInput(_, value, _)
    languageInput = value
    updateSave()
end

function mtgdl__onQualDropdown(_, option, _)
  qualityInput = option:match('^%S+'):lower()
  drawUI()
  updateSave()
end

function mtgdl__onLangDropdown(_, option, _)
  languageInput = option:match('^%S+'):lower()
  drawUI()
  updateSave()
end

function mtgdl__onForceLanguageInput(_, value, _)
  if value:lower()=='true' then   -- pieHere, UI toggle gives a string?
    forceLanguage=true
  else
    forceLanguage=false
  end
  updateSave()
end

-- pieHere, toggle state combining or not
function mtgdl__onCombineStatesInput(_, value, _)
  if value:lower()=='true' then
    combineStates=true
  else
    combineStates=false
  end
  updateSave()
end

-- pieHere, toggle state combining or not
function mtgdl__onCacheBusterInput(ply, value, _)
  if value:lower()=='true' then
    cacheBuster=true
    printToColor(' ',ply.color)
    printToColor(' ------------------------ ',ply.color)
    ply.broadcast('This forces TTS to redownload the card images as opposed to using the ones it saved in its cache.\nYou should rather reset you image cache:\n☰ Menu → ☼ Configuration → Uncheck Mod Caching')
    printToColor(' ------------------------ ',ply.color)
  else
    cacheBuster=false
  end
  updateSave()
end


------ TTS CALLBACKS
-- pieHere, save global state!

------ GLOBAL STATE
function onLoad(saved_data)
    if saved_data ~= "" then
        local loaded_data = JSON.decode(saved_data)
        cardBackInput = loaded_data[1]
        combineStates = loaded_data[2]
        cacheBuster   = loaded_data[3]
        languageInput = loaded_data[4]
        qualityInput  = loaded_data[5]
    end
    drawUI()
end

function updateSave()
  local data_to_save = {cardBackInput, combineStates, cacheBuster, languageInput, qualityInput}
  saved_data = JSON.encode(data_to_save)
  self.script_state = saved_data
end


--------------------------------------------------------------------------------
-- pie's manual "JSON.decode" for scryfall's api output
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- which fields to extract?
-- these need to be in the order the appear in the json text
normal_card_keys={
  'object',
  'id',
  'oracle_id',
  'name',
  'printed_name',       --for non-EN cards
  'lang',
  'layout',
  'image_status',
  'image_uris',
  'mana_cost',
  'cmc',
  'type_line',
  'printed_type_line',  --for non-EN cards
  'oracle_text',
  'printed_text',       --for non-EN cards
  'defense',
  'loyalty',
  'power',
  'toughness',
  'set',
  'collector_number'
}

image_uris_keys={       -- "image_uris":{
  'small',
  'normal',
  'large',
  'png'
}

related_card_keys={     -- "all_parts":[{"object":"related_card",
  'id',
  'component',
  'name',
  'type_line',
  'uri',
}

card_face_keys={        -- "card_faces":[{"object":"card_face",
  'name',
  'printed_name',       --for non-EN cards
  'mana_cost',
  'cmc',
  'type_line',
  'printed_type_line',  --for non-EN cards
  'oracle_text',
  'printed_text',       --for non-EN cards
  'power',
  'toughness',
  'loyalty',
  'defense',
  'image_uris',
}

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
function JSONdecode(txt)
  local txtBeginning = txt:sub(1,16)
  local jsonType = txtBeginning:match('{"object":"(%w+)"')

  -- not scryfall? use normal JSON.decode
  if not(jsonType=='card' or jsonType=='list') then
    return JSON.decode(txt)
  end

  ------------------------------------------------------------------------------
  -- parse list: extract each card, and parse it separately
  -- used when one wants to decode a whole list
  if jsonType=='list' then
    local txtBeginning = txt:sub(1,80)
    local nCards=txtBeginning:match('"total_cards":(%d+)')
    if nCards==nil then
      return JSON.decode(txt)
    end
    local cardStart=0
    local cardEnd=0
    local cardDats = {}
    for i=1,nCards do     -- could insert max number cards to parse here
      cardStart=string.find(txt,'{"object":"card"',cardEnd+1)
      cardEnd = findClosingBracket(txt,cardStart)
      local cardDat = JSONdecode(txt:sub(cardStart,cardEnd))
      table.insert(cardDats,cardDat)
    end
    local dat = {object="list",total_cards=nCards,data=cardDats}    --ignoring has_more...
    return dat
  end

  ------------------------------------------------------------------------------
  -- parse card

  txt=txt:gsub('}',',}')    -- comma helps parsing last element in an array

  local cardDat={}
  local all_parts_i=string.find(txt,'"all_parts":')
  local card_faces_i=string.find(txt,'"card_faces":')

  -- if all_parts exist
  if all_parts_i~=nil then
    local st=string.find(txt,'%[',all_parts_i)
    local en=findClosingBracket(txt,st)
    local all_parts_txt = txt:sub(all_parts_i,en)
    local all_parts={}
    -- remove all_parts snip from the main text
    txt=txt:sub(1,all_parts_i-1)..txt:sub(en+2,-1)
    -- parse all_parts_txt for each related_card
    st=1
    local cardN=0
    while st~=nil do
      st=string.find(all_parts_txt,'{"object":"related_card"',st)
      if st~=nil then
        cardN=cardN+1
        en=findClosingBracket(all_parts_txt,st)
        local related_card_txt=all_parts_txt:sub(st,en)
        st=en
        local s,e=1,1
        local related_card={}
        for i,key in ipairs(related_card_keys) do
          val,s=getKeyValue(related_card_txt,key,s)
          related_card[key]=val
        end
        table.insert(all_parts,related_card)
        if cardN>30 then break end   -- avoid inf loop if something goes strange
      end
      cardDat.all_parts=all_parts
    end
  end

  -- if card_faces exist
  if card_faces_i~=nil then
    local st=string.find(txt,'%[',card_faces_i)
    local en=findClosingBracket(txt,st)
    local card_faces_txt = txt:sub(card_faces_i,en)
    local card_faces={}
    -- remove card_faces snip from the main text
    txt=txt:sub(1,card_faces_i-1)..txt:sub(en+2,-1)

    -- parse card_faces_txt for each card_face
    st=1
    local cardN=0
    while st~=nil do
      st=string.find(card_faces_txt,'{"object":"card_face"',st)
      if st~=nil then
        cardN=cardN+1
        en=findClosingBracket(card_faces_txt,st)
        local card_face_txt=card_faces_txt:sub(st,en)
        st=en
        local s,e=1,1
        local card_face={}
        for i,key in ipairs(card_face_keys) do
          val,s=getKeyValue(card_face_txt,key,s)
          card_face[key]=val
        end
        table.insert(card_faces,card_face)
        if cardN>4 then break end   -- avoid inf loop if something goes strange
      end
      cardDat.card_faces=card_faces
    end
  end

  -- normal card (or what's left of it after removing card_faces and all_parts)
  st=1
  for i,key in ipairs(normal_card_keys) do
    val,st=getKeyValue(txt,key,st)
    cardDat[key]=val
  end

  return cardDat
end

--------------------------------------------------------------------------------
-- returns data for one card at a time from a scryfall's "object":"list"
function getNextCardDatFromList(txt,startHere)

  if startHere==nil then
    startHere=1
  end

  local cardStart=string.find(txt,'{"object":"card"',startHere)
  if cardStart==nil then
    -- print('error: no more cards in list')
    startHere=nil
    return nil,nil,nil
  end

  local cardEnd = findClosingBracket(txt,cardStart)
  if cardEnd==nil then
    -- print('error: no more cards in list')
    startHere=nil
    return nil,nil,nil
  end

  -- startHere is not a local variable, so it's possible to just do:
  -- getNextCardFromList(txt) and it will keep giving the next card or nil if there's no more
  startHere=cardEnd+1

  local cardDat = JSONdecode(txt:sub(cardStart,cardEnd))

  return cardDat,cardStart,cardEnd
end

--------------------------------------------------------------------------------
function findClosingBracket(txt,st)   -- find paired {} or []
  if st==nil then return nil end
  local ob,cb='{','}'
  local pattern='[{}]'
  if txt:sub(st,st)=='[' then
    ob,cb='[',']'
    pattern='[%[%]]'
  end
  local txti=st
  local nopen=1
  while nopen>0 do
    txti=string.find(txt,pattern,txti+1)
    if txt:sub(txti,txti)==ob then
      nopen=nopen+1
    elseif txt:sub(txti,txti)==cb then
      nopen=nopen-1
    end
  end
  return txti
end

--------------------------------------------------------------------------------
function getKeyValue(txt,key,st)
  local str='"'..key..'":'
  local st=string.find(txt,str,st)
  local en=nil
  local value=nil
  if st~=nil then
    if key=='image_uris' then     -- special case for scryfall's image_uris table
      value={}
      local s=st
      for i,k in ipairs(image_uris_keys) do
        local val,s=getKeyValue(txt,k,s)
        value[k]=val
      end
      en=s
    elseif txt:sub(st+#str,st+#str)~='"' then      -- not a string
      en=string.find(txt,',"',st+#str+1)
      value=tonumber(txt:sub(st+#str,en-1))
    else                                           -- a string
      en=string.find(txt,'",',st+#str+1)
      value=txt:sub(st+#str+1,en-1):gsub('\\"','"'):gsub('\\n','\n'):gsub("\\u(%x%x%x%x)",function (x) return string.char(tonumber(x,16)) end)
    end
  end
  if type(value)=='string' then
    value=value:gsub(',}','}')    -- get rid of the previously inserted comma
  end
  return value,en
end



cardScript=[[
function onLoad()
  local enc=Global.getVar('Encoder')
  if enc==nil then
    self.createButton({
      click_function='spawnTokens',
      function_owner=self,
      label='T',
      tooltip='spawn token',
      position={0.77,0.28,-1.05},
      scale={0.5,0.5,0.5},
      width=300,
      height=300,
      font_size=250,
      color={0.1,0.1,0.1,0.75},
      font_color={1,1,1}
    })
  end
end
function spawnTokens()
  local jsonTxt=self.script_state
  if not(jsonTxt:find('"object":"list"')) then return end
  local json=JSON.decode(jsonTxt)
  local cardBackURL=self.getCustomObject().back
  local cPos=self.getPosition()+self.getTransformForward():scale(-3.2)
  local cRot=self.getRotation()
  for n,cardDat in ipairs(json.data) do
    local imagesuffix=''
    if cardDat.image_status~='highres_scan' then      -- cache buster for low quality images
      imagesuffix='?'..tostring(os.date("%x")):gsub('/', '')
    end
    local faceAddress,backAddress,cardName,cardDesc,backName,backDesc
    local backDat=nil
    if cardDat.image_uris then
      faceAddress=cardDat.image_uris.large:gsub('%?.*','')..imagesuffix
      cardName=cardDat.name:gsub('"','')..'\n'..cardDat.type_line..' '..cardDat.cmc..'CMC'
      cardDesc=setOracle(cardDat)
    elseif cardDat.card_faces then
      cardName=cardDat.card_faces[1].name:gsub('"','')..'\n'..cardDat.card_faces[1].type_line..' '..cardDat.cmc..'CMC DFC'
      cardDesc=setOracle(cardDat.card_faces[1])
      faceAddress=cardDat.card_faces[1].image_uris.large:gsub('%?.*','')..imagesuffix
      backAddress=cardDat.card_faces[2].image_uris.large:gsub('%?.*','')..imagesuffix
      if faceAddress:find('/back/') and backAddress:find('/front/') then
        local temp=faceAddress;faceAddress=backAddress;backAddress=temp
      end
      backName=cardDat.card_faces[2].name:gsub('"','')..'\n'..cardDat.card_faces[2].type_line..' '..cardDat.cmc..'CMC DFC'
      backDesc=setOracle(cardDat.card_faces[2])
      backDat={
        Transform={posX=0,posY=0,posZ=0,rotX=0,rotY=0,rotZ=0,scaleX=1,scaleY=1,scaleZ=1},
        Name="Card",
        Nickname=backName,
        Description=backDesc,
        Memo=cardDat.oracle_id,
        CardID=(n+10)*100,
        CustomDeck={[n+10]={FaceURL=backAddress,BackURL=cardBackURL,NumWidth=1,NumHeight=1,Type=0,BackIsHidden=true,UniqueBack=false}},
      }
    end
    local cardDat={
      Transform={posX=0,posY=0,posZ=0,rotX=0,rotY=0,rotZ=0,scaleX=1,scaleY=1,scaleZ=1},
      Name="Card",
      Nickname=cardName,
      Description=cardDesc,
      Memo=cardDat.oracle_id,
      CardID=n*100,
      CustomDeck={[n]={FaceURL=faceAddress,BackURL=cardBackURL,NumWidth=1,NumHeight=1,Type=0,BackIsHidden=true,UniqueBack=false}},
    }
    if backDat then
      cardDat.States={[2]=backDat}
    end
    spawnObjectData({data=cardDat,position=cPos,rotation=cRot})
  end
end
function setOracle(cardDat)
  local n='\n[b]'
  if cardDat.power then
    n=n..cardDat.power..'/'..cardDat.toughness
  elseif cardDat.loyalty then
    n=n..tostring(cardDat.loyalty)
  elseif cardData.defense then
    n=n..tostring(cardDat.defense)
  else
    n=false
  end
  return cardDat.oracle_text..(n and n..'[/b]'or'')
end
]]