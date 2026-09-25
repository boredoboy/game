import fs from 'node:fs';
import path from 'node:path';
import zlib from 'node:zlib';

const root = path.resolve(import.meta.dirname, '..');
const rate = 22050;
let seed = 407;
function random() { seed = (seed * 1664525 + 1013904223) >>> 0; return seed / 4294967296; }
function clamp(v) { return Math.max(0, Math.min(255, Math.round(v))); }
const crcTable = new Uint32Array(256);
for (let n=0;n<256;n++) { let c=n; for(let k=0;k<8;k++) c=(c&1)?(0xedb88320^(c>>>1)):(c>>>1); crcTable[n]=c>>>0; }
function crc32(buf) { let c=0xffffffff; for(const b of buf) c=crcTable[(c^b)&255]^(c>>>8); return (c^0xffffffff)>>>0; }
function chunk(type, data) { const t=Buffer.from(type), body=Buffer.concat([t,data]), out=Buffer.alloc(8); out.writeUInt32BE(data.length,0); out.writeUInt32BE(crc32(body),4); return Buffer.concat([out,body]); }
function writePng(file, width, height, pixel) {
  const rows=Buffer.alloc((width*3+1)*height);
  for(let y=0;y<height;y++) { const offset=y*(width*3+1); rows[offset]=0; for(let x=0;x<width;x++){const p=pixel(x,y); const o=offset+1+x*3; rows[o]=p[0];rows[o+1]=p[1];rows[o+2]=p[2];} }
  const ihdr=Buffer.alloc(13);ihdr.writeUInt32BE(width,0);ihdr.writeUInt32BE(height,4);ihdr[8]=8;ihdr[9]=2;
  const out=Buffer.concat([Buffer.from([137,80,78,71,13,10,26,10]),chunk('IHDR',ihdr),chunk('IDAT',zlib.deflateSync(rows,{level:8})),chunk('IEND',Buffer.alloc(0))]);
  fs.mkdirSync(path.dirname(file),{recursive:true});fs.writeFileSync(file,out);
}
function texture(kind) { return (x,y)=>{const n=(random()-.5)*22;let base;
  if(kind==='tarmac'){const c=((x*7+y*13)%181<2)?20:0;base=[61+n-c,68+n-c,66+n-c];}
  else if(kind==='concrete'){const seam=(x<3||x>252||y<3||y>252)?23:0;base=[103+n-seam,107+n-seam,102+n-seam];}
  else if(kind==='rusted_metal'){const rib=x%28<3?19:-8,rust=(x*17+y*29)%83<8?30:0;base=[69+n+rib+rust,72+n+rib+rust,67+n+rib+rust];}
  else if(kind==='crate_wood'){const grain=18*Math.sin(y*.23+Math.sin(x*.07)),seam=y%63<3?25:0;base=[112+n+grain-seam,89+n+grain-seam,59+n+grain-seam];}
  else if(kind==='field_cloth'){const weave=(x+y)%3===0?5:-2;base=[65+n*.45+weave,80+n*.45+weave,72+n*.45+weave];}
  else if(kind==='anime_hair'){const strand=((x+9*Math.sin(y*.035))%46)<3?17:0;base=[32+n*.22+strand,46+n*.22+strand,57+n*.22+strand];}
  else if(kind==='soft_skin'){const blush=7*Math.sin(x*.07)*Math.sin(y*.045);base=[224+n*.24+blush,177+n*.24+blush,150+n*.24+blush];}
  else {const c=((x+y)/27|0)%2===0?[205,164,84]:[36,42,42];base=c.map(v=>v+n*.3);}
  return base.map(clamp);}; }
for(const [file,kind] of Object.entries({
  'environment/tarmac.png':'tarmac','environment/concrete.png':'concrete','environment/rusted_metal.png':'rusted_metal','environment/crate_wood.png':'crate_wood','environment/hazard_stripe.png':'hazard',
  'characters/field_cloth.png':'field_cloth','characters/anime_hair.png':'anime_hair','characters/soft_skin.png':'soft_skin'
})) writePng(path.join(root,'assets/textures/packs',file),256,256,texture(kind));

