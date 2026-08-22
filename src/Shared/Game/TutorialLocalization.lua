--[[
    TutorialLocalization — small, explicit catalog for the new-player tutorial.

    Halo & Horns is not fully localized yet. This module deliberately translates only the
    tutorial surfaces and always falls back to the authored English config copy. Locale IDs come
    from Roblox (for example "es-mx" or "pt-br") and are reduced to a supported language here.
]]

local TutorialLocalization = {}

local CATALOG = {
    en = {
        ["tutorial.progress"] = "TUTORIAL  %d / %d",
        ["tutorial.complete_label"] = "TUTORIAL COMPLETE",
        ["tutorial.cue.click_here"] = "CLICK HERE",
        ["tutorial.target.mine"] = "⬇ MINE",
        ["tutorial.target.hatch"] = "⬇ HATCH",
        ["tutorial.target.go"] = "⬇ GO",
        ["tutorial.target.fight"] = "⬇ FIGHT",
        ["tutorial.language_banner"] = "Your tutorial language is %s. You can switch to English in Settings.",
    },
    es = {
        ["tutorial.progress"] = "TUTORIAL  %d / %d",
        ["tutorial.complete_label"] = "TUTORIAL COMPLETADO",
        ["tutorial.cue.click_here"] = "HAZ CLIC AQUÍ",
        ["tutorial.target.mine"] = "⬇ MINA",
        ["tutorial.target.hatch"] = "⬇ ABRE",
        ["tutorial.target.go"] = "⬇ VE",
        ["tutorial.target.fight"] = "⬇ LUCHA",
        ["tutorial.language_banner"] = "Tu idioma es %s. El tutorial usará este idioma. Puedes cambiarlo a inglés en Ajustes.",

        ["tutorial.hatch_first_egg.title"] = "Abre tu primer huevo",
        ["tutorial.hatch_first_egg.body"] = "Tu compañero necesita otro aliado. Sigue el camino al Huevo de Tierra y abre uno.",
        ["tutorial.hatch_first_egg.body_gamepad"] = "Tu compañero necesita otro aliado. Sigue el camino al Huevo de Tierra y pulsa X para abrirlo.",
        ["tutorial.farm_crystals.title"] = "Extrae cristales",
        ["tutorial.farm_crystals.body"] = "Tu escuadrón mina cristales cercanos con Farm Near ACTIVO. Haz clic en uno pequeño para POTENCIARLO y gana 100 monedas.",
        ["tutorial.farm_crystals.body_gamepad"] = "Tu escuadrón mina cristales cercanos con Farm Near ACTIVO. Acércate a uno pequeño para POTENCIARLO y gana 100 monedas.",
        ["tutorial.hatch_another.title"] = "Amplía tu escuadrón",
        ["tutorial.hatch_another.body"] = "Gasta esas monedas en otro huevo. Más mascotas significa minar más rápido.",
        ["tutorial.hatch_another.body_gamepad"] = "Gasta esas monedas en otro huevo. Acércate y pulsa X; más mascotas minan más rápido.",
        ["tutorial.build_squad.title"] = "Forma tu escuadrón",
        ["tutorial.build_squad.body"] = "Aquí eliges qué mascotas luchan contigo. Abre Mascotas y mira; puedes conservar tu escuadrón actual.",
        ["tutorial.build_squad.body_gamepad"] = "Aquí eliges qué mascotas luchan contigo. Pulsa izquierda en la cruceta para abrir Mascotas y elige con A.",
        ["tutorial.build_squad.body_with_unequipped"] = "Ahora tienes más mascotas para elegir. Abre Mascotas y decide quién lucha contigo. Puedes cambiar una o conservar tu escuadrón.",
        ["tutorial.bind_power.title"] = "Asigna tu poder",
        ["tutorial.bind_power.body"] = "Naciste con Resonancia. Pulsa Editar en la barra y coloca Resonancia en una ranura. Harás esto con cada poder nuevo.",
        ["tutorial.bind_power.body_gamepad"] = "Naciste con Resonancia. Pulsa derecha en la cruceta, elige Resonancia con A y asígnala a una ranura.",
        ["tutorial.cast_power.title"] = "Usa Resonancia",
        ["tutorial.cast_power.body"] = "Pulsa esa ranura cerca de cristales. Resonancia hace que se rompan más rápido y den más moneda.",
        ["tutorial.cast_power.body_gamepad"] = "Elige Resonancia con LB/RB y pulsa RT cerca de cristales. Se romperán más rápido y darán más moneda.",
        ["tutorial.slot_power.title"] = "Mejora Resonancia",
        ["tutorial.slot_power.body"] = "¡Ganaste una mejora de Potencia! Abre PODERES, toca Resonancia y colócala en una ranura para obtener pulsos más fuertes.",
        ["tutorial.slot_power.body_gamepad"] = "¡Ganaste una mejora de Potencia! Pulsa derecha, elige Resonancia con A y coloca Potencia para mejorar sus pulsos.",
        ["tutorial.first_fight.title"] = "Tu primera batalla",
        ["tutorial.first_fight.body"] = "¡Algo se agita en la cueva de Tierra! Ve allí; tus mascotas lucharán por ti. Derrótalo y recoge sus monedas.",
        ["tutorial.battle_brew.title"] = "Bebe para luchar",
        ["tutorial.battle_brew.body"] = "HAZ CLIC en la Bebida Berserker que parpadea en tu barra. ¡Todas tus mascotas golpearán más fuerte!",
        ["tutorial.battle_brew.body_gamepad"] = "¡Encontraste dos Bebidas Berserker! Elige la bebida con LB/RB y pulsa RT para tomarla.",
        ["tutorial.rally_call.title"] = "Hazlos volver",
        ["tutorial.rally_call.body"] = "¿Ves la BANDERA arriba a la izquierda de tu barra? Es Reunir. Púlsala para que tus mascotas vuelvan al instante.",
        ["tutorial.rally_call.body_gamepad"] = "¿Ves la BANDERA arriba a la izquierda? Elígela con LB/RB y pulsa RT para llamar a todas tus mascotas.",
        ["tutorial.completion.title"] = "🎉 ¡TUTORIAL COMPLETADO — NIVEL 2!",
        ["tutorial.completion.body"] = "¡Llegaste al nivel 2! Visita el Altar de Ascensión para elegir tu próximo poder y sigue tus misiones.",
    },
    ["pt-br"] = {
        ["tutorial.progress"] = "TUTORIAL  %d / %d",
        ["tutorial.complete_label"] = "TUTORIAL CONCLUÍDO",
        ["tutorial.cue.click_here"] = "CLIQUE AQUI",
        ["tutorial.target.mine"] = "⬇ MINERE",
        ["tutorial.target.hatch"] = "⬇ ABRA",
        ["tutorial.target.go"] = "⬇ VÁ",
        ["tutorial.target.fight"] = "⬇ LUTE",
        ["tutorial.language_banner"] = "Seu idioma é %s. O tutorial usará esse idioma. Você pode mudar para inglês nas Configurações.",

        ["tutorial.hatch_first_egg.title"] = "Abra seu primeiro ovo",
        ["tutorial.hatch_first_egg.body"] = "Seu companheiro precisa de um aliado. Siga o caminho até o Ovo da Terra e abra um.",
        ["tutorial.hatch_first_egg.body_gamepad"] = "Seu companheiro precisa de um aliado. Siga o caminho até o Ovo da Terra e aperte X para abrir um.",
        ["tutorial.farm_crystals.title"] = "Minere cristais",
        ["tutorial.farm_crystals.body"] = "Seu esquadrão minera cristais próximos com Farm Near LIGADO. Clique em um cristal pequeno para TURBINÁ-LO e ganhe 100 moedas.",
        ["tutorial.farm_crystals.body_gamepad"] = "Seu esquadrão minera cristais próximos com Farm Near LIGADO. Aproxime-se de um cristal pequeno para TURBINÁ-LO e ganhe 100 moedas.",
        ["tutorial.hatch_another.title"] = "Aumente seu esquadrão",
        ["tutorial.hatch_another.body"] = "Gaste essas moedas em outro ovo. Mais pets significam mineração mais rápida.",
        ["tutorial.hatch_another.body_gamepad"] = "Gaste essas moedas em outro ovo. Aproxime-se e aperte X; mais pets mineram mais rápido.",
        ["tutorial.build_squad.title"] = "Monte seu esquadrão",
        ["tutorial.build_squad.body"] = "Aqui você escolhe os pets que lutam ao seu lado. Abra Pets e dê uma olhada; você pode manter seu esquadrão atual.",
        ["tutorial.build_squad.body_gamepad"] = "Aqui você escolhe os pets que lutam ao seu lado. Aperte esquerda no direcional para abrir Pets e escolha com A.",
        ["tutorial.build_squad.body_with_unequipped"] = "Agora você tem mais pets para escolher. Abra Pets e decida quem luta ao seu lado. Troque um ou mantenha o esquadrão atual.",
        ["tutorial.bind_power.title"] = "Equipe seu poder",
        ["tutorial.bind_power.body"] = "Você nasceu com Ressonância. Aperte Editar na barra e coloque Ressonância em um espaço. Faça isso com cada poder novo.",
        ["tutorial.bind_power.body_gamepad"] = "Você nasceu com Ressonância. Aperte direita no direcional, escolha Ressonância com A e coloque-a em um espaço.",
        ["tutorial.cast_power.title"] = "Use Ressonância",
        ["tutorial.cast_power.body"] = "Aperte esse espaço perto de cristais. Ressonância faz com que quebrem mais rápido e deem mais moedas.",
        ["tutorial.cast_power.body_gamepad"] = "Escolha Ressonância com LB/RB e aperte RT perto de cristais. Eles quebrarão mais rápido e darão mais moedas.",
        ["tutorial.slot_power.title"] = "Fortaleça Ressonância",
        ["tutorial.slot_power.body"] = "Você ganhou um aprimoramento de Potência! Abra PODERES, toque em Ressonância e coloque-o em um espaço para pulsos mais fortes.",
        ["tutorial.slot_power.body_gamepad"] = "Você ganhou um aprimoramento de Potência! Aperte direita, escolha Ressonância com A e equipe Potência.",
        ["tutorial.first_fight.title"] = "Sua primeira luta",
        ["tutorial.first_fight.body"] = "Algo se agita na caverna da Terra! Vá até lá; seus pets lutarão por você. Derrote-o e recolha as moedas.",
        ["tutorial.battle_brew.title"] = "Beba para lutar",
        ["tutorial.battle_brew.body"] = "CLIQUE na Poção Berserker piscando na sua barra. Todos os seus pets causarão mais dano!",
        ["tutorial.battle_brew.body_gamepad"] = "Você encontrou duas Poções Berserker! Escolha a poção com LB/RB e aperte RT para beber.",
        ["tutorial.rally_call.title"] = "Chame-os de volta",
        ["tutorial.rally_call.body"] = "Viu a BANDEIRA no canto superior esquerdo da barra? É Reunir. Aperte-a para chamar seus pets de volta na hora.",
        ["tutorial.rally_call.body_gamepad"] = "Viu a BANDEIRA no canto superior esquerdo? Escolha com LB/RB e aperte RT para chamar todos os pets.",
        ["tutorial.completion.title"] = "🎉 TUTORIAL CONCLUÍDO — NÍVEL 2!",
        ["tutorial.completion.body"] = "Você chegou ao nível 2! Visite o Altar da Ascensão para escolher seu próximo poder e siga suas missões.",
    },
}

local DISPLAY_NAMES = {
    en = "English",
    es = "Español",
    ["pt-br"] = "Português (Brasil)",
}

function TutorialLocalization.languageFor(localeId)
    local normalized = string.lower(tostring(localeId or "")):gsub("_", "-")
    if normalized == "es" or string.sub(normalized, 1, 3) == "es-" then
        return "es"
    end
    if normalized == "pt" or string.sub(normalized, 1, 3) == "pt-" then
        return "pt-br"
    end
    return "en"
end

function TutorialLocalization.displayName(localeId)
    return DISPLAY_NAMES[TutorialLocalization.languageFor(localeId)] or DISPLAY_NAMES.en
end

function TutorialLocalization.isTranslated(localeId)
    return TutorialLocalization.languageFor(localeId) ~= "en"
end

function TutorialLocalization.text(localeId, key, fallback)
    local language = TutorialLocalization.languageFor(localeId)
    local translated = CATALOG[language] and CATALOG[language][key]
    return translated or fallback or (CATALOG.en and CATALOG.en[key]) or key
end

function TutorialLocalization.format(localeId, key, fallback, ...)
    return string.format(TutorialLocalization.text(localeId, key, fallback), ...)
end

return TutorialLocalization
