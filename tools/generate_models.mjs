import fs from "node:fs";
import path from "node:path";

const OUT = path.resolve("models");
const TAU = Math.PI * 2;
fs.mkdirSync(OUT, { recursive: true });

const PALETTE = {
  basalt:[0.105,0.095,0.12,1], stone:[0.23,0.22,0.25,1], stone2:[0.31,0.29,0.32,1],
  iron:[0.18,0.19,0.21,1], wood:[0.27,0.16,0.09,1], darkwood:[0.12,0.075,0.055,1],
  roof:[0.25,0.075,0.055,1], gold:[0.68,0.38,0.07,1], bone:[0.68,0.63,0.51,1],
  earth:[0.12,0.105,0.12,1], ember:[1.0,0.15,0.015,1], soul:[0.36,0.12,0.72,1],
  moss:[0.13,0.20,0.12,1], crystal:[0.27,0.09,0.55,1], cloth:[0.30,0.08,0.07,1]
};

class Model {
  constructor(name){ this.name=name; this.groups=new Map(); }
  group(mat){
    if(!this.groups.has(mat)) this.groups.set(mat,{p:[],n:[],i:[]});
    return this.groups.get(mat);
  }
  tri(mat,a,b,c){
    const g=this.group(mat), u=sub(b,a),v=sub(c,a),n=norm(cross(u,v)),base=g.p.length/3;
    for(const q of [a,b,c]){g.p.push(...q);g.n.push(...n)}
    g.i.push(base,base+1,base+2);
  }
  quad(mat,a,b,c,d){this.tri(mat,a,b,c);this.tri(mat,a,c,d)}
  box(mat,c,s,ry=0){
    const [x,y,z]=s.map(v=>v/2), pts=[
      [-x,-y,-z],[x,-y,-z],[x,y,-z],[-x,y,-z],[-x,-y,z],[x,-y,z],[x,y,z],[-x,y,z]
    ].map(p=>add(rotY(p,ry),c));
    for(const f of [[0,3,2,1],[4,5,6,7],[0,4,7,3],[1,2,6,5],[3,7,6,2],[0,1,5,4]])
      this.quad(mat,pts[f[0]],pts[f[1]],pts[f[2]],pts[f[3]]);
  }
  cylinder(mat,c,r,h,segments=12,top=r){
    const y0=c[1]-h/2,y1=c[1]+h/2;
    for(let k=0;k<segments;k++){
      const a=k*TAU/segments,b=(k+1)*TAU/segments;
      const p0=[c[0]+Math.cos(a)*r,y0,c[2]+Math.sin(a)*r],p1=[c[0]+Math.cos(b)*r,y0,c[2]+Math.sin(b)*r];
      const q0=[c[0]+Math.cos(a)*top,y1,c[2]+Math.sin(a)*top],q1=[c[0]+Math.cos(b)*top,y1,c[2]+Math.sin(b)*top];
      this.quad(mat,p0,q0,q1,p1);this.tri(mat,[c[0],y0,c[2]],p1,p0);
      if(top>0)this.tri(mat,[c[0],y1,c[2]],q0,q1);
    }
  }
  cone(mat,c,r,h,segments=12){this.cylinder(mat,c,r,h,segments,0)}
  beam(mat,a,b,w){
    const mid=a.map((v,i)=>(v+b[i])/2),d=sub(b,a),len=Math.hypot(...d);
    this.box(mat,mid,[w,w,len],Math.atan2(d[0],d[2]));
  }
  stairs(mat,start,width,stepH,stepD,count,dir=1){
    for(let k=0;k<count;k++)this.box(mat,[start[0],start[1]+stepH*(k+.5),start[2]+dir*stepD*(k+.5)],[width,stepH,stepD]);
  }
}
const add=(a,b)=>a.map((v,i)=>v+b[i]),sub=(a,b)=>a.map((v,i)=>v-b[i]);
const cross=(a,b)=>[a[1]*b[2]-a[2]*b[1],a[2]*b[0]-a[0]*b[2],a[0]*b[1]-a[1]*b[0]];
const norm=a=>{const l=Math.hypot(...a)||1;return a.map(v=>v/l)};
const rotY=(p,a)=>[p[0]*Math.cos(a)+p[2]*Math.sin(a),p[1],-p[0]*Math.sin(a)+p[2]*Math.cos(a)];

