# Heaven & Hell Pet Design Prompts (layers 2–4)

Status: design — Jason, 2026-06. Meshy text-to-3D generation prompts for every roster pet in
layers 2, 3, and 4 (60 pets). Companion to [PET_REALM_HEAVEN_HELL_ROSTER.md](PET_REALM_HEAVEN_HELL_ROSTER.md)
(roles/rarity/odds) and the [Design Document](PET_REALM_DESIGN_DOCUMENT.md) (palette + dragon rules).

Pipeline: generate in Meshy → group upload → mesh combine (see the pet mesh/texture pipeline).
Remember the gotcha: the combine's `texture_asset` needs the **IMAGE** id, not the Decal id.

## How to use these

Each pet below is a **subject clause**. Build the final prompt as:

> `STYLE` + `<pet subject clause>` + (optional `GOLDEN` suffix)

### STYLE — prepend to every prompt
> Stylized cute Roblox-style collectible game pet, single creature, full body, centered, facing
> forward in a neutral idle pose, chunky rounded friendly proportions, clean smooth forms suited
> to low-poly game use, soft even shading, no base or platform, plain neutral background.

(Dragons & apexes: add "large, majestic, heroic, extra detail" — and note dragons need a higher
viewport zoom on import, per the existing dragon entries in `configs/pets.lua`.)

### Variant suffix — covers the gold version of EVERY pet
Golden is a **recolor of the same sculpt** — never change the silhouette. So a pet's golden
prompt is literally its base prompt + the GOLDEN suffix. This is why there is no separate
per-pet gold list: append it to any base below.

> **GOLDEN VARIANT** — identical sculpt and silhouette; re-skin the entire surface as lustrous
> polished gold with a bright metallic sheen and warm highlights; eyes become faceted gemstones;
> subtle golden sparkle. Recolor only, form unchanged.

> **Rainbow is NOT generated** — it's a runtime **effect** (shader / VFX overlay) on the base
> model, so it needs no prompt and no separate mesh. Only base + golden get generation prompts.

> Note: gold and rainbow are still the cross-cutting shiny tiers, so the **base** palettes below
> deliberately avoid gold/rainbow as a dominant color — that keeps a shiny reading as a shiny.

---

## Layer 2

### Heaven 2 — The Aurora Reaches  ·  palette: white / silver / pearl / prismatic / aurora; translucent, haloed, luminous

**Fire**
- **Coronal Cherub** — chubby winged cherub-imp wreathed in cool white flame, tiny halo, soft cyan glow.
- **Prism Lion** — stocky lion cub with a mane of refracting prismatic crystal shards, pearl-white fur.
- **Lance Seraph** — sleek four-winged seraph bird clutching a spear of white sunfire, silver plumage.
- **Lumen Salamander** — plump salamander of translucent glowing white light, soft aurora sheen along its back.
- **Dawnfire Phoenix** *(mythic apex)* — majestic phoenix of radiant white and pale-cyan feathers trailing soft light, luminous corona.

**Ice** *(dragon origin)*
- **Frostlight Doe** — dainty fawn of pale crystalline frost, faintly glowing antler-buds, prismatic hooves.
- **Prism Fox** — small fox with translucent prismatic-ice fur that refracts rainbow light, aurora-tipped tail.
- **Starlight Owl** — round owl of deep night-blue plumage speckled with starlight, glowing aurora eyes.
- **Glacial Bear** — chunky prismatic-furred polar bear, aurora sheen, sturdy tank build.
- **★ Aurora Dragon** *(secret)* — majestic prism-scaled dragon, translucent aurora-glowing scales, crystalline horns, frost breath; sturdy ground/melee build, not a slender flyer.

**Grass**
- **Bloomspirit Lamb** — fluffy lamb of soft white light with glowing flower-bud wool, tiny leaf halo.
- **Lightleaf Hare** — swift hare with translucent petal-like ears and faint light-wings, pearl fur.
- **Crystalbark Stag** — noble stag with glowing crystal-and-bark antlers, white pelt.
- **Radiant Sprite** — tiny floating bloom-spirit of glowing pollen motes with petal wings, pearl-green light.
- **Worldbloom Ent** *(mythic apex)* — towering gentle tree-guardian of living white light, blossoming canopy, glowing roots.