function writeWav(file,duration,synth){const count=Math.floor(rate*duration), pcm=Buffer.alloc(count*2);for(let i=0;i<count;i++){const t=i/rate,s=Math.max(-1,Math.min(1,synth(t,i,count)));pcm.writeInt16LE(Math.round(s*32767),i*2);}const header=Buffer.alloc(44);header.write('RIFF',0);header.writeUInt32LE(36+pcm.length,4);header.write('WAVE',8);header.write('fmt ',12);header.writeUInt32LE(16,16);header.writeUInt16LE(1,20);header.writeUInt16LE(1,22);header.writeUInt32LE(rate,24);header.writeUInt32LE(rate*2,28);header.writeUInt16LE(2,32);header.writeUInt16LE(16,34);header.write('data',36);header.writeUInt32LE(pcm.length,40);fs.mkdirSync(path.dirname(file),{recursive:true});fs.writeFileSync(file,Buffer.concat([header,pcm]));}
const wav=(file,duration,fn)=>writeWav(path.join(root,'assets/audio/packs',file),duration,fn);
const env=(t,d,decay)=>Math.exp(-t*decay)*Math.min(1,t*120)*Math.min(1,(d-t)*16);
wav('core_sfx/weapons/rifle_shot.wav',.27,(t,i,n)=>env(t,n/rate,13)*(random()-.5)*1.2+env(t,n/rate,13)*Math.sin(2*Math.PI*(72-42*t)*t)*.42);
wav('core_sfx/weapons/reload.wav',1.35,(t)=>{let sum=0;for(const [at,f] of [[.08,690],[.35,280],[.75,520],[1.08,340]]){const dt=t-at;if(dt>=0&&dt<.18)sum+=Math.sin(2*Math.PI*(f-140*dt)*dt)*Math.exp(-dt*19)*.65+(random()-.5)*Math.exp(-dt*34)*.32;}return sum;});
wav('core_sfx/weapons/empty.wav',.15,(t,i,n)=>env(t,n/rate,30)*(Math.sin(2*Math.PI*480*t)*.5+(random()-.5)*.24));
wav('core_sfx/actors/zombies/zombie_hit.wav',.38,(t,i,n)=>env(t,n/rate,8)*((random()-.5)*1.28+Math.sin(2*Math.PI*95*t)*.27));
wav('voice_pack/zombie_groan.wav',2.3,(t,i,n)=>Math.sin(Math.PI*t/(n/rate))**.8*(Math.sin(2*Math.PI*(72+11*Math.sin(t*2.1))*t)*.52+(random()-.5)*.32));
wav('core_sfx/ui/menu_confirm.wav',.22,(t,i,n)=>Math.sin(Math.PI*t/(n/rate))**2*Math.sin(2*Math.PI*(640-130*t)*t)*.24);
wav('core_sfx/ui/menu_hover.wav',.09,(t,i,n)=>Math.sin(Math.PI*t/(n/rate))**2*Math.sin(2*Math.PI*(790-130*t)*t)*.17);
wav('core_sfx/footsteps/concrete_step.wav',.19,(t,i,n)=>env(t,n/rate,20)*((random()-.5)*.78+Math.sin(2*Math.PI*88*t)*.2));
wav('core_sfx/ambience/radio_static.wav',.8,(t,i,n)=>Math.sin(Math.PI*t/(n/rate))**0.35*((random()-.5)*.22));
wav('ambience_pack/industrial_dawn.wav',12,(t)=>Math.sin(2*Math.PI*46*t)*.075+Math.sin(2*Math.PI*59.4*t)*.035+(random()-.5)*(.03+.024*Math.sin(t*.7)**2)+Math.sin(2*Math.PI*.13*t)*.028);
console.log('Generated 8 texture and 10 WAV starter assets.');