function crenels(m,r,y,count=8){
  for(let i=0;i<count;i++){const a=i*TAU/count;m.box("stone2",[Math.cos(a)*r,y,Math.sin(a)*r],[.42,.55,.42],-a)}
}
function torch(m,x,y,z){m.cylinder("iron",[x,y-.25,z],.055,.55,8);m.cone("ember",[x,y+.05,z],.16,.42,8)}
function windowGlow(m,x,y,z,sx=.35,sy=.55){m.box("ember",[x,y,z],[sx,sy,.035])}
function timberFrame(m,w,d,y){
  for(const x of [-w/2,w/2])for(const z of [-d/2,d/2])m.box("wood",[x,y,z],[.18,y*2,.18]);
  for(const z of [-d/2,d/2])m.beam("wood",[-w/2,.5,z],[w/2,y*1.8,z],.15);
}
function base(m,w,d){m.box("basalt",[0,.16,0],[w,.32,d]);m.box("stone",[0,.38,0],[w*.91,.18,d*.91])}

function townHall(){
  const m=new Model("Town Hall");base(m,5.8,5.8);
  m.box("stone",[0,1.8,0],[4.5,2.9,4.4]);m.box("stone2",[0,3.25,0],[4.8,.32,4.7]);
  for(const [x,z] of [[-2.1,-2.05],[2.1,-2.05],[-2.1,2.05],[2.1,2.05]]){
    m.cylinder("stone2",[x,2.35,z],.62,3.9,10,.54);crenels(m,.72,4.4,8);
    m.cone("roof",[x,4.85,z],.88,1.25,8)
  }
  m.cone("roof",[0,4.25,0],3.1,2.35,4);
  m.box("darkwood",[0,1.25,2.23],[1.05,1.85,.15]);m.stairs("stone",[0,.4,2.45],1.7,.16,.32,4,1);
  for(const x of [-1.45,1.45])windowGlow(m,x,2.15,2.23);
  for(const x of [-2.55,2.55])torch(m,x,1.55,2.42);
  m.box("cloth",[0,4.9,-.1],[.08,2.4,.08]);m.box("cloth",[.48,5.45,-.1],[.9,.72,.04]);
  return m;
}
function mine(){
  const m=new Model("Gold Mine");base(m,3.9,3.9);m.cylinder("stone",[0,.95,0],1.55,1.35,12,1.4);
  for(let i=0;i<8;i++){const a=i*TAU/8;m.box("wood",[Math.cos(a)*1.35,1.1,Math.sin(a)*1.35],[.18,1.35,.18],-a)}
  m.cylinder("iron",[0,1.82,0],1.15,.18,16);m.cylinder("gold",[0,2.02,0],.72,.45,10,.58);
  for(let i=0;i<7;i++){const a=i*2.4;m.cone("gold",[Math.cos(a)*.58,2.45+Math.sin(i)*.12,Math.sin(a)*.58],.18,.68,6)}
  m.box("darkwood",[0,.9,1.5],[.85,1.2,.12]);torch(m,1.45,1.25,1.45);return m;
}
function sawmill(){
  const m=new Model("Sawmill");base(m,3.9,3.9);m.box("wood",[.35,1.25,-.25],[2.65,1.7,2.35]);
  timberFrame(m,2.7,2.4,1.85);m.cone("roof",[.35,2.75,-.25],2.05,1.35,4);
  for(let i=0;i<5;i++){m.cylinder("wood",[-1.35,.53,-1.25+i*.48],.17,2.5,10); }
  m.cylinder("iron",[1.0,1.15,1.22],.72,.09,24);m.box("darkwood",[1.0,.62,1.22],[1.75,.3,.7]);return m;
}
function barracks(){
  const m=new Model("Barracks");base(m,4.0,4.0);m.box("stone",[0,1.55,0],[3.2,2.25,2.9]);
  timberFrame(m,3.25,2.95,2.45);m.cone("roof",[0,3.25,0],2.45,1.5,4);
  m.box("darkwood",[0,1.28,1.5],[.82,1.72,.14]);m.box("cloth",[0,3.75,1.72],[1.4,.62,.05]);
  for(const x of [-1.35,1.35])torch(m,x,1.55,1.62);return m;
}
function camp(){
  const m=new Model("Army Camp");base(m,5.8,5.8);
  for(const [x,z,r] of [[-1.5,-1.2,0],[1.4,-1.25,.12],[-1.25,1.45,-.1]]){
    m.cone("cloth",[x,1.0,z],1.25,1.9,4);m.box("darkwood",[x,.25,z],[2.1,.15,2.1],r)
  }
  m.cylinder("stone",[1.35,.38,1.35],.72,.35,12);torch(m,1.35,.78,1.35);
  for(let i=0;i<4;i++){const a=i*TAU/4;m.box("wood",[Math.cos(a)*.65,.35+Math.sin(i)*.08,Math.sin(a)*.65],[.2,.2,1.3],a)}
  return m;
}
function altar(){
  const m=new Model("Soul Altar");base(m,3.9,3.9);m.cylinder("stone",[0,.65,0],1.45,.75,8,1.22);
  m.cylinder("basalt",[0,1.25,0],.9,.82,8,.7);for(let i=0;i<6;i++){const a=i*TAU/6;m.cone("stone2",[Math.cos(a)*1.35,1.45,Math.sin(a)*1.35],.22,1.65,5)}
  m.cylinder("soul",[0,2.08,0],.38,.9,12,0);return m;
}
function forge(){
  const m=new Model("Forge");base(m,3.9,3.9);m.box("stone",[0,1.35,0],[3.0,2.0,2.7]);m.cone("roof",[0,2.8,0],2.2,1.3,4);
  m.cylinder("stone2",[.95,2.4,-.6],.36,3.4,10,.3);m.box("iron",[-.65,.78,1.35],[1.05,.28,.52]);
  m.box("ember",[-.65,.56,1.35],[.72,.12,.36]);torch(m,1.25,1.45,1.48);return m;
}
function tower(){
  const m=new Model("Watch Tower");base(m,3.9,3.9);m.cylinder("stone",[0,2.6,0],1.42,4.65,12,1.25);
  m.cylinder("stone2",[0,4.82,0],1.7,.45,12);crenels(m,1.6,5.28,12);m.cone("roof",[0,5.78,0],1.65,1.45,12);
  windowGlow(m,0,3.1,1.33,.3,.7);torch(m,1.25,4.85,1.1);return m;
}
function laboratory(){
  const m=new Model("Laboratory");base(m,3.9,3.9);m.cylinder("stone",[0,1.55,0],1.45,2.45,12,1.32);m.cone("roof",[0,3.25,0],1.9,1.2,12);
  for(const [x,c] of [[-.72,"soul"],[.72,"ember"]]){m.cylinder("iron",[x,1.22,1.35],.3,.9,12,.22);m.cylinder(c,[x,1.52,1.35],.18,.42,10,.15)}
  m.cylinder("iron",[.95,2.55,-.45],.22,2.5,10,.18);return m;
}
function spellHall(){
  const m=new Model("Spell Hall");base(m,3.9,3.9);
  for(let i=0;i<6;i++){const a=i*TAU/6;m.cylinder("stone2",[Math.cos(a)*1.42,1.25,Math.sin(a)*1.42],.2,1.85,8,.15);m.cone("soul",[Math.cos(a)*1.42,2.35,Math.sin(a)*1.42],.16,.5,7)}
  m.cylinder("basalt",[0,.75,0],1.1,.9,16);m.cylinder("soul",[0,1.25,0],.65,.08,24);return m;
}
function yard(){
  const m=new Model("Builders Yard");base(m,3.9,3.9);
  for(const x of [-1.3,1.3])for(const z of [-1.3,1.3])m.box("wood",[x,1.35,z],[.22,2.5,.22]);
  for(const z of [-1.3,1.3])m.beam("wood",[-1.3,2.55,z],[1.3,2.55,z],.2);
  for(const x of [-1.3,1.3])m.beam("wood",[x,2.55,-1.3],[x,2.55,1.3],.2);
  m.stairs("wood",[0,.32,.65],2.2,.22,.4,5,-1);m.box("iron",[.9,.72,1.25],[.8,.18,.5]);return m;
}
function wall(){
  const m=new Model("Wall");base(m,1.9,1.9);m.box("stone",[0,.95,0],[1.72,1.55,1.5]);
  for(const x of [-.62,0,.62])m.box("stone2",[x,1.92,0],[.38,.42,1.55]);return m;
}