**Desert**
- **Aurora Dove** — plump radiant white dove, softly glowing breast, drifting light motes.
- **Prism Scarab** — rounded beetle with a prismatic crystal shell that casts a protective light-barrier.
- **Mirage Meerkat** — alert pale meerkat on watch, faint heat-shimmer, light-wisp tail.
- **Sunwell Camel** — friendly camel with a glowing oasis-blue water-light hump, pale radiant coat.
- **Empyreal Couatl** *(mythic apex)* — majestic plumed light-serpent, radiant white-and-prismatic feathered coils, halo.

### Hell 2 — The Frozen Dark  ·  palette: black / obsidian / black-ice / sickly-violet; frostbitten, hollow, cracked

**Fire**
- **Frostcinder Imp** — gaunt charred imp of black ice and cold blue-violet flame, hollow glowing eyes.
- **Rimemane Lion** — black frost-charred lion with a mane of jagged black ice, frostbitten hide.
- **Hoarfrost Phoenix** — dark skeletal phoenix wreathed in pale cold-blue fire, frost-rimed black feathers.
- **Frostbrand Salamander** — black salamander with glowing violet frostbite brands, icy cracked skin.
- **Deadfire Phoenix** *(mythic apex)* — ashen-black phoenix with a dying ember-violet glow, frost-tipped charred plumage.

**Ice** *(dragon origin)*
- **Rimegloom Hare** — gaunt frostbitten hare with black-ice fur, hollow pale eyes.
- **Dread Fox** — spectral black fox wreathed in chilling violet mist, eerie glowing stare.
- **Gravefrost Owl** — tattered black owl of frozen shadow, jagged ice feathers, violet eyes.
- **Rimeguard Bear** — hulking black-ice polar bear, frostbitten coat, hollow violet eyes, sturdy tank build.
- **★ Rimewraith Dragon** *(secret)* — menacing black-ice revenant dragon, jagged frostbitten obsidian scales, violet inner glow, hollow eyes; sturdy ground/melee build.

**Grass**
- **Frostblight Lamb** — frozen rotted lamb, matted black-ice wool, sickly violet glow, hollow eyes.
- **Gloom Hare** — gaunt fanged frostbitten hare, dark patchy fur, pale dead eyes.
- **Icerot Stag** — decaying stag with black frozen thorns and ice-cracked antlers, rot-violet veins.
- **Rimewither Sprite** — withered dark frost-spirit shedding black pollen, violet glow.
- **Frostgrave Ent** *(mythic apex)* — massive frozen dead-tree guardian, black-ice bark, hollow knot-eyes, violet heart-glow.

**Desert**
- **Wraith Dove** — tattered black dove with a sickly violet glow, drains the fallen to heal the squad.
- **Rime Scarab** — black-ice beetle whose carapace projects armor-stripping frost.
- **Gloom Jackal** — gaunt black-ice scavenger jackal, hollow violet eyes.
- **Frostdust Camel** — gaunt frost-wraith camel, black-ice hump, breath of freezing dust.
- **Dread Couatl** *(mythic apex)* — menacing black-frost plumed serpent, violet-glowing coils, curse-breath.

---

## Layer 3

### Heaven 3 — The Empyrean Bloom  ·  palette: white / pearl / living emerald-light; radiant flora, petals, glow

**Fire**
- **Gloryspark Cherub** — radiant cherub-mote of white flame with tiny emerald-light wings, soft halo.
- **Seraph Lion** — regal lion with a glowing white halo-mane edged in emerald light, pearl coat.
- **Radiant Lance** — graceful light-bird wielding a white sunfire lance, emerald-tipped wings.
- **Gloryscale Salamander** — salamander of glowing white light with emerald scale-sheen and a radiant aura.
- **Empyrean Firehawk** *(mythic apex)* — great radiant fire-hawk of white-and-emerald flame, sweeping dive-attacks.

**Ice**
- **Lumen Seal** — glowing white-light seal pup, soft emerald sheen.
- **Halo Wisp** — drifting will-o-light orb-sprite ringed with emerald glow, slows what it touches.
- **Celestial Moth** — pearl moth with starlit emerald-glow wing-scales.
- **Halo Bear** — haloed polar bear of white-and-emerald light, sturdy tank build.
- **Empyrean Mammoth** *(mythic apex)* — vast radiant mammoth with glowing emerald tusks, light-wreathed.

