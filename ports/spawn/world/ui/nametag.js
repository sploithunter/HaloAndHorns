// THE NAMETAG (spawn-nametag.dc.html): the tag over another player's head, written the way ui.js is: the engine calls the default export
// for every tag whose facts moved, or whose reads through ctx moved, and paints the string; "" paints no tag over that body; <style> rides
// the string; nodes match by id between paints. Spawn owns this default; a world may carry its own copy at the path world.config.yaml names
// under `nametag:` (every starter ships this file at ui/nametag.js) and edit it as plain JavaScript, HTML and CSS.
// tag = { id, name, handle, face, said, named, earshot, talking, muted, mutual, dnd, agent, doing, hot, party, guild, ring, opacity, depth, distance }
//   id (the body under the tag: ctx.getObject(tag.id) is its handle) · name · handle (the dim @handle of a friend whose shown name is not it: a character; null otherwise) · face (their profile picture's URL, or null:
//   the head's disc stands) · said ({ text, until }: the line they just said, or null) · named (a name, else a dot) ·
//   earshot (within earshot: whole; else dimmed) · talking · muted · mutual · dnd (do not disturb: a moon on the face) · agent · doing (what an agent
//   is doing now, while her turn runs: her working line when you stand near her, else a word for her step: 'thinking…', 'reading the world',
//   'writing', 'working', 'talking' or 'waiting'; null when she is not working, and on every person) · hot (the one you
//   look at) · party (your party: the ember dot) · guild (your guild: the green dot) · ring (a lane's colour, or null) · opacity · depth (0 at the
//   feet, 1 at twice earshot) · distance (metres). Earshot here is world.config.yaml's earshot above ten players; with ten or fewer the whole
//   room is in earshot, so depth stays about 0 there. Every text fact arrives ready for markup.
// named is false over every person for a viewer in streamer mode.
const STYLE = `<style>
  .tag { position: relative; display: flex; flex-direction: column; align-items: center; font-family: 'Geist Pixel', ui-monospace, Menlo, monospace; opacity: var(--opacity, 1); transform: scale(calc(1 - var(--depth, 0) * .82)); transform-origin: 50% 100%; }
  .tag.hot { transform: scale(max(calc(1 - var(--depth, 0) * .82), .72)); }
  .said { position: absolute; left: 50%; bottom: 100%; margin-bottom: 6px; transform: translateX(-50%); width: max-content; max-width: 220px; display: block; animation: nametag-say 9s linear both; }
  .said > div { color: rgba(255,255,255,.92); font-size: 12px; line-height: 1.35; max-width: 200px; text-wrap: pretty; text-align: center; background: #070708; padding: 6px 9px; }
  .row { display: flex; align-items: center; gap: 6px; padding: 4px 6px; }
  .head { position: relative; display: flex; flex: none; width: 14px; height: 14px; border-radius: 9999px; background: #2a2a30; box-shadow: none; }
  .pfp { width: 14px; height: 14px; border-radius: 9999px; flex: none; object-fit: cover; }
  .pfp:not([src]) { display: none; }
  .tag.talking .head { box-shadow: 0 0 0 2px #1d96a0; }
  .tag.mutual .head { box-shadow: 0 0 0 2px #f4ede1; }
  .tag.ringed .head { box-shadow: 0 0 0 2px var(--ring); }
  .moon { position: absolute; right: -3px; bottom: -3px; width: 8px; height: 8px; border-radius: 9999px; background: #070708; }
  .moon::after { content: ""; position: absolute; left: 1.5px; top: 1.5px; width: 5px; height: 5px; border-radius: 9999px; box-shadow: inset 2px -1px 0 0 #f4ede1; }
  .tag.agent .head { background: radial-gradient(circle at 45% 40%, #d97757 0 30%, #8a3f26 31% 55%, #2b160e 56%); }
  .crew { width: 8px; height: 8px; border-radius: 9999px; flex: none; box-shadow: 0 0 0 1px rgba(7,7,8,.6); }
  .crew.party { background: #d97757; }
  .crew.guild { background: #7fc97f; }
  .name { font-size: 12px; line-height: 1; color: #fff; white-space: nowrap; }
  .handle { font-size: 12px; line-height: 1; color: rgba(255,255,255,.4); white-space: nowrap; }
  .tag.mutual .name { color: #f4ede1; }
  .tag.muted .name { color: rgba(255,255,255,.45); text-decoration: line-through; }
  .doing { font-size: 10px; color: rgba(255,255,255,.55); white-space: nowrap; }
  .bars { display: flex; gap: 2px; align-items: center; height: 9px; flex: none; filter: drop-shadow(0 0 1px #070708); }
  .bars > i { display: block; width: 2px; height: 9px; background: #1d96a0; animation: nametag-bar .8s ease-in-out infinite; }
  .bars > i:nth-child(2) { animation-delay: .15s; } .bars > i:nth-child(3) { animation-delay: .3s; }
  .dot { width: 5px; height: 5px; border-radius: 9999px; background: rgba(255,255,255,.55); box-shadow: 0 0 0 1px rgba(7,7,8,.6); margin-bottom: 6px; }
  @keyframes nametag-bar { 0%,100% { transform: scaleY(.3); } 50% { transform: scaleY(1); } }
  @keyframes nametag-say { 0% { opacity: 0; transform: translate(-50%, 6px); } 4% { opacity: 1; transform: translate(-50%, 0); } 75% { opacity: 1; } 100% { opacity: 0; transform: translate(-50%, 0); } }
</style>`;

export default function (ctx, tag) {
  const states = [
    "named",
    "earshot",
    "talking",
    "muted",
    "mutual",
    "dnd",
    "agent",
    "hot",
    "party",
    "guild",
  ].filter((state) => tag[state]);
  const classes = ["tag", ...states, tag.ring ? "ringed" : ""]
    .filter(Boolean)
    .join(" ");
  const vars = `--opacity:${tag.opacity};--depth:${tag.depth}${tag.ring ? `;--ring:${tag.ring}` : ""}`;
  // The bubble's id carries the line's clock: a new line is a new node, so its animation starts over.
  const said = tag.said
    ? `<div class="said" id="said-${tag.said.until}"><div>${tag.said.text}</div></div>`
    : "";
  const face = tag.face
    ? `<img class="pfp" src="${tag.face}" crossorigin="anonymous" alt="" />`
    : "";
  const moon = tag.dnd ? `<i class="moon"></i>` : "";
  const crew = tag.guild
    ? `<span class="crew guild"></span>`
    : tag.party
      ? `<span class="crew party"></span>`
      : "";
  const handle = tag.handle ? `<span class="handle">${tag.handle}</span>` : "";
  const doing = tag.doing ? `<span class="doing">${tag.doing}</span>` : "";
  const bars = tag.talking
    ? `<div class="bars"><i></i><i></i><i></i></div>`
    : "";
  const row = tag.named
    ? `<div class="row"><span class="head">${face}${moon}</span>${crew}<span class="name">${tag.name}</span>${handle}${doing}${bars}</div>`
    : `<div class="dot"></div>`;
  return `${STYLE}<div class="${classes}" style="${vars}">${said}${row}</div>`;
}
