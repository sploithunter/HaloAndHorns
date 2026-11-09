  const probe={place:player.place,profile:player.state.hhAccountProbe,view:{fps:ctx.view.fps,drawCalls:ctx.view.drawCalls,triangles:ctx.view.triangles,gpuMemoryMB:ctx.view.gpuMemoryMB,size:ctx.view.size},places:[...ctx.world.places].map(p=>p.id)};
  html+=`<div id="probe-data" style="visibility:hidden" data-probe="${escape(JSON.stringify(probe))}"></div>`;