function rock(){
  const m=new Model("Corrupted Rocks");base(m,1.9,1.9);
  for(let i=0;i<7;i++){const a=i*2.3,r=.25+i*.035;m.cone(i%3===0?"crystal":"stone2",[Math.cos(a)*.58,.45+i*.05,Math.sin(a)*.58],r,.75+i*.12,6)}
  return m;
}
function deadTree(){
  const m=new Model("Dead Tree");base(m,1.9,1.9);m.cylinder("darkwood",[0,1.45,0],.34,2.8,9,.22);
  for(const [a,y,l] of [[-.75,2.1,1.7],[.65,2.5,1.55],[-1.15,2.75,1.1]]){const end=[Math.sin(a)*l,y+Math.cos(a)*l,Math.cos(a)*l*.2];m.beam("wood",[0,y,0],end,.18)}
  for(let i=0;i<6;i++){const a=i*TAU/6;m.beam("darkwood",[0,.18,0],[Math.cos(a)*.9,.05,Math.sin(a)*.9],.12)}return m;
}
function bones(){
  const m=new Model("Bones");base(m,1.9,1.9);
  for(let i=0;i<8;i++){const a=i*.83;m.beam("bone",[-.45+Math.cos(a)*.35,.25,-.3+Math.sin(a)*.3],[.45+Math.cos(a)*.3,.18,.3+Math.sin(a)*.25],.11)}
  m.cylinder("bone",[.28,.32,-.18],.32,.42,10,.28);return m;
}
function crystals(){
  const m=new Model("Soul Crystals");base(m,1.9,1.9);
  for(let i=0;i<8;i++){const a=i*2.2;m.cone(i%3?"crystal":"soul",[Math.cos(a)*.58,.55+i*.04,Math.sin(a)*.58],.18+i*.018,.9+i*.13,6)}return m;
}

