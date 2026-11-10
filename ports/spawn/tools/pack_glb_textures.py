"""Repack embedded opaque images without changing the GLB geometry or transforms."""
import io,json,struct,sys
from pathlib import Path
from PIL import Image
source=Path(sys.argv[1]);target=Path(sys.argv[2]);raw=source.read_bytes()
length=struct.unpack_from('<I',raw,12)[0];doc=json.loads(raw[20:20+length]);blob=raw[28+length:]
normal_views={doc['images'][doc['textures'][m['normalTexture']['index']]['source']]['bufferView'] for m in doc.get('materials',[]) if m.get('normalTexture')}
image_views={im['bufferView']:im for im in doc.get('images',[]) if 'bufferView' in im}
result=bytearray()
for i,view in enumerate(doc['bufferViews']):
 data=blob[view.get('byteOffset',0):view.get('byteOffset',0)+view['byteLength']]
 if i in image_views:
  im=Image.open(io.BytesIO(data));im.thumbnail((512,512) if i in normal_views else (1024,1024),Image.Resampling.LANCZOS)
  output=io.BytesIO()
  if i in normal_views:
   im.convert('RGB').save(output,format='PNG',optimize=True);image_views[i]['mimeType']='image/png'
  else:
   im.convert('RGB').save(output,format='JPEG',quality=90,optimize=True);image_views[i]['mimeType']='image/jpeg'
  data=output.getvalue()
 while len(result)%4:result.append(0)
 view['byteOffset']=len(result);view['byteLength']=len(data);result.extend(data)
while len(result)%4:result.append(0)
doc['buffers'][0]['byteLength']=len(result)
encoded=json.dumps(doc,separators=(',',':')).encode()
while len(encoded)%4:encoded+=b' '
target.write_bytes(struct.pack('<III',0x46546c67,2,28+len(encoded)+len(result))+struct.pack('<II',len(encoded),0x4e4f534a)+encoded+struct.pack('<II',len(result),0x004e4942)+result)
print('Packed',source.stat().st_size,'to',target.stat().st_size,'bytes')
