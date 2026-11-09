"""Read asset content through Studio's supported APIs; never read cookies or rewrite the place.
Requires Pillow and zstandard. Only transient EditableMesh/Image objects are created and destroyed.
"""
import subprocess,json,select,time,pathlib,sys,base64,zstandard
from PIL import Image
import argparse
parser=argparse.ArgumentParser(description="Read-only EditableMesh/EditableImage export from an open HH Studio session")
parser.add_argument("studio_id")
parser.add_argument("output",type=pathlib.Path)
args=parser.parse_args()
ROOT=pathlib.Path(__file__).resolve().parents[3]
out=args.output;out.mkdir(parents=True,exist_ok=True)
parts=json.loads((ROOT/'configs/spawn_merge_source_bay.json').read_text())['parts']
p=subprocess.Popen(['/Applications/RobloxStudio.app/Contents/MacOS/StudioMCP'],stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.DEVNULL,text=True,bufsize=1)
serial=0
def rpc(method,params):
 global serial
 serial+=1;n=serial;p.stdin.write(json.dumps({'jsonrpc':'2.0','id':n,'method':method,'params':params})+'\n');p.stdin.flush();end=time.time()+55
 while time.time()<end:
  if select.select([p.stdout],[],[],1)[0]:
   line=p.stdout.readline()
   try:r=json.loads(line)
   except:continue
   if r.get('id')==n:return r
 raise RuntimeError('Studio timed out')
rpc('initialize',{'protocolVersion':'2024-11-05','capabilities':{},'clientInfo':{'name':'hh-readonly-assets','version':'1'}})
p.stdin.write(json.dumps({'jsonrpc':'2.0','method':'notifications/initialized'})+'\n');p.stdin.flush()
def run(code):
 r=rpc('tools/call',{'name':'execute_luau','arguments':{'studio_id':args.studio_id,'datamodel_type':'Edit','code':code}})
 if r.get('result',{}).get('isError') or 'error' in r:raise RuntimeError(str(r)[:1500])
 return r['result']['content'][0]['text']
def download(code):
 meta=json.loads(run(code));n=meta['length'];chunks=[]
 for i in range(1,n+1,65000):chunks.append(run(f'return string.sub(_G.HHSpawnExportPayload,{i},{i+64999})'))
 raw=zstandard.ZstdDecompressor().decompress(base64.b64decode(''.join(chunks)))
 return meta,raw
common='local A=game:GetService("AssetService"); local E=game:GetService("EncodingService");local H=game:GetService("HttpService");'
compress='local c=E:CompressBuffer(b,Enum.CompressionAlgorithm.Zstd,3);_G.HHSpawnExportPayload=buffer.tostring(E:Base64Encode(c));'
manifest={}
try:
 for mid in sorted(set(x.get('mesh') for x in parts if x.get('mesh'))):
  identity=mid.split('//')[-1];path=out/(identity+'.bin')
  if not path.exists():
   code=common+f'local m=A:CreateEditableMeshAsync(Content.fromUri({json.dumps(mid)}));'+'''
local faces=m:GetFaces();local b=buffer.create(#faces*3*32);local cursor=0
for k,f in ipairs(faces) do
 local vs=m:GetFaceVertices(f);local us=m:GetFaceUVs(f);local ns=m:GetFaceNormals(f)
 for j=1,3 do
  local v=m:GetPosition(vs[j]);local uv=m:GetUV(us[j]);local n=m:GetNormal(ns[j])
  for _,x in ipairs({v.X,v.Y,v.Z,n.X,n.Y,n.Z,uv.X,uv.Y}) do buffer.writef32(b,cursor,x);cursor+=4 end
 end
 if k%250==0 then task.wait() end
end
local size=m:GetSize();local center=m:GetCenter();m:Destroy()
'''+compress+'return H:JSONEncode({length=#_G.HHSpawnExportPayload,faces=#faces,size={size.X,size.Y,size.Z},center={center.X,center.Y,center.Z}})'
   meta,raw=download(code);path.write_bytes(raw);(out/(identity+'.json')).write_text(json.dumps(meta))
  manifest[mid]=json.load(open(out/(identity+'.json')))
  print('mesh',identity,manifest[mid]['faces'],flush=True)
 textures=sorted(set(t for x in parts for t in [x.get('texture'),*(x.get('surface') or {}).values()] if t))
 for tid in textures:
  identity=tid.split('//')[-1];path=out/(identity+'.png')
  if not path.exists():
   code=common+f'local image=A:CreateEditableImageAsync(Content.fromUri({json.dumps(tid)}));'+'''local size=image.Size;local b=image:ReadPixelsBuffer(Vector2.zero,size);image:Destroy();'''+compress+'return H:JSONEncode({length=#_G.HHSpawnExportPayload,width=size.X,height=size.Y})'
   try:
    meta,raw=download(code);Image.frombytes('RGBA',(meta['width'],meta['height']),raw).save(path);print('texture',identity,meta['width'],flush=True)
   except Exception as ex:print('TEXTURE FAILURE',identity,str(ex)[:1000],flush=True)
 (out/'meshes.json').write_text(json.dumps(manifest,indent=2))
finally:p.terminate()