function scenery(){
  const m=new Model("Ashfall Mountain Ring"), N=42,size=72,step=size/N;
  const h=(x,z)=>{
    const d=Math.max(Math.abs(x),Math.abs(z)),edge=Math.max(0,(d-22)/14);
    const ridge=edge*edge*15, noise=Math.sin(x*.22)*Math.cos(z*.17)*1.4+Math.sin((x+z)*.41)*.55;
    return Math.max(-.25,ridge+noise*edge);
  };
  for(let iz=0;iz<N;iz++)for(let ix=0;ix<N;ix++){
    const x=-size/2+ix*step,z=-size/2+iz*step,x1=x+step,z1=z+step;
    const a=[x,h(x,z),z],b=[x1,h(x1,z),z],c=[x1,h(x1,z1),z1],d=[x,h(x,z1),z1];
    m.tri("earth",a,c,b);m.tri("earth",a,d,c)
  }
  for(let i=0;i<28;i++){const a=i*2.399,r=27+(i%5)*1.25,x=Math.cos(a)*r,z=Math.sin(a)*r;
    m.cone(i%4===0?"basalt":"stone",[x,h(x,z)+1.3,z],1.2+(i%3)*.45,3.5+(i%6)*1.15,7)}
  for(let i=0;i<18;i++){const a=i*TAU/18,r=31,x=Math.cos(a)*r,z=Math.sin(a)*r;
    m.box("stone",[x,h(x,z)+1.0,z],[1.2+(i%3)*.5,2+(i%4)*.8,.9],-a)}
  return m;
}