**Grass** *(dragon origin)*
- **Gloryleaf Lamb** — lamb of green-white light with glowing leaf-wool, tiny bloom halo.
- **Halo Hart** — radiant young stag with a halo and glowing emerald antlers, pearl pelt.
- **Lightbark Rhino** — sturdy light-plated rhino with glowing root-bark armor, emerald glow.
- **Bloomlight Sprite** — floating harvest-spirit of glowing pollen and petals, emerald-white light.
- **★ Verdant Dragon** *(secret)* — colossal benevolent tree-dragon of living light, bark-and-leaf scales, a blossoming canopy crest, glowing emerald veins; massive heavy tank build.

**Desert**
- **Bloom Ibis** — radiant white ibis with emerald-light plumes, gentle heal-glow.
- **Radiant Totem** — floating carved light-totem, emerald glyphs, casts a team barrier.
- **Glory Mongoose** — alert pale desert mongoose with emerald-glow stripes, rallies the squad.
- **Light Tortoise** — domed glowing tortoise, emerald sun-spring shell, slow heal aura.
- **Empyrean Sphinx** *(mythic apex)* — serene oracle-sphinx of white alabaster with emerald-light eyes, blessing aura.

### Hell 3 — The Blightmire  ·  palette: rot-green / black / bruise-violet; decay, bile, bone, drips

**Fire**
- **Blightcinder Imp** — sickly imp of green-rot fire, oozing cinders, hollow eyes.
- **Plaguemane Lion** — boil-maned lion with rotting green-black hide and a pustule glow.
- **Pyreblight Phoenix** — diseased phoenix wreathed in green pyre-flame, rotting feathers.
- **Rotbrand Salamander** — black salamander oozing green rot, glowing plague brands.
- **Pestilence Harpy** *(mythic apex)* — gaunt rot-winged harpy, bile-dripping feathers, plague-screech.

**Ice**
- **Murkfrost Seal** — bog-frost seal, matted green-black hide, sick eyes.
- **Plague Wisp** — drifting miasma-orb sprite trailing green rot, slows and fears.
- **Carrion Moth** — ragged rot-moth with bone-pale wings, green-glow eyes.
- **Murk Bear** — bog-frost polar bear, matted rotted coat, green-glow eyes, sturdy tank build.
- **Blight Mammoth** *(mythic apex)* — drowned bog-mammoth of rot and slime, green-glow eyes, decaying tusks.

**Grass** *(dragon origin)*
- **Blightleaf Lamb** — rotted lamb with green-black decayed wool, life-leech glow, hollow eyes.
- **Murk Hart** — gaunt bog-stag dripping moss, dead pale eyes.
- **Rothide Rhino** — rotting armored rhino with thorned green-black hide, oozing veins.
- **Plaguebloom Sprite** — withered spirit shedding diseased green spores, bruise-violet glow.
- **★ Blight Dragon** *(secret)* — colossal rotting bog-dragon, decayed bark-and-bone scales, dripping bile, green-glow veins; massive heavy tank build, faint swarm of flies.

**Desert**
- **Carrion Ibis** — gaunt rot-ibis with bone-pale plumes, drains the fallen to heal.
- **Plague Totem** — rotting carved totem dripping bile, weakens nearby foes.
- **Murk Mongoose** — mottled green-black desert mongoose, saps enemy damage.
- **Plaguedust Camel** — gaunt camel exhaling sickly green dust, rotting hump.
- **Pestilent Sphinx** *(mythic apex)* — cursed oracle-sphinx of cracked bone, green-glow eyes, blight aura.

---

## Layer 4

### Heaven 4 — The Sunspire Reaches  ·  palette: white / alabaster / sun-white / quartz; near-blinding, faceted glass (NO gold)

**Fire**
- **Sunspark Cherub** — radiant cherub-mote of brilliant white sun-fire, faceted light halo.
- **Blaze Lion** — powerful lion blazing with white-sun light, alabaster mane, glowing eyes.
- **Sunlance Seraph** — sleek light-bird hurling brilliant white sun-lances, quartz-tipped wings.
- **Sunscale Salamander** — salamander with faceted quartz scales glowing sun-white, radiant aura.
- **Solaris Ifrit** *(mythic apex)* — towering radiant sun-fire genie wreathed in white flame, hurls sun-bolts.

