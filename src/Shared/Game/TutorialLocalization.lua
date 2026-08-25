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
        ["tutorial.first_fight.handoff.title"] = "TO CONTINUE THE TUTORIAL",
        ["tutorial.first_fight.handoff.body"] = "It's in Quest.\n\nOpen Quest anytime to start Combat Training — the Earth cave — and learn how to fight.",
        ["tutorial.first_fight.handoff.later"] = "Later",
        ["tutorial.first_fight.handoff.ok"] = "Okay",
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
        ["tutorial.build_squad.body"] = "La fila de arriba es tu escuadrón equipado: esas mascotas luchan y minan contigo. El resto espera en Inventario. Abre Mascotas y cambiaremos una.",
        ["tutorial.build_squad.body_gamepad"] = "La fila de arriba es tu escuadrón equipado. Pulsa izquierda en la cruceta para abrir Mascotas y cambiaremos una.",
        ["tutorial.build_squad.body_with_unequipped"] = "Tienes un Kitty Arcoíris en Inventario, tu mascota más fuerte. Abre Mascotas: quita una de la fila equipada, pon al Kitty y pulsa Activar.",
        ["tutorial.build_squad.guide.open.title"] = "Forma tu escuadrón",
        ["tutorial.build_squad.guide.open.body"] = "La fila de arriba es tu escuadrón equipado: esas mascotas luchan y minan contigo. El resto espera en Inventario. Abre Mascotas y cambiaremos una.",
        ["tutorial.build_squad.guide.open.body_gamepad"] = "La fila de arriba es tu escuadrón equipado. Pulsa izquierda en la cruceta para abrir Mascotas y cambiaremos una.",
        ["tutorial.build_squad.guide.unequip.title"] = "Quita una",
        ["tutorial.build_squad.guide.unequip.body"] = "Pulsa la X de una mascota equipada para quitarla. Así liberas un hueco.",
        ["tutorial.build_squad.guide.unequip.body_gamepad"] = "Elige una mascota equipada y pulsa A para quitarla. Así liberas un hueco.",
        ["tutorial.build_squad.guide.pick.title"] = "Elige la más fuerte",
        ["tutorial.build_squad.guide.pick.body"] = "Pulsa la mascota más fuerte en Inventario: tu Kitty Arcoíris. Puedes elegir cualquiera, incluso la que acabas de quitar.",
        ["tutorial.build_squad.guide.pick.body_gamepad"] = "Elige la mascota más fuerte en Inventario — tu Kitty Arcoíris — y pulsa A. Puedes elegir cualquiera, incluso la que acabas de quitar.",
        ["tutorial.build_squad.guide.activate.title"] = "Activar",
        ["tutorial.build_squad.guide.activate.body"] = "Pulsa Activar para enviar el nuevo escuadrón. La fila de arriba lucha; Inventario es el resto.",
        ["tutorial.build_squad.guide.activate.body_gamepad"] = "Pulsa Activar (A) para enviar el nuevo escuadrón. La fila de arriba lucha; Inventario es el resto.",
        ["tutorial.bind_power.title"] = "Asigna tu poder",
        ["tutorial.bind_power.body"] = "Naciste con Resonancia. Pulsa Editar en la barra y coloca Resonancia en una ranura. Harás esto con cada poder nuevo.",
        ["tutorial.bind_power.body_gamepad"] = "Naciste con Resonancia. Pulsa derecha en la cruceta, elige Resonancia con A y asígnala a una ranura.",
        ["tutorial.cast_power.title"] = "Usa Resonancia",
        ["tutorial.cast_power.body"] = "Pulsa esa ranura cerca de cristales. Resonancia hace que se rompan más rápido y den más moneda.",
        ["tutorial.cast_power.body_gamepad"] = "Elige Resonancia con LB/RB y pulsa RT cerca de cristales. Se romperán más rápido y darán más moneda.",
        ["tutorial.slot_power.title"] = "Mejora Resonancia",
        ["tutorial.slot_power.body"] = "¡Ganaste una mejora de Potencia! Abre PODERES, toca Resonancia y colócala en una ranura para obtener pulsos más fuertes.",
        ["tutorial.slot_power.body_gamepad"] = "¡Ganaste una mejora de Potencia! Pulsa derecha, elige Resonancia con A y coloca Potencia para mejorar sus pulsos.",
        ["tutorial.first_fight.title"] = "Entrenamiento de combate",
        ["tutorial.first_fight.body"] = "La cueva de Tierra es un campo de entrenamiento. Pulsa E para entrar y aprender a luchar.",
        ["tutorial.first_fight.handoff.title"] = "PARA CONTINUAR EL TUTORIAL",
        ["tutorial.first_fight.handoff.body"] = "Está en Quest.\n\nAbre Quest cuando quieras para empezar el entrenamiento de combate — la cueva de Tierra — y aprender a luchar.",
        ["tutorial.first_fight.handoff.later"] = "Luego",
        ["tutorial.first_fight.handoff.ok"] = "Okay",
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
        ["tutorial.build_squad.body"] = "A fileira de cima é o esquadrão equipado: esses pets lutam e minam com você. O resto espera no Inventário. Abra Pets e vamos trocar um.",
        ["tutorial.build_squad.body_gamepad"] = "A fileira de cima é o esquadrão equipado. Aperte esquerda no direcional para abrir Pets — vamos trocar um.",
        ["tutorial.build_squad.body_with_unequipped"] = "Você tem um Kitty Arco-íris no Inventário, seu pet mais forte. Abra Pets: tire um da fileira equipada, coloque o Kitty e aperte Ativar.",
        ["tutorial.build_squad.guide.open.title"] = "Monte seu esquadrão",
        ["tutorial.build_squad.guide.open.body"] = "A fileira de cima é o esquadrão equipado: esses pets lutam e minam com você. O resto espera no Inventário. Abra Pets e vamos trocar um.",
        ["tutorial.build_squad.guide.open.body_gamepad"] = "A fileira de cima é o esquadrão equipado. Aperte esquerda no direcional para abrir Pets — vamos trocar um.",
        ["tutorial.build_squad.guide.unequip.title"] = "Tire um",
        ["tutorial.build_squad.guide.unequip.body"] = "Toque no X de um pet equipado para tirá-lo. Isso libera um espaço.",
        ["tutorial.build_squad.guide.unequip.body_gamepad"] = "Escolha um pet equipado e aperte A para tirá-lo. Isso libera um espaço.",
        ["tutorial.build_squad.guide.pick.title"] = "Escolha o mais forte",
        ["tutorial.build_squad.guide.pick.body"] = "Toque no pet mais forte no Inventário — seu Kitty Arco-íris. Você pode escolher qualquer um, até o que acabou de tirar.",
        ["tutorial.build_squad.guide.pick.body_gamepad"] = "Escolha o pet mais forte no Inventário — seu Kitty Arco-íris — e aperte A. Você pode escolher qualquer um, até o que acabou de tirar.",
        ["tutorial.build_squad.guide.activate.title"] = "Ativar",
        ["tutorial.build_squad.guide.activate.body"] = "Aperte Ativar para enviar o novo esquadrão. A fileira de cima luta; o Inventário é o resto.",
        ["tutorial.build_squad.guide.activate.body_gamepad"] = "Aperte Ativar (A) para enviar o novo esquadrão. A fileira de cima luta; o Inventário é o resto.",
        ["tutorial.bind_power.title"] = "Equipe seu poder",
        ["tutorial.bind_power.body"] = "Você nasceu com Ressonância. Aperte Editar na barra e coloque Ressonância em um espaço. Faça isso com cada poder novo.",
        ["tutorial.bind_power.body_gamepad"] = "Você nasceu com Ressonância. Aperte direita no direcional, escolha Ressonância com A e coloque-a em um espaço.",
        ["tutorial.cast_power.title"] = "Use Ressonância",
        ["tutorial.cast_power.body"] = "Aperte esse espaço perto de cristais. Ressonância faz com que quebrem mais rápido e deem mais moedas.",
        ["tutorial.cast_power.body_gamepad"] = "Escolha Ressonância com LB/RB e aperte RT perto de cristais. Eles quebrarão mais rápido e darão mais moedas.",
        ["tutorial.slot_power.title"] = "Fortaleça Ressonância",
        ["tutorial.slot_power.body"] = "Você ganhou um aprimoramento de Potência! Abra PODERES, toque em Ressonância e coloque-o em um espaço para pulsos mais fortes.",
        ["tutorial.slot_power.body_gamepad"] = "Você ganhou um aprimoramento de Potência! Aperte direita, escolha Ressonância com A e equipe Potência.",
        ["tutorial.first_fight.title"] = "Treino de combate",
        ["tutorial.first_fight.body"] = "A caverna da Terra é um campo de treino. Aperte E para entrar e aprender a lutar.",
        ["tutorial.first_fight.handoff.title"] = "PARA CONTINUAR O TUTORIAL",
        ["tutorial.first_fight.handoff.body"] = "Está em Quest.\n\nAbra Quest quando quiser para começar o treino de combate — a caverna da Terra — e aprender a lutar.",
        ["tutorial.first_fight.handoff.later"] = "Depois",
        ["tutorial.first_fight.handoff.ok"] = "Okay",
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
