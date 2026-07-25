--[[
    Gameplay tips shown in the compact quest tracker.

    Copy must stay short: the surface is only 360x40 and each tip is visible for ten seconds.
    Keep mechanics accurate and prefer one learning point per line.
]]

return {
    interval_seconds = 60,
    display_seconds = 10,
    max_characters = 88,

    tips = {
        "Berserk Brew boosts your pets in both combat and mining.",
        "Fortune Flask raises your luck while its green meter lasts.",
        "Swift Tonic helps you and your pets move faster.",
        "Weakening Vials make one enemy take more damage.",
        "Lock a potion slot to auto-drink when its meter runs low.",
        "One potion sip refills part of its meter; another sip tops it up.",

        "Natural enhancements work for every origin, but give the smallest boost.",
        "Dual-origin enhancements work for either listed origin.",
        "Single-origin enhancements are strongest, but only match one origin.",
        "Enhancements stop working when you outlevel them. Upgrade old slots.",
        "Recharge enhancements shorten cooldowns.",
        "Focus enhancements make powers cost less Focus.",
        "Range enhancements widen powers that affect an area.",
        "Duration enhancements keep eligible powers active longer.",
        "Use the Powers menu to fill empty enhancement slots.",
        "Replacing a filled enhancement slot destroys the old enhancement.",
        "Sell spare enhancements for gems.",
        "Upgrade All refreshes enhancements that have fallen behind your level.",

        "Running out of Focus? Slot Focus enhancements into costly powers.",
        "The Lumen Dove restores Focus while it supports your squad.",
        "The Ashwing helps your powers recharge faster.",
        "Support pets strengthen allies instead of dealing heavy damage.",
        "Tank pets draw attention and soak up damage.",
        "Melee pets are balanced close-range fighters.",
        "Ranged pets hit hard from safety, but have less health.",
        "Control pets disrupt enemies so the rest of the squad can attack.",
        "A hurt Bear becomes enraged and fights harder.",
        "Pet roles change combat behavior, not just card badges.",

        "Click a crystal to assign your squad and boost active mining.",
        "Resonance boosts nearby crystals for faster mining.",
        "Pet damage buffs also increase mining damage.",
        "A crystal's health bar shows how close it is to breaking.",
        "The boost bar shows the extra mining power you built up.",
        "Pets must reach a crystal before their mining damage starts.",
        "Ranged pets can begin mining from farther away.",
        "Stronger areas reward more, but their crystals are tougher.",
        "Mine with a team to share the work and earn team bonuses.",

        "Luck improves hatch results while the luck meter is active.",
        "Bunny support raises your hatch luck while deployed.",
        "Golden and Rainbow pets are stronger than their basic variants.",
        "Huge pets are rare, powerful, and kept by a Beginning reset.",
        "The egg preview shows each pet's role and support power badges.",
        "Auto-delete filters can clear unwanted hatch results.",
        "Your hatch count setting controls how many eggs one action opens.",
        "Recall returns you to the last egg you successfully hatched.",

        "Rally calls your squad back when a fight gets dangerous.",
        "Focus Fire tells the whole squad to pressure one target.",
        "Regroup pulls pets together and steadies the fight.",
        "Retreat breaks off the current fight.",
        "Farm Near sends idle pets to nearby crystals.",
        "Edit your hotbar to place powers where your fingers expect them.",
        "Hover a power in the hotbar editor to read what it does.",
        "Power tooltips show which enhancements actually improve that power.",

        "Temporary alliances can form when nearby players fight the same encounter.",
        "The strongest nearby player anchors a temporary alliance.",
        "Invite players to a team for persistent shared play.",
        "Trading can include pets, enhancements, and gems.",
        "Locked or unique pets cannot be traded away.",
        "Stacked pets still represent every copy shown on the card.",

        "World Travel only lists realms and origins you have unlocked.",
        "Choose a realm, then an origin, when using World Travel.",
        "Portal unlocks become fast-travel destinations.",
        "Heaven pets deal extra damage in Hell; Hell pets excel in Heaven.",
        "Your origin determines which origin enhancements you can use.",
        "Claim level rewards to unlock powers, slots, and new progression.",
        "If progress stalls, check Quests for a new active branch.",
        "Veteran levels continue rewarding enhancement rolls after level 50.",
        "Daily rewards improve when you return on consecutive days.",
        "The target outline marks what your selected pet is fighting.",
        "You can disable these rotating tips in Settings under Display Tips.",
    },
}