**Ice**
- **Sunfrost Marten** — sleek sun-glazed frost marten, quartz sheen.
- **Glare Jelly** — drifting translucent quartz-light jelly, blinding glare that slows.
- **Sunbeam Petrel** — pale sun-white sea-petrel, beam-glow eyes, faceted feathers.
- **Quartz Bear** — polar bear of faceted clear quartz and sun-white fur, sturdy tank build.
- **Sunspire Yeti** *(mythic apex)* — towering glass-furred yeti, sun-white sheen, quartz claws.

**Grass**
- **Sunbloom Lamb** — lamb with glowing white sun-flower wool, faceted-light halo.
- **Sunleaf Hare** — bright hare with translucent quartz-leaf ears, sun-white coat.
- **Quartzshell Beetle** — hulking crystal-shelled rhino-beetle, faceted quartz plates, sun-white glow.
- **Sunmote Sprite** — floating spirit of glowing sun-pollen with faceted light wings.
- **Sunroot Ent** *(mythic apex)* — towering sun-tree guardian of white light and quartz bark, radiant canopy.

**Desert** *(dragon origin)*
- **Sun Lark** — bright white desert lark, radiant sun-glow breast, gentle heal pulse.
- **Quartz Idol** — floating carved quartz idol, sun-white glyphs, casts a team barrier.
- **Sunmote Vulture** — pale circling vulture wreathed in sun-motes, rallies squad damage.
- **Sunspring Camel** — camel with a glowing oasis-light hump, radiant pale coat, heal aura.
- **★ Alabaster Dragon** *(secret)* — colossal radiant desert dragon of smooth white alabaster and sun-fused glass, crowned by a halo'd sun-disk; oasis-breath that **heals and shields the team** (support dragon, NO gold).

### Hell 4 — The Scorchglass  ·  palette: black-glass / obsidian / ember-on-black; fractured glass, molten cracks, ash

**Fire**
- **Scorchcinder Imp** — obsidian imp veined with glowing ember cracks, smoldering shards.
- **Cindermane Lion** — black lion with molten-cracked obsidian hide and an ember-glow mane.
- **Magmaglass Phoenix** — dark phoenix of molten black glass with glowing ember-cracked feathers.
- **Scorchbrand Salamander** — obsidian salamander with glowing ember brands, cracked molten skin.
- **Inferno Ifrit** *(mythic apex)* — towering dark fire-genie of black flame and ember cracks, hurls black-fire bolts.

**Ice**
- **Blackfrost Marten** — obsidian-frost marten, ember-flecked black coat, cold glow.
- **Shatter Jelly** — drifting fractured black-glass jelly, ember-glow, shatter-slow.
- **Obsidian Petrel** — sea-petrel of sharp black-glass feathers, ember-glow eyes.
- **Obsidian Bear** — polar bear of black volcanic glass and frost, ember-cracked, sturdy tank build.
- **Scorchglass Yeti** *(mythic apex)* — towering molten-glass yeti, ember-veined obsidian fur.

**Grass**
- **Scorchleaf Lamb** — charred lamb with burnt-glass wool, ember-glow, leech aura.
- **Cinder Hare** — ember-singed hare, blackened fur, glowing cracks.
- **Glassback Beetle** — hulking obsidian-shelled rhino-beetle, ember-veined black plates.
- **Scorchbloom Sprite** — withered spirit shedding ember-sparks, black-glass petals.
- **Scorchroot Ent** *(mythic apex)* — burnt-glass tree-guardian, obsidian bark with molten-ember cracks, glowing core.

**Desert** *(dragon origin)*
- **Scorch Vulture** — circling black-glass vulture, ember-glow, drains the fallen to heal.
- **Obsidian Idol** — dark carved obsidian idol, ember glyphs, weakens nearby foes.
- **Cinder Jackal** — ember-singed black jackal, saps enemy damage for the team.
- **Scorchdust Camel** — gaunt camel exhaling scorching ash, ember-cracked hump.
- **★ Glass Dragon** *(secret)* — colossal fractured black-glass desert dragon, razor obsidian scales veined with ember cracks; Alabaster's dark mirror — **curses and shreds every foe** and drains for the team (support dragon).

---

## Layer 5

### Heaven 5 — The Radiance  ·  palette: pure white / blinding light / prismatic halo; near-formless radiance (NO gold)