const models = {
  "buildings/town_hall":townHall(),"buildings/gold_mine":mine(),"buildings/sawmill":sawmill(),
  "buildings/barracks":barracks(),"buildings/army_camp":camp(),"buildings/soul_altar":altar(),
  "buildings/forge":forge(),"buildings/tower":tower(),"buildings/laboratory":laboratory(),
  "buildings/spell_hall":spellHall(),"buildings/builders_yard":yard(),"buildings/wall":wall(),
  "obstacles/corrupted_rocks":rock(),"obstacles/dead_tree":deadTree(),"obstacles/bones":bones(),
  "obstacles/soul_crystals":crystals(),"environment/mountain_ring":scenery()
};

for(const [rel,model] of Object.entries(models)){
  const dest=path.join(OUT,rel+".glb");fs.mkdirSync(path.dirname(dest),{recursive:true});writeGLB(model,dest);
}
console.log(`Generated ${Object.keys(models).length} GLB models`);

function writeGLB(model,dest){
  const mats=[...model.groups.keys()], chunks=[], views=[], accessors=[], primitives=[];
  let byteOffset=0;
  const append=(typed,target)=>{
    const pad=(4-(byteOffset%4))%4;if(pad){chunks.push(Buffer.alloc(pad));byteOffset+=pad}
    const buf=Buffer.from(typed.buffer,typed.byteOffset,typed.byteLength),view=views.length;
    views.push({buffer:0,byteOffset,byteLength:buf.length,target});chunks.push(buf);byteOffset+=buf.length;return view;
  };
  const acc=(view,componentType,count,type,min,max)=>{const a={bufferView:view,componentType,count,type};if(min)a.min=min;if(max)a.max=max;accessors.push(a);return accessors.length-1};
  for(const [mi,mat] of mats.entries()){
    const g=model.groups.get(mat),pos=new Float32Array(g.p),nor=new Float32Array(g.n),idx=new Uint32Array(g.i);
    const pv=append(pos,34962),nv=append(nor,34962),iv=append(idx,34963);
    const xs=[],ys=[],zs=[];for(let i=0;i<g.p.length;i+=3){xs.push(g.p[i]);ys.push(g.p[i+1]);zs.push(g.p[i+2])}
    primitives.push({attributes:{POSITION:acc(pv,5126,g.p.length/3,"VEC3",[Math.min(...xs),Math.min(...ys),Math.min(...zs)],[Math.max(...xs),Math.max(...ys),Math.max(...zs)]),NORMAL:acc(nv,5126,g.n.length/3,"VEC3")},indices:acc(iv,5125,g.i.length,"SCALAR"),material:mi});
  }
  const json={asset:{version:"2.0",generator:"Ashfall GLB Forge"},scene:0,scenes:[{nodes:[0]}],nodes:[{name:model.name,mesh:0}],meshes:[{name:model.name,primitives}],buffers:[{byteLength:byteOffset}],bufferViews:views,accessors,
    materials:mats.map(name=>({name,pbrMetallicRoughness:{baseColorFactor:PALETTE[name],metallicFactor:name==="iron"?.65:.05,roughnessFactor:name==="gold"?.38:.82},emissiveFactor:name==="ember"?[1,.08,.01]:name==="soul"?[.25,.03,.65]:[0,0,0]}))};
  const j=Buffer.from(JSON.stringify(json)),jp=Buffer.concat([j,Buffer.alloc((4-j.length%4)%4,0x20)]),bin=Buffer.concat(chunks),bp=Buffer.concat([bin,Buffer.alloc((4-bin.length%4)%4)]);
  const head=Buffer.alloc(12),jh=Buffer.alloc(8),bh=Buffer.alloc(8);head.writeUInt32LE(0x46546c67,0);head.writeUInt32LE(2,4);head.writeUInt32LE(12+8+jp.length+8+bp.length,8);
  jh.writeUInt32LE(jp.length,0);jh.writeUInt32LE(0x4e4f534a,4);bh.writeUInt32LE(bp.length,0);bh.writeUInt32LE(0x004e4942,4);
  fs.writeFileSync(dest,Buffer.concat([head,jh,jp,bh,bp]));
}
