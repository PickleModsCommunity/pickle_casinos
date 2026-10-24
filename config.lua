Config = {}
Config.Language = "en"
Config.Debug = false -- This enables debugging prints.
Config.RenderDistance = 50.0
Config.InteractDistance = 2.5
Config.UseTarget = true -- This enables the use of the target system when available.
Config.UseObjectGizmo = false -- This enables the use of object_gizmo for placing objects. If false, it uses the default movement system.
Config.MaximumChipPurchaseAmount = 1000000 -- Maximum amount of chips a player can purchase at once.
Config.MaximumItemPurchaseAmount = 100 -- Maximum amount of items a player can purchase at once.
Config.ExchangeRateLimits = { min = 1, max = 100 } -- Allowed range (percent) for casino owners' chip exchange rates. Keep max at 100 or below so buying chips never gives more chips than the money paid.
Config.ImageDirectory = "nui://ox_inventory/web/images/" -- (QB: nui://qb-inventory/html/images/) This is the directory where the images are stored. It should be a relative path to the resource folder.
Config.DisableIPIdentifier = true -- This disables the IP identifier from being sent to the logs.
Config.DisplayCurrencyAsChips = false -- This shows bet amounts and winnings as a number without any currency - set as false to disable this.
Config.BytesPerSecond = 25000 -- This is the amount of bytes per second that latent events will send when sending large events.
Config.MaxWager = 1000000

Config.LuckyTicket = {
    enabled = true,
    item = "lucky_ticket",                  -- inventory item name
    chipsPerTicket = 5000,                  -- award 1 ticket every N chips wagered cumulatively
    -- Games that count toward the cumulative wager. Default: all settle-paying games except lucky wheel.
    eligibleGames = {
        blackjack = true,
        baccarat = true,
        slots = true,
        roulette = true,
        thunder_roulette = true,
        poker = true,
        horseracing = true,
    },
}

Config.PlaceableEntities = { -- These are the entities that can be placed in the Personal Casinos update.
    ["blackjack"] = {item = "blackjack_table"},
    ["baccarat"] = {item = "baccarat_table"},
    ["roulette"] = {item = "roulette_table"},
    ["thunder_roulette"] = {item = "thunder_roulette_table"},
    ["poker"] = {item = "poker_table"},
    ["wheel"] = {item = "wheel_machine"},
    ["horseracing"] = {item = "horseracing_machine"},
    ["slot"] = {item = "slot_machine"},
}

Config.ToggleGameMode = function(state)
    if state then
        -- Do stuff when going into a game
    else
        -- Do stuff when exiting out of a game
    end
end

Config.GameTimes = { -- seatTurnTime is each person's time they get to decide an action, waitingTime is the betting round time.
    ["blackjack"] = {seatTurnTime = 15, waitingTime = 15},
    ["baccarat"] = {seatTurnTime = 15, waitingTime = 15},
    ["roulette"] = {seatTurnTime = 15, waitingTime = 15},
    ["thunder_roulette"] = {seatTurnTime = 15, waitingTime = 15},
    ["poker"] = {seatTurnTime = 15, waitingTime = 15},
    ["wheel"] = {seatTurnTime = 15, waitingTime = 15},
    ["horseracing"] = {seatTurnTime = 15, waitingTime = 15},
}

Config.CasinoBlip = {
    sprite = 679,
    color = 0,
    scale = 1.0,
}

Config.Currency = {
    currency = "USD",
    countryCode = "en-US",
}

Config.TargetIcons = {
    cashier = "fa-solid fa-coins",
    stores = "fa-solid fa-basket-shopping",
    management = "fa-solid fa-gear",
    blackjack = "fa-solid fa-play",
    roulette = "fa-solid fa-play",
    thunder_roulette = "fa-solid fa-bolt",
    baccarat = "fa-solid fa-play",
    poker = "fa-solid fa-play",
    wheel = "fa-solid fa-play",
    luckywheel = "fa-solid fa-play",
    horseracing = "fa-solid fa-play",
    slots = "fa-solid fa-play",
}

Config.AdminGroups = { -- These are the groups that are allowed to use the /casino command.
    "group.admin",
    "group.god",
    "admin",
    "superadmin",
    "god",
}

Config.Chips = {
    {color = "#15803D", value = 1},
    {color = "#C2410C", value = 5},
    {color = "#BE185D", value = 10},
    {color = "#3F3F46", value = 100},
    {color = "#0369A1", value = 1000},
    {color = "#15803D", value = 10000},
    {color = "#C2410C", value = 25000},
    {color = "#BE185D", value = 100000},
    {color = "#3F3F46", value = 250000},
    {color = "#0369A1", value = 1000000},
}

Config.TargetedModels = { -- These are the models that when scanning with /mapobjects will be added to the map objects list.
    -- SLOT MACHINES
    `vw_prop_casino_slot_01a`,
    `vw_prop_casino_slot_02a`,
    `vw_prop_casino_slot_03a`,
    `vw_prop_casino_slot_04a`,
    `vw_prop_casino_slot_05a`,
    `vw_prop_casino_slot_06a`,
    `vw_prop_casino_slot_07a`,
    `vw_prop_casino_slot_08a`,
    -- BLACKJACK TABLES
    `vw_prop_casino_blckjack_01`,
    `h4_prop_casino_blckjack_01a`,
    `h4_prop_casino_blckjack_01b`,
    `h4_prop_casino_blckjack_01c`,
    `h4_prop_casino_blckjack_01d`,
    `h4_prop_casino_blckjack_01e`,
    `vw_prop_casino_blckjack_01b`,
    -- ROULETTE TABLES
    `vw_prop_casino_roulette_01`,
    `vw_prop_casino_roulette_01b`,
    -- THUNDER ROULETTE TABLES (reuse roulette props by default)
    -- THREE CARD POKER TABLES
    `vw_prop_casino_3cardpoker_01`,
    `h4_prop_casino_3cardpoker_01c`,
    `h4_prop_casino_3cardpoker_01b`,
    `ch_prop_casino_poker_01a`,
    `h4_prop_casino_3cardpoker_01e`,
    `ch_prop_casino_poker_01b`,
    `h4_prop_casino_3cardpoker_01a`,
    `h4_prop_casino_3cardpoker_01d`,
    -- WHEEL
    `vw_prop_vw_luckywheel_01a`,
    `vw_prop_vw_luckywheel_02a`,
}

Config.AmbientAudio = {
    ["casino_ambient"] = {
        label = "Casino Ambient",
        audioBanks = {
            "DLC_VINEWOOD/CASINO_GENERAL",
            "DLC_VINEWOOD/CASINO_SLOT_MACHINES_01",
            "DLC_VINEWOOD/CASINO_SLOT_MACHINES_02",
            "DLC_VINEWOOD/CASINO_SLOT_MACHINES_03",
        },
        stream = "casino_walla",
        streamRef = "DLC_VW_Casino_Interior_Sounds",
        audioScene = "DLC_VW_Casino_General",
    },
}

Config.FrameworkSettings = {
    -- Note to framework creators: stop breaking your frameworks by moving / removing stuff in big 2025, if it continues I'm making pickle core
    society = "qb-management", -- This is the society that the casinos will use to pay taxes. (qb-management or qb-banking, if using ESX don't worry it's automatic)
    dirtyMoney = "DEFAULT", -- DEFAULT / item name (black_money, marked_bills, etc).
}

Config.Casinos = {
    vipExpireTime = 86400 * 7, -- Time in seconds before a VIP membership expires, set to 0 to make VIP permanent. (1 day = 86400 seconds)
    tax = 10, -- Percentage of the profit that the casino pays in tax when withdrawing clean cash from the management system.
    taxRecipients = { -- This should always add up to 100%; above is where you set the percentage of the tax.
        ["police"] = 50, -- The percentage of the tax paid by the casinos to this society.
        ["ambulance"] = 50, -- The percentage of the tax paid by the casinos to this society.
    },
    profitPercent = 5 -- (0-100) Percentage of the profit that the casino takes from the store.
}

Config.CreatorOptions = {
    -- MODELS MUST BE `MODEL_NAME` NOT "MODEL_NAME"
    stores = {
        {
            label = "Burgershot",
            items = {
                {item = "hamburger", price = 10},
                {item = "crisps", price = 3},
                {item = "soda", price = 2},
            }
        },
        {
            label = "Pickle's Brewery",
            items = {
                {item = "cigbox", price = 10},
                {item = "cigarette", price = 2},
                {item = "beer", price = 3},
                {item = "gin_shot", price = 4},
                {item = "vodka_shot", price = 5},
                {item = "whiskey_bottle", price = 15},
                {item = "tequila_bottle", price = 25},
                {item = "vodka_bottle", price = 50},
            }
        },
    },
    dealerModels = {
        {
            label = "Male Dealer #1", 
            model = `s_m_y_casino_01`,
            pedComponents = {
                {id = 0, drawable = 3, texture = 0}, -- Head
                {id = 1, drawable = 1, texture = 0}, -- Beard
                {id = 2, drawable = 3, texture = 0}, -- Hair   
                {id = 3, drawable = 1, texture = 0}, -- Upper
                {id = 4, drawable = 0, texture = 0}, -- Lower
                {id = 5, drawable = 0, texture = 0}, -- Hand
                {id = 6, drawable = 1, texture = 0}, -- Feet
                {id = 7, drawable = 2, texture = 0}, -- Teeth
                {id = 8, drawable = 3, texture = 0}, -- Accessories
                {id = 9, drawable = 0, texture = 0}, -- Task
                {id = 10, drawable = 1, texture = 0}, -- Decals
                {id = 11, drawable = 1, texture = 0}, -- Torso
            }
        },
        {
            label = "Male Dealer #2", 
            model = `s_m_y_casino_01`,
            pedComponents = {
                {id = 0, drawable = 2, texture = 0}, -- Head
                {id = 1, drawable = 1, texture = 0}, -- Beard
                {id = 2, drawable = 4, texture = 0}, -- Hair   
                {id = 3, drawable = 0, texture = 0}, -- Upper
                {id = 4, drawable = 0, texture = 0}, -- Lower
                {id = 5, drawable = 0, texture = 0}, -- Hand
                {id = 6, drawable = 1, texture = 0}, -- Feet
                {id = 7, drawable = 2, texture = 0}, -- Teeth
                {id = 8, drawable = 1, texture = 0}, -- Accessories
                {id = 9, drawable = 0, texture = 0}, -- Task
                {id = 10, drawable = 1, texture = 0}, -- Decals
                {id = 11, drawable = 1, texture = 0}, -- Torso
            }
        },
        {
            label = "Male Dealer #3", 
            model = `s_m_y_casino_01`,
            pedComponents = {
                {id = 0, drawable = 0, texture = 0}, -- Head
                {id = 1, drawable = 0, texture = 0}, -- Beard
                {id = 2, drawable = 0, texture = 0}, -- Hair   
                {id = 3, drawable = 0, texture = 0}, -- Upper
                {id = 4, drawable = 0, texture = 0}, -- Lower
                {id = 5, drawable = 0, texture = 0}, -- Hand
                {id = 6, drawable = 0, texture = 0}, -- Feet
                {id = 7, drawable = 0, texture = 0}, -- Teeth
                {id = 8, drawable = 0, texture = 0}, -- Accessories
                {id = 9, drawable = 0, texture = 0}, -- Task
                {id = 10, drawable = 0, texture = 0}, -- Decals
                {id = 11, drawable = 0, texture = 0}, -- Torso
            }
        },
        {
            label = "Female Dealer #1", 
            model = `s_f_y_casino_01`,
            pedComponents = {
                {id = 0, drawable = 3, texture = 0}, -- Head
                {id = 1, drawable = 0, texture = 0}, -- Beard
                {id = 2, drawable = 3, texture = 0}, -- Hair   
                {id = 3, drawable = 0, texture = 0}, -- Upper
                {id = 4, drawable = 1, texture = 0}, -- Lower
                -- {id = 5, drawable = 1, texture = 0}, -- Hand
                {id = 6, drawable = 1, texture = 0}, -- Feet
                {id = 7, drawable = 1, texture = 0}, -- Teeth
                {id = 8, drawable = 0, texture = 0}, -- Accessories
                -- {id = 9, drawable = 0, texture = 0}, -- Task
                {id = 10, drawable = 0, texture = 0}, -- Decals
                {id = 11, drawable = 0, texture = 0}, -- Torso
            }
        },
        {
            label = "Female Dealer #2", 
            model = `s_f_y_casino_01`,
            pedComponents = {
                {id = 0, drawable = 2, texture = 0}, -- Head
                {id = 1, drawable = 0, texture = 0}, -- Beard
                {id = 2, drawable = 2, texture = 0}, -- Hair   
                {id = 3, drawable = 3, texture = 0}, -- Upper
                {id = 4, drawable = 1, texture = 0}, -- Lower
                -- {id = 5, drawable = 0, texture = 0}, -- Hand
                {id = 6, drawable = 1, texture = 0}, -- Feet
                {id = 7, drawable = 2, texture = 0}, -- Teeth
                {id = 8, drawable = 3, texture = 0}, -- Accessories
                -- {id = 9, drawable = 0, texture = 0}, -- Task
                {id = 10, drawable = 0, texture = 0}, -- Decals
                {id = 11, drawable = 0, texture = 0}, -- Torso
            }
        },
        {
            label = "Female Dealer #3", 
            model = `s_f_y_casino_01`,
            pedComponents = {
                {id = 0, drawable = 0, texture = 0}, -- Head
                {id = 1, drawable = 0, texture = 0}, -- Beard
                {id = 2, drawable = 0, texture = 0}, -- Hair   
                {id = 3, drawable = 0, texture = 0}, -- Upper
                {id = 4, drawable = 0, texture = 0}, -- Lower
                {id = 5, drawable = 0, texture = 0}, -- Hand
                {id = 6, drawable = 0, texture = 0}, -- Feet
                {id = 7, drawable = 0, texture = 0}, -- Teeth
                {id = 8, drawable = 0, texture = 0}, -- Accessories
                {id = 9, drawable = 0, texture = 0}, -- Task
                {id = 10, drawable = 0, texture = 0}, -- Decals
                {id = 11, drawable = 0, texture = 0}, -- Torso
            }
        },
    },
    blackjack = {
        tableModels = {
            {label = "Table #1", model = `h4_prop_casino_blckjack_01a`},
            {label = "Table #2", model = `vw_prop_casino_blckjack_01`},
            {label = "Table #3", model = `h4_prop_casino_blckjack_01c`},
            {label = "Table #4", model = `h4_prop_casino_blckjack_01e`},
            {label = "Table #5", model = `vw_prop_casino_blckjack_01b`},
            {label = "Table #6", model = `h4_prop_casino_blckjack_01d`},
            {label = "Table #7", model = `h4_prop_casino_blckjack_01b`},
        }
    },
    roulette = {
        tableModels = {
            {label = "Table #1", model = `vw_prop_casino_roulette_01`},
            {label = "Table #2", model = `vw_prop_casino_roulette_01b`},
        }
    },
    thunder_roulette = {
        tableModels = {
            {label = "Table #1", model = `vw_prop_casino_roulette_01`},
            {label = "Table #2", model = `vw_prop_casino_roulette_01b`},
        }
    },
    baccarat = {
        tableModels = {
            {label = "Table #1", model = `fury_p_baccarat`},
        }
    },
    poker = {
        tableModels = {
            {label = "Table #1", model = `fury_p_poker_table`},
        }
    },
    luckywheel = {
        wheelModels = {
            {label = "Wheel #1", model = `vw_prop_vw_luckywheel_02a`},
            -- Add MLO wheel models here if you want to use them.
        }
    },
    wheel = {}, -- No additional settings
    horseracing = {}, -- No additional settings
    slots = {}, -- No additional settings
}

------------------------------------------------------------------------------------------------------------------------
-- DO NOT TOUCH THE BELOW UNLESS YOU KNOW WHAT YOU'RE DOING, I WILL NOT HELP YOU WITH THIS (unless i broke it)
------------------------------------------------------------------------------------------------------------------------

Config.Poker = {
    buttonModel = `vw_prop_vw_colle_imporage`, -- This prop indicates who is the dealer.
}

Config.Roulette = {
    StraightPayout = 36, -- Multiplier paid on a winning single-number (straight) bet. Standard roulette is 36x.
}

-- Blackjack dealer odds: rigs the dealer's cards in the house's favor by the configured
-- percentages. Both values are a percent chance out of 100, rolled with math.random(100).
-- Set either to 0 to disable it and leave that phase fully random.
Config.BlackjackOdds = {
    -- Chance that the dealer's opening two cards are forced into a natural blackjack
    -- (an Ace paired with a 10/Jack/Queen/King). Rolled once per round, before the deal.
    BlackjackPossibility = 0,
    -- Chance that a card the dealer draws (while under 17) is forced to a value that
    -- lands the dealer on exactly 21. Rolled per drawn card; if no card can make 21
    -- from the dealer's current hand, a normal random card is dealt instead.
    DrawBlackjackPossibility = 0,
}

-- Thunder Roulette: each round picks N "thunder" numbers from the wheel and assigns
-- each a multiplier. If the ball lands on a thunder number, straight-number bets on
-- that number pay `wager * multiplier` instead of the normal 36x.
--
-- RTP note: with the defaults below, mean count ~= 1.83, mean multiplier ~= 67,
-- giving an expected straight-bet RTP near ~98.7% (slightly below 100%, keeping a
-- small house edge while feeling generous). Tighten by lowering the rare-tier
-- multiplier weights; loosen by raising them.
Config.ThunderRoulette = {
    StraightPayout = 29, -- Multiplier paid on a non-thunder straight (single-number) win. Thunder strikes use their own per-number multiplier instead.
    SpinDuration = 10000, -- ms; matches base roulette spin timing.
    -- Weighted distribution for how many thunder numbers per round.
    NumberCounts = {
        { value = 1, weight = 50 },
        { value = 2, weight = 25 },
        { value = 3, weight = 15 },
        { value = 4, weight = 7 },
        { value = 5, weight = 3 },
    },
    -- Weighted multiplier values awarded per thunder number.
    Multipliers = {
        { value = 50,  weight = 60 },
        { value = 75,  weight = 25 },
        { value = 100, weight = 10 },
        { value = 150, weight = 4 },
        { value = 250, weight = 1 },
    },
}

Config.WheelMultiplier = {
    two = 2,
    three = 3,
    five = 5,
    eleven = 11,
    twentyThree = 23,
    -- Bonus is handled in Config.WheelBonus
}

Config.WheelBonus = {
    {
        multiplier = 5,
        chance = 115,
    },
    {
        multiplier = 10,
        chance = 110,
    },
    {
        multiplier = 25,
        chance = 105,
    },
    {
        multiplier = 50,
        chance = 100,
    },
    {
        multiplier = 100,
        chance = 25,
    },
    {
        multiplier = 1000,
        chance = 1,
    },
}

Config.Slots = {
    ["bananabonanza"] = {
        label = "Banana Bonanza",
        model = `fury_p_slot_01`,
        foldername = "bananabonanza",
        headerTextImage = "header_title.png",
        backgroundImage = "background.png",
        reelCount = 5,
        reelSymbols = 3,
        paylineWinThreshold = 3,
        bonusTriggerCount = 3,
        bonusFreeSpins = 15,
        bonusSymbol = "Bonus Symbol",
        slotSymbols = {
            ["Bonus Symbol"] = {
                image = "bonus.png",
                reels = {8, 8, 1, 1, 1},
                pay = {0, 0, 0, 0, 0},
            },
            ["Monkey"] = {
                image = "monkey.png",
                reels = {15, 12, 10, 10, 15},
                pay = {0, 0, 3, 7, 30},
            },
            ["Coconut"] = {
                image = "coconut.png",
                reels = {15, 15, 10, 10, 15},
                pay = {0, 0, 1.5, 3.5, 10},
            },
            ["Coconut Tree Bundle"] = {
                image = "tree_2.png",
                reels = {15, 12, 10, 10, 12},
                pay = {0, 0, 1.2, 2, 6},
            },
            ["Coconut Tree"] = {
                image = "tree_1.png",
                reels = {11, 11, 10, 10, 11},
                pay = {0, 0, 0.8, 1.5, 4},
            },
            ["Banana Bunch"] = {
                image = "banana_2.png",
                reels = {10, 10, 10, 10, 10},
                pay = {0, 0, 0.35, 0.6, 1.75},
            },
            ["Banana"] = {
                image = "banana_1.png",
                reels = {10, 10, 10, 10, 10},
                pay = {0, 0, 0.2, 0.35, 1.25},
            },
        },
        paylines = {
            {1, 1, 1, 1, 1},
            {0, 0, 0, 0, 0},
            {2, 2, 2, 2, 2},
            {0, 1, 2, 1, 0},
            {2, 1, 0, 1, 2},
            {1, 0, 0, 0, 1},
            {1, 2, 2, 2, 1},
            {0, 0, 1, 2, 2},
            {2, 2, 1, 0, 0},
            {1, 2, 1, 0, 1},
            {1, 0, 1, 2, 1},
            {0, 1, 1, 1, 0},
            {2, 1, 1, 1, 2},
            {0, 1, 0, 1, 0},
            {2, 1, 2, 1, 2},
            {1, 1, 0, 1, 1},
            {1, 1, 2, 1, 1},
            {0, 0, 2, 0, 0},
            {2, 2, 0, 2, 2},
            {0, 2, 2, 2, 0},
        },
    },
    ["spacewarriors"] = {
        label = "Space Warriors",
        model = `fury_p_slot_02`,
        foldername = "spacewarriors",
        headerTextImage = "header_title.png",
        backgroundImage = "background.png",
        reelCount = 5,
        reelSymbols = 3,
        paylineWinThreshold = 3,
        bonusTriggerCount = 3,
        bonusFreeSpins = 15,
        bonusSymbol = "Bonus Symbol",
        slotSymbols = {
            ["Bonus Symbol"] = {
                image = "bonus.png",
                reels = {8, 8, 1, 1, 1},
                pay = {0, 0, 0, 0, 0},
            },
            ["Spaceship"] = {
                image = "spaceship.png",
                reels = {15, 12, 10, 10, 15},
                pay = {0, 0, 3, 7, 30},
            },
            ["Rocket"] = {
                image = "rocket.png",
                reels = {15, 15, 10, 10, 15},
                pay = {0, 0, 1.5, 3.5, 10},
            },
            ["Blaster"] = {
                image = "blaster.png",
                reels = {15, 12, 10, 10, 12},
                pay = {0, 0, 1.2, 2, 6},
            },
            ["Mars"] = {
                image = "mars.png",
                reels = {11, 11, 10, 10, 11},
                pay = {0, 0, 0.8, 1.5, 4},
            },
            ["Earth"] = {
                image = "earth.png",
                reels = {10, 10, 10, 10, 10},
                pay = {0, 0, 0.35, 0.6, 1.75},
            },
            ["Asteroid"] = {
                image = "asteroid.png",
                reels = {10, 10, 10, 10, 10},
                pay = {0, 0, 0.2, 0.35, 1.25},
            },
        },
        paylines = {
            {1, 1, 1, 1, 1},
            {0, 0, 0, 0, 0},
            {2, 2, 2, 2, 2},
            {0, 1, 2, 1, 0},
            {2, 1, 0, 1, 2},
            {1, 0, 0, 0, 1},
            {1, 2, 2, 2, 1},
            {0, 0, 1, 2, 2},
            {2, 2, 1, 0, 0},
            {1, 2, 1, 0, 1},
            {1, 0, 1, 2, 1},
            {0, 1, 1, 1, 0},
            {2, 1, 1, 1, 2},
            {0, 1, 0, 1, 0},
            {2, 1, 2, 1, 2},
            {1, 1, 0, 1, 1},
            {1, 1, 2, 1, 1},
            {0, 0, 2, 0, 0},
            {2, 2, 0, 2, 2},
            {0, 2, 2, 2, 0},
        },
    },
    ["candybonanza"] = {
        label = "Candy Bonanza",
        model = `fury_p_slot_03`,
        foldername = "candybonanza",
        headerTextImage = "header_title.png",
        backgroundImage = "background.png",
        reelCount = 5,
        reelSymbols = 3,
        paylineWinThreshold = 3,
        bonusTriggerCount = 3,
        bonusFreeSpins = 15,
        bonusSymbol = "Bonus Symbol",
        slotSymbols = {
            ["Bonus Symbol"] = {
                image = "bonus.png",
                reels = {8, 8, 1, 1, 1},
                pay = {0, 0, 0, 0, 0},
            },
            ["Peppermint"] = {
                image = "peppermint.png",
                reels = {15, 12, 10, 10, 15},
                pay = {0, 0, 3, 7, 30},
            },
            ["Candystick"] = {
                image = "candystick.png",
                reels = {15, 15, 10, 10, 15},
                pay = {0, 0, 1.5, 3.5, 10},
            },
            ["Banana Pop"] = {
                image = "banana_pop.png",
                reels = {15, 12, 10, 10, 12},
                pay = {0, 0, 1.2, 2, 6},
            },
            ["Pickle Pop"] = {
                image = "pickle_pop.png",
                reels = {11, 11, 10, 10, 11},
                pay = {0, 0, 0.8, 1.5, 4},
            },
            ["Strawberry Pop"] = {
                image = "strawberry_pop.png",
                reels = {10, 10, 10, 10, 10},
                pay = {0, 0, 0.35, 0.6, 1.75},
            },
            ["Raspberry Pop"] = {
                image = "raspberry_pop.png",
                reels = {10, 10, 10, 10, 10},
                pay = {0, 0, 0.2, 0.35, 1.25},
            },
        },
        paylines = {
            {1, 1, 1, 1, 1},
            {0, 0, 0, 0, 0},
            {2, 2, 2, 2, 2},
            {0, 1, 2, 1, 0},
            {2, 1, 0, 1, 2},
            {1, 0, 0, 0, 1},
            {1, 2, 2, 2, 1},
            {0, 0, 1, 2, 2},
            {2, 2, 1, 0, 0},
            {1, 2, 1, 0, 1},
            {1, 0, 1, 2, 1},
            {0, 1, 1, 1, 0},
            {2, 1, 1, 1, 2},
            {0, 1, 0, 1, 0},
            {2, 1, 2, 1, 2},
            {1, 1, 0, 1, 1},
            {1, 1, 2, 1, 1},
            {0, 0, 2, 0, 0},
            {2, 2, 0, 2, 2},
            {0, 2, 2, 2, 0},
        },
    },
}

Config.HorseRacing = {
    machineModel = `npds_bettingmachine_01`,
    tracks = {
        {
            label = "Track #1",
            coords = vector3(1158.0900, 258.6992, 80.8438),
            heading = 147.9117,
            distance = 171.15, -- Length of the track in meters
            renderDistance = 500.0, -- Distance at which the track and horses will render for people nearby.
        },
        {
            label = "Track #2",
            coords = vector3(1266.5555, 191.2764, 80.8438),
            heading = 147.9117,
            distance = 171.15, -- Length of the track in meters
            renderDistance = 500.0, -- Distance at which the track and horses will render for people nearby.
        }
    },
    odds = {
        {
            label = "40/1",
            multiplier = 40,
            chances = 2,
        },
        {
            label = "30/1",
            multiplier = 30,
            chances = 3,
        },
        {
            label = "20/1",
            multiplier = 20,
            chances = 4,
        },
        {
            label = "15/1",
            multiplier = 15,
            chances = 5,
        },
        {
            label = "10/1",
            multiplier = 10,
            chances = 6,
        },
        {
            label = "7/1",
            multiplier = 7,
            chances = 7,
        },
        {
            label = "5/1",
            multiplier = 5,
            chances = 9,
        },
        {
            label = "4/1",
            multiplier = 4,
            chances = 10,
        },
        {
            label = "3/1",
            multiplier = 3,
            chances = 12,
        },
        {
            label = "2/1",
            multiplier = 2,
            chances = 16,
        },
        {
            label = "1/1",
            multiplier = 1,
            chances = 32,
        },
        {
            label = "1/2",
            multiplier = 0.5,
            chances = 64,
        },
    }
}

Config.LuckyWheel = {
    spinCooldown = 86400 * 1, -- Time in seconds before the player can spin again. (1 day = 86400 seconds)
    paidCooldown = true, -- If true, the player will have to wait the cooldown out even if the spin costs money.
    rotateVehicle = true, -- If true, the vehicle will rotate when the wheel is spinning.
    sections = {
        ["vehicle"] = { 
            chance = 1,
            chooseRandomReward = true, -- If true, it will choose a random prize from the list below - otherwise it will use the first one
            rewards = { -- When casinoCost is above 0, it will require player-owned casinos to have the money to pay this prize, if they don't the wager will be refunded and prize(s) will be cancelled.
                -- THE FIRST VEHICLE IN THIS LIST WILL BE THE DISPLAY VEHICLE.
                {type = "vehicle", label = "Adder", model = "adder", casinoCost = 100000, name = "Adder"},
            },
        },
        ["mystery"] = { 
            chance = 5,
            chooseRandomReward = true, -- If true, it will choose a random prize from the list below - otherwise it will use the first one
            rewards = { -- When casinoCost is above 0, it will require player-owned casinos to have the money to pay this prize, if they don't the wager will be refunded and prize(s) will be cancelled.
                {type = "money", amount = 25000, casinoCost = 25000},
                {type = "item", name = "shirt", amount = 1, casinoCost = 10}, -- cost is 0 because chips are exchanged for money in the casino, so it doesn't cost the casino anything.
                {type = "chips", amount = 50000, casinoCost = 0}, -- cost is 0 because chips are exchanged for money in the casino, so it doesn't cost the casino anything.
            },
        },
        ["discount"] = { 
            chance = 20,
            chooseRandomReward = true, -- If true, it will choose a random prize from the list below - otherwise it will use the first one
            rewards = { -- When casinoCost is above 0, it will require player-owned casinos to have the money to pay this prize, if they don't the wager will be refunded and prize(s) will be cancelled.
                {type = "money", amount = 1000, casinoCost = 1000},
            },
        },
        ["clothing"] = { 
            chance = 20,
            chooseRandomReward = true, -- If true, it will choose a random prize from the list below - otherwise it will use the first one
            rewards = { -- When casinoCost is above 0, it will require player-owned casinos to have the money to pay this prize, if they don't the wager will be refunded and prize(s) will be cancelled.
                {type = "item", name = "shirt", amount = 1, casinoCost = 10}, -- cost is 0 because chips are exchanged for money in the casino, so it doesn't cost the casino anything.
            },
        },
        ["money_50k"] = { 
            chance = 10,
            chooseRandomReward = false, -- If true, it will choose a random prize from the list below - otherwise it will use the first one
            rewards = { -- When casinoCost is above 0, it will require player-owned casinos to have the money to pay this prize, if they don't the wager will be refunded and prize(s) will be cancelled.
                {type = "money", amount = 50000, casinoCost = 50000},
            },
        },
        ["money_40k"] = { 
            chance = 10,
            chooseRandomReward = true, -- If true, it will choose a random prize from the list below - otherwise it will use the first one
            rewards = { -- When casinoCost is above 0, it will require player-owned casinos to have the money to pay this prize, if they don't the wager will be refunded and prize(s) will be cancelled.
                {type = "money", amount = 40000, casinoCost = 40000},
            },
        },
        ["money_30k"] = { 
            chance = 10,
            chooseRandomReward = true, -- If true, it will choose a random prize from the list below - otherwise it will use the first one
            rewards = { -- When casinoCost is above 0, it will require player-owned casinos to have the money to pay this prize, if they don't the wager will be refunded and prize(s) will be cancelled.
                {type = "money", amount = 30000, casinoCost = 30000},
            },
        },
        ["money_20k"] = { 
            chance = 10,
            chooseRandomReward = true, -- If true, it will choose a random prize from the list below - otherwise it will use the first one
            rewards = { -- When casinoCost is above 0, it will require player-owned casinos to have the money to pay this prize, if they don't the wager will be refunded and prize(s) will be cancelled.
                {type = "money", amount = 20000, casinoCost = 20000},
            },
        },
        ["chips_25k"] = { 
            chance = 10,
            chooseRandomReward = true, -- If true, it will choose a random prize from the list below - otherwise it will use the first one
            rewards = { -- When casinoCost is above 0, it will require player-owned casinos to have the money to pay this prize, if they don't the wager will be refunded and prize(s) will be cancelled.
                {type = "chips", amount = 25000, casinoCost = 0}, -- cost is 0 because chips are exchanged for money in the casino, so it doesn't cost the casino anything.
            },
        },
        ["chips_20k"] = { 
            chance = 10,
            chooseRandomReward = true, -- If true, it will choose a random prize from the list below - otherwise it will use the first one
            rewards = { -- When casinoCost is above 0, it will require player-owned casinos to have the money to pay this prize, if they don't the wager will be refunded and prize(s) will be cancelled.
                {type = "chips", amount = 20000, casinoCost = 0}, -- cost is 0 because chips are exchanged for money in the casino, so it doesn't cost the casino anything.
            },
        },
        ["chips_15k"] = { 
            chance = 10,
            chooseRandomReward = true, -- If true, it will choose a random prize from the list below - otherwise it will use the first one
            rewards = { -- When casinoCost is above 0, it will require player-owned casinos to have the money to pay this prize, if they don't the wager will be refunded and prize(s) will be cancelled.
                {type = "chips", amount = 15000, casinoCost = 0}, -- cost is 0 because chips are exchanged for money in the casino, so it doesn't cost the casino anything.
            },
        },
        ["chips_10k"] = { 
            chance = 10,
            chooseRandomReward = true, -- If true, it will choose a random prize from the list below - otherwise it will use the first one
            rewards = { -- When casinoCost is above 0, it will require player-owned casinos to have the money to pay this prize, if they don't the wager will be refunded and prize(s) will be cancelled.
                {type = "chips", amount = 10000, casinoCost = 0}, -- cost is 0 because chips are exchanged for money in the casino, so it doesn't cost the casino anything.
            },
        },
        ["rp_15k"] = { 
            chance = 15,
            chooseRandomReward = true, -- If true, it will choose a random prize from the list below - otherwise it will use the first one
            rewards = { -- When casinoCost is above 0, it will require player-owned casinos to have the money to pay this prize, if they don't the wager will be refunded and prize(s) will be cancelled.
                {type = "xp", name = "casino", amount = 15000, casinoCost = 0}, -- cost is 0 because chips are exchanged for money in the casino, so it doesn't cost the casino anything.
            },
        },
        ["rp_10k"] = { 
            chance = 15,
            chooseRandomReward = true, -- If true, it will choose a random prize from the list below - otherwise it will use the first one
            rewards = { -- When casinoCost is above 0, it will require player-owned casinos to have the money to pay this prize, if they don't the wager will be refunded and prize(s) will be cancelled.
                {type = "xp", name = "casino", amount = 10000, casinoCost = 0}, -- cost is 0 because chips are exchanged for money in the casino, so it doesn't cost the casino anything.
            },
        },
        ["rp_7k"] = { 
            chance = 15,
            chooseRandomReward = true, -- If true, it will choose a random prize from the list below - otherwise it will use the first one
            rewards = { -- When casinoCost is above 0, it will require player-owned casinos to have the money to pay this prize, if they don't the wager will be refunded and prize(s) will be cancelled.
                {type = "xp", name = "casino", amount = 7500, casinoCost = 0}, -- cost is 0 because chips are exchanged for money in the casino, so it doesn't cost the casino anything.
            },
        },
        ["rp_5k"] = { 
            chance = 15,
            chooseRandomReward = true, -- If true, it will choose a random prize from the list below - otherwise it will use the first one
            rewards = { -- When casinoCost is above 0, it will require player-owned casinos to have the money to pay this prize, if they don't the wager will be refunded and prize(s) will be cancelled.
                {type = "xp", name = "casino", amount = 5000, casinoCost = 0}, -- cost is 0 because chips are exchanged for money in the casino, so it doesn't cost the casino anything.
            },
        },
        ["rp_2k"] = { 
            chance = 15,
            chooseRandomReward = true, -- If true, it will choose a random prize from the list below - otherwise it will use the first one
            rewards = { -- When casinoCost is above 0, it will require player-owned casinos to have the money to pay this prize, if they don't the wager will be refunded and prize(s) will be cancelled.
                {type = "xp", name = "casino", amount = 2500, casinoCost = 0}, -- cost is 0 because chips are exchanged for money in the casino, so it doesn't cost the casino anything.
            },
        },
    }
}