**Fire**
- **Seraph Cherub** — cherub-mote of pure blinding white light, faint halo, near-formless radiance.
- **Sol Lion** — powerful lion of brilliant white light, radiant mane, glowing form.
- **Empyrean Lance** — light-bird wielding a lance of pure white radiance, halo-glow wings.
- **Glory Salamander** — salamander of glowing white light with a radiant aura and prismatic halo sheen.
- **Sol Phoenix** *(mythic apex)* — supreme phoenix of pure white sun-radiance, blinding corona, near-formless light feathers.

**Ice**
- **Astral Ermine** — pure-white starlight ermine, luminous near-translucent coat.
- **Sol Wisp** — drifting orb of radiant white light haloed in glow, slows what it touches.
- **Astral Petrel** — pure-starlight sea-petrel, constellation-speckled wings, radiant eyes.
- **Astral Bear** — radiant polar bear of pure white light, halo, sturdy tank build.
- **Astral Leviathan** *(mythic apex)* — vast serpent of pure white starlight with halo-glow fins, luminous.

**Grass**
- **Eden Lamb** — lamb of pure white light with a radiant bloom halo, glowing wool (self-heal).
- **Sol Hart** — radiant stag of white light, halo, glowing antlers.
- **Edenshell Tortoise** — domed guardian-tortoise of pure white light, radiant shell, sturdy tank.
- **Eden Badger** — stocky white-light badger with radiant stripes, bruiser build.
- **Eden Colossus** *(mythic apex)* — towering stone-and-light colossus of pure radiance, glowing core.

**Desert**
- **Sol Dove** — radiant white dove of pure light, halo, gentle heal pulse.
- **Astral Idol** — floating carved light-idol, halo glyphs, casts a team barrier.
- **Sol Mongoose** — alert pure-light desert mongoose, radiant stripes, rallies the squad.
- **Sol Camel** — camel with a radiant white-light hump, glowing oasis heal aura.
- **Astral Lammasu** *(mythic apex)* — majestic winged guardian-lammasu (bull body, bearded, feathered wings) of pure white light, blessing aura.

**Apex dragon (shared secret)**
- **★ Seraph Dragon** *(secret · hybrid)* — grand six-winged seraphic dragon of near-pure blinding white light, halo crown, radiant near-formless body; large, heroic, majestic apex build.

### Hell 5 — The Void  ·  palette: pure black / void / violet-red edge; light-devouring silhouettes

**Fire**
- **Umbral Imp** — imp of pure void-black, faint violet-red edge glow, light-devouring silhouette.
- **Void Lion** — black lion of pure void with a violet-red rim light, hollow form.
- **Abyss Phoenix** — phoenix of void-black with a violet-red ember edge, light-swallowing wings.
- **Null Salamander** — void-black salamander with violet-red brand glow, event-horizon skin.
- **Oblivion Phoenix** *(mythic apex)* — supreme void-black phoenix with a violet-red corona edge, devours surrounding light.

**Ice**
- **Umbral Ermine** — void-black ermine, violet-red rim, hollow eyes.
- **Void Wisp** — drifting void-orb sprite edged in violet-red, slows and fears.
- **Abyss Petrel** — void-black sea-petrel, violet-red eye-glow, light-devouring wings.
- **Void Bear** — void-black polar bear edged in violet-red, light-swallowing, sturdy tank build.
- **Abyss Leviathan** *(mythic apex)* — vast serpent of pure void, violet-red rim, light-devouring scales.

**Grass**
- **Umbral Lamb** — void-black lamb, violet-red glow, hollow eyes (life-leech).
- **Void Hart** — gaunt void-black stag, violet-red rim.
- **Nullshell Tortoise** — void-black guardian-tortoise, violet-red shell cracks, sturdy tank.
- **Void Badger** — stocky void-black badger, violet-red stripes, bruiser build.
- **Oblivion Colossus** *(mythic apex)* — towering void-black stone colossus, violet-red core, light-devouring.

**Desert**
- **Void Dove** — tattered void-black dove, violet-red glow, drains the fallen to heal.
- **Null Idol** — void-black carved idol, violet-red glyphs, curses nearby foes.
- **Umbral Jackal** — void-black jackal, violet-red rim, saps enemy damage.
- **Null Camel** — gaunt void camel, violet-red breath, regen-denial aura.
- **Void Anubis** *(mythic apex)* — towering void-black jackal-headed guardian (Anubis-like), violet-red regalia, curse-blessing aura.

**Apex dragon (shared secret)**
- **★ Void Dragon** *(secret · hybrid)* — colossal dragon of pure void-black, an event-horizon silhouette edged in violet-red that devours surrounding light; large, heroic, menacing apex build.

---

## Egg prompts (layers 2–5)

Each realm has **4 per-origin eggs** (fire / ice / grass / desert). Layer 1's eggs already exist
(`solar_egg`, `aurora_egg`, `bloom_egg`, `gilded_egg` + the hell set). Eggs use the same mesh
combine path as pets (mesh + IMAGE texture). Build each as `EGG STYLE` + the descriptor.

### EGG STYLE — prepend to every egg prompt
> Stylized collectible game egg, a single smooth rounded ovoid standing upright, centered, clean
> low-poly-friendly form, soft even shading, decorative themed shell, no base or platform, plain
> neutral background.

The shell = **realm palette + origin motif** (fire = flame swirls · ice = frost crystals ·
grass = leaves/blossom · desert = glass/sand facets).

**Heaven 2 — Aurora Reaches** (white / pearl / prismatic / aurora)
- Fire — pearl-white egg with cool white-flame swirls, faint prismatic sheen, soft cyan glow.
- Ice — translucent frost-crystal egg with an aurora shimmer and prismatic refraction.
- Grass — pearl egg wrapped in glowing white-light vines and tiny blossoms.
- Desert — sun-fused translucent glass egg with a faint prismatic glint, smooth.

**Hell 2 — Frozen Dark** (black / obsidian / black-ice / violet)
- Fire — black egg veined with cold blue-violet flame cracks, frost-rimed.
- Ice — jagged black-ice egg with a violet inner glow, frostbitten surface.
- Grass — black rotted egg bound in frozen black vines, violet glow.
- Desert — black obsidian-glass egg, sharp facets, violet glint.

**Heaven 3 — Empyrean Bloom** (white / pearl / emerald-light)
- Fire — pearl egg with white-and-emerald flame swirls, soft halo.
- Ice — white egg studded with emerald-glow frost crystals, luminous.
- Grass — radiant egg sprouting glowing emerald-light leaves and blossoms.
- Desert — glowing radiant-glass egg with an emerald glint.

**Hell 3 — Blightmire** (rot-green / black / bruise-violet)
- Fire — black egg oozing green rot-fire cracks, sickly glow.
- Ice — bog-frosted black egg trailing green miasma, sick glow.
- Grass — rotting bark egg dripping bile, green-black, fungal.
- Desert — rot-streaked dark-glass egg with a green glint and bone fragments.

**Heaven 4 — Sunspire Reaches** (white / alabaster / sun-white / quartz)
- Fire — brilliant white egg with sun-white flame facets, near-blinding.
- Ice — sun-glazed frost-quartz egg, faceted, white glow.
- Grass — white egg with quartz-leaf accents, sun glow.
- Desert — smooth alabaster/sunstone egg, faceted, brilliant white.

**Hell 4 — Scorchglass** (black-glass / obsidian / ember)
- Fire — obsidian egg veined with glowing ember cracks, molten.
- Ice — black-glass egg flecked with embers, cold-and-hot contrast.
- Grass — burnt-glass egg of obsidian bark, ember-veined.
- Desert — polished black-glass egg, sharp facets, ember glint.

**Heaven 5 — The Radiance** (pure white / blinding light / halo)
- Fire — egg of pure white light, a faint flame-corona within, prismatic halo.
- Ice — egg of pure white light, a faint frost-crystal within, prismatic halo.
- Grass — egg of pure white light, a faint blossom within, prismatic halo.
- Desert — egg of pure white light, faint glass facets within, prismatic halo.

**Hell 5 — The Void** (pure black / void / violet-red edge)
- Fire — egg of pure void-black, a violet-red ember rim, light-devouring.
- Ice — egg of pure void-black, a violet-red frost rim.
- Grass — egg of pure void-black, a violet-red rot rim.
- Desert — egg of pure void-black, a violet-red glass-shard rim.

(Golden egg variants, if wanted, use the same GOLDEN suffix as pets. Rainbow eggs = runtime effect.)

## Not covered here (yet)

- **Layer 1** (Heaven 1 / Hell 1): pet + egg art largely exists / in progress in `configs/pets.lua`.
