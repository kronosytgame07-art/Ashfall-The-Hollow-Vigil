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
  beam3(mat,a,b,w){
    const d=norm(sub(b,a)),helper=Math.abs(d[1])>.92?[1,0,0]:[0,1,0],u=norm(cross(d,helper)),v=norm(cross(d,u)),h=w/2;
    const ring=p=>[
      add(add(p,u.map(n=>n*h)),v.map(n=>n*h)),
      add(add(p,u.map(n=>-n*h)),v.map(n=>n*h)),
      add(add(p,u.map(n=>-n*h)),v.map(n=>-n*h)),
      add(add(p,u.map(n=>n*h)),v.map(n=>-n*h))
    ],ra=ring(a),rb=ring(b);
    this.quad(mat,ra[0],ra[1],ra[2],ra[3]);this.quad(mat,rb[3],rb[2],rb[1],rb[0]);
    for(let i=0;i<4;i++)this.quad(mat,ra[i],rb[i],rb[(i+1)%4],ra[(i+1)%4]);
  }
  roofPanel(mat,side,ridgeY,eaveY,halfW,depth,overhang=.15){
    const x0=side*halfW,x1=0,z0=-depth/2-overhang,z1=depth/2+overhang,t=.12;
    const a=[x0,eaveY,z0],b=[x0,eaveY,z1],c=[x1,ridgeY,z1],d=[x1,ridgeY,z0];
    const down=[0,-t,0],a2=add(a,down),b2=add(b,down),c2=add(c,down),d2=add(d,down);
    this.quad(mat,a,b,c,d);this.quad(mat,d2,c2,b2,a2);
    this.quad(mat,a,a2,b2,b);this.quad(mat,b,b2,c2,c);this.quad(mat,c,c2,d2,d);this.quad(mat,d,d2,a2,a);
  }
  stairs(mat,start,width,stepH,stepD,count,dir=1){
    for(let k=0;k<count;k++)this.box(mat,[start[0],start[1]+stepH*(k+.5),start[2]+dir*stepD*(k+.5)],[width,stepH,stepD]);
  }
}
const add=(a,b)=>a.map((v,i)=>v+b[i]),sub=(a,b)=>a.map((v,i)=>v-b[i]);
const cross=(a,b)=>[a[1]*b[2]-a[2]*b[1],a[2]*b[0]-a[0]*b[2],a[0]*b[1]-a[1]*b[0]];
const norm=a=>{const l=Math.hypot(...a)||1;return a.map(v=>v/l)};
const rotY=(p,a)=>[p[0]*Math.cos(a)+p[2]*Math.sin(a),p[1],-p[0]*Math.sin(a)+p[2]*Math.cos(a)];

function crenels(m,r,y,count=8,cx=0,cz=0){
  for(let i=0;i<count;i++){const a=i*TAU/count;m.box("stone2",[cx+Math.cos(a)*r,y,cz+Math.sin(a)*r],[.42,.55,.42],-a)}
}
function torch(m,x,y,z){m.cylinder("iron",[x,y-.25,z],.055,.55,8);m.cone("ember",[x,y+.05,z],.16,.42,8)}
function windowGlow(m,x,y,z,sx=.35,sy=.55){m.box("ember",[x,y,z],[sx,sy,.035])}
function timberFrame(m,w,d,y){
  for(const x of [-w/2,w/2])for(const z of [-d/2,d/2])m.box("wood",[x,y,z],[.18,y*2,.18]);
  for(const z of [-d/2,d/2])m.beam("wood",[-w/2,.5,z],[w/2,y*1.8,z],.15);
}
function base(m,w,d){m.box("basalt",[0,.16,0],[w,.32,d]);m.box("stone",[0,.38,0],[w*.91,.18,d*.91])}
function gothicDress(m,w,d,height=2.2){
  // Contreforts, ferrures, braseros et pieux donnent à chaque silhouette une
  // lecture dark-fantasy cohérente sans dépasser son empreinte de grille.
  const x=w/2-.22,z=d/2-.22;
  for(const sx of [-1,1])for(const sz of [-1,1]){
    m.box("stone2",[sx*x,.72,sz*z],[.28,1.05,.28]);
    m.cone("iron",[sx*x,1.48,sz*z],.16,.5,6);
  }
  for(const sx of [-1,1]){
    m.box("iron",[sx*(w/2-.08),height*.58,0],[.08,height*.72,.12]);
    m.box("cloth",[sx*(w/2-.13),height*.68,.04],[.05,.62,.48]);
  }
  for(const zf of [-1,1])torch(m,w*.24,height*.55,zf*(d/2-.08));
}

function townHall(){
  const m=new Model("Ashfall Gothic Town Hall Level 1");base(m,5.8,5.8);
  // Soubassement et grande halle à colombages, inspirés de la référence fournie.
  m.box("stone",[0,.82,0],[4.85,.9,4.4]);
  m.box("darkwood",[0,2.08,0],[4.55,1.75,4.15]);
  m.box("stone2",[0,.48,0],[5.25,.24,4.85]);
  for(let x=-2.1;x<=2.1;x+=.7){
    m.box((Math.round(x*10)%2)?"stone":"stone2",[x,.72,2.22],[.59,.32,.28]);
    m.box("stone",[x,.72,-2.22],[.59,.32,.28]);
  }
  // Charpente principale : poteaux, traverses et croix de Saint-André réellement en relief.
  for(const x of [-2.18,-1.1,0,1.1,2.18]){
    m.box("wood",[x,2.08,2.12],[.16,2.45,.18]);
    m.box("wood",[x,2.08,-2.12],[.16,2.45,.18]);
  }
  for(const y of [1.05,2.05,2.95]){
    m.box("wood",[0,y,2.14],[4.55,.15,.18]);
    m.box("wood",[0,y,-2.14],[4.55,.15,.18]);
  }
  for(const x of [-1.65,-.55,.55,1.65]){
    m.beam3("wood",[x-.42,1.13,2.24],[x+.42,1.95,2.24],.11);
    m.beam3("wood",[x+.42,1.13,-2.24],[x-.42,1.95,-2.24],.11);
  }
  // Pignons triangulaires et toit monumental très pentu.
  m.tri("darkwood",[-2.28,3.0,2.08],[2.28,3.0,2.08],[0,5.72,2.08]);
  m.tri("darkwood",[2.28,3.0,-2.08],[-2.28,3.0,-2.08],[0,5.72,-2.08]);
  for(const z of [-2.11,2.11]){
    m.beam3("wood",[-2.24,3.02,z],[0,5.7,z],.18);
    m.beam3("wood",[2.24,3.02,z],[0,5.7,z],.18);
    m.box("wood",[0,4.15,z],[.16,2.2,.2]);
    m.box("wood",[0,3.5,z],[2.55,.14,.2]);
  }
  m.roofPanel("roof",-1,5.82,2.83,2.78,4.55,.24);
  m.roofPanel("roof",1,5.82,2.83,2.78,4.55,.24);
  m.box("iron",[0,5.82,0],[.16,.16,4.95]);
  // Rangées de tuiles sombres/orangées qui cassent l'aspect parfaitement lisse.
  for(let row=0;row<7;row++){
    const t=row/7,y=2.98+(5.72-2.98)*t,x=2.55*(1-t);
    for(const side of [-1,1])m.beam3(row%3?"roof":"cloth",[side*x,y,-2.32],[side*x,y,2.32],.075);
  }
  // Grand porche frontal, perron et garde-corps de pierre.
  m.box("darkwood",[0,1.55,2.27],[1.45,2.25,.22]);
  m.box("wood",[0,2.67,2.38],[2.25,.24,.28]);
  for(const x of [-.92,.92])m.box("wood",[x,1.72,2.38],[.22,2.05,.24]);
  m.stairs("stone",[0,.36,.72],2.45,.15,.3,6,1);
  for(const x of [-1.42,1.42]){
    m.box("stone2",[x,.78,2.72],[.4,1.05,.42]);
    m.box("stone",[x,.94,2.45],[.22,.72,.7]);
  }
  // Double porte avec ferrures et lueurs intérieures.
  m.box("basalt",[0,1.62,2.36],[1.3,2.18,.18]);
  m.box("darkwood",[0,1.59,2.48],[1.02,1.94,.16]);
  for(const x of [-.36,0,.36])m.box("iron",[x,1.59,2.58],[.055,1.75,.04]);
  for(const y of [.9,1.52,2.17])m.box("iron",[0,y,2.59],[.95,.065,.04]);
  windowGlow(m,0,1.57,2.61,.32,.6);
  // Fenêtres chaudes sur la façade et les côtés.
  for(const x of [-1.55,1.55]){
    m.box("basalt",[x,1.85,2.22],[.65,.95,.2]);windowGlow(m,x,1.85,2.34,.4,.68);
    m.box("iron",[x,1.85,2.39],[.045,.68,.035]);m.box("iron",[x,1.85,2.39],[.4,.045,.035]);
  }
  for(const z of [-1.25,.25,1.25]){
    m.box("ember",[2.29,1.75,z],[.04,.62,.4]);m.box("ember",[-2.29,1.75,z],[.04,.62,.4]);
  }
  // Lucarne secondaire sur le pan droit.
  m.box("darkwood",[1.18,4.05,.55],[.95,1.15,.75]);
  m.cone("roof",[1.18,4.78,.55],.86,.72,4);
  windowGlow(m,1.18,4.1,1.0,.42,.55);
  // Cheminée massive en pierres appareillées.
  m.box("stone",[1.63,4.2,-.72],[.78,3.4,.82]);
  for(let y=2.72;y<5.75;y+=.38)m.box(y%1>.5?"stone2":"basalt",[1.63,y,-.29],[.82,.09,.08]);
  m.box("stone2",[1.63,5.88,-.72],[1.0,.25,1.02]);
  for(const x of [1.38,1.88])for(const z of [-.97,-.47])m.box("stone2",[x,6.12,z],[.24,.32,.24]);
  // Bannière, lanternes, bois mort et braises périphériques.
  m.box("iron",[-2.55,1.55,2.7],[.08,2.7,.08]);
  m.box("iron",[-2.16,2.78,2.7],[.82,.08,.08]);
  m.box("cloth",[-2.18,2.12,2.72],[.62,1.22,.05]);
  m.box("gold",[-2.18,2.18,2.755],[.1,.62,.025]);
  for(const x of [-.92,.92]){torch(m,x,2.02,2.68);m.box("iron",[x,2.02,2.49],[.4,.06,.06]);}
  for(const [x,z] of [[-2.25,-1.8],[2.35,1.65],[1.95,-2.1]]){
    m.beam3("darkwood",[x,.3,z],[x+(x>0?.42:-.42),1.45,z+.18],.13);
    m.cone("ember",[x,.32,z],.13,.35,7);
  }
  return m;
}
function mine(){
  const m=new Model("Gold Mine");base(m,3.9,3.9);m.cylinder("stone",[0,.95,0],1.55,1.35,12,1.4);
  for(let i=0;i<8;i++){const a=i*TAU/8;m.box("wood",[Math.cos(a)*1.35,1.1,Math.sin(a)*1.35],[.18,1.35,.18],-a)}
  m.cylinder("iron",[0,1.82,0],1.15,.18,16);m.cylinder("gold",[0,2.02,0],.72,.45,10,.58);
  for(let i=0;i<7;i++){const a=i*2.4;m.cone("gold",[Math.cos(a)*.58,2.45+Math.sin(i)*.12,Math.sin(a)*.58],.18,.68,6)}
  m.box("basalt",[0,.92,1.51],[1.15,1.42,.22]);m.box("darkwood",[0,.86,1.64],[.76,1.12,.14]);
  for(const x of [-.3,.3])m.box("iron",[x,.86,1.74],[.06,1.0,.05]);
  for(const x of [-.52,.52])m.box("wood",[x,1.12,1.68],[.16,1.55,.16]);
  m.beam3("wood",[-.62,1.82,1.68],[.62,1.82,1.68],.17);
  m.beam3("iron",[.42,1.82,1.68],[1.15,2.5,.75],.08);
  m.box("iron",[1.15,2.12,.75],[.08,.78,.08]);m.box("gold",[1.15,1.72,.75],[.32,.22,.28]);
  for(const x of [-.42,.42])m.beam3("iron",[x,.18,1.75],[x,.2,2.55],.055);
  torch(m,1.45,1.25,1.45);gothicDress(m,3.9,3.9,2.5);return m;
}
function sawmill(){
  const m=new Model("Sawmill");base(m,3.9,3.9);m.box("wood",[.35,1.25,-.25],[2.65,1.7,2.35]);
  timberFrame(m,2.7,2.4,1.85);m.cone("roof",[.35,2.75,-.25],2.05,1.35,4);
  for(let i=0;i<5;i++){m.cylinder("wood",[-1.35,.53,-1.25+i*.48],.17,2.5,10); }
  m.cylinder("iron",[1.0,1.15,1.22],.72,.09,24);m.box("darkwood",[1.0,.62,1.22],[1.75,.3,.7]);
  gothicDress(m,3.9,3.9,2.8);for(const z of [-1.45,1.45])m.beam3("iron",[-1.5,.55,z],[1.5,.55,z],.07);return m;
}
function barracks(){
  const m=new Model("Barracks");base(m,4.0,4.0);m.box("stone",[0,1.55,0],[3.2,2.25,2.9]);
  timberFrame(m,3.25,2.95,2.45);m.cone("roof",[0,3.25,0],2.45,1.5,4);
  m.box("darkwood",[0,1.28,1.5],[.82,1.72,.14]);m.box("cloth",[0,3.75,1.72],[1.4,.62,.05]);
  for(const x of [-1.35,1.35])torch(m,x,1.55,1.62);
  gothicDress(m,4,4,3.4);for(const x of [-.9,0,.9])m.box("iron",[x,2.15,1.52],[.08,.72,.1]);
  for(const x of [-1.38,1.38]){m.cylinder("wood",[x,.82,-1.52],.1,1.25,8);m.box("iron",[x,1.38,-1.52],[.62,.08,.08]);m.box("iron",[x,1.05,-1.52],[.08,.62,.08]);}
  m.box("iron",[0,1.22,1.58],[.94,.08,.08]);m.box("cloth",[0,2.72,1.6],[.72,.88,.05]);
  for(const x of [-.48,0,.48])m.cone("iron",[x,3.02,1.63],.07,.32,5);return m;
}
function camp(){
  const m=new Model("Ashen Legion Camp");
  m.box("earth",[0,.1,0],[5.75,.2,5.75]);
  for(let i=0;i<18;i++){const a=i*TAU/18,r=2.55+(i%3)*.08;m.box(i%2?"stone":"basalt",[Math.cos(a)*r,.24,Math.sin(a)*r],[.48,.28,.36],-a)}
  for(const [x,z,r] of [[-1.95,-1.82,.12],[1.95,-1.78,-.1],[-2.0,1.86,-.08],[2.04,1.82,.09]]){
    m.cone("cloth",[x,1.0,z],.82,1.58,4);m.box("darkwood",[x,.23,z],[1.42,.14,1.42],r);
    m.box("iron",[x,1.12,z],[.07,1.85,.07]);
  }
  m.cylinder("stone",[0,.32,0],.82,.34,14);m.cylinder("ember",[0,.52,0],.46,.26,12,.28);
  for(let i=0;i<5;i++){const a=i*TAU/5;m.box("wood",[Math.cos(a)*.38,.55,Math.sin(a)*.38],[.12,.12,1.0],a)}
  for(let i=0;i<12;i++){const a=i*TAU/12,r=2.62;m.cone("darkwood",[Math.cos(a)*r,.62,Math.sin(a)*r],.11,1.18,6)}
  for(const x of [-1.25,1.25]){m.box("wood",[x,.48,.15],[1.15,.14,.32]);m.box("iron",[x,.67,.15],[.7,.08,.08]);}
  m.box("iron",[0,1.35,-2.5],[.08,2.3,.08]);m.box("cloth",[.38,1.85,-2.5],[.68,.82,.05]);
  m.box("gold",[.38,1.86,-2.54],[.08,.46,.03]);
  return m;
}
function altar(){
  const m=new Model("Soul Altar");base(m,3.9,3.9);m.cylinder("stone",[0,.65,0],1.45,.75,8,1.22);
  m.cylinder("basalt",[0,1.25,0],.9,.82,8,.7);for(let i=0;i<6;i++){const a=i*TAU/6;m.cone("stone2",[Math.cos(a)*1.35,1.45,Math.sin(a)*1.35],.22,1.65,5)}
  m.cylinder("soul",[0,2.08,0],.38,.9,12,0);gothicDress(m,3.9,3.9,2.6);return m;
}
function forge(){
  const m=new Model("Forge");base(m,3.9,3.9);m.box("stone",[0,1.35,0],[3.0,2.0,2.7]);m.cone("roof",[0,2.8,0],2.2,1.3,4);
  m.cylinder("stone2",[.95,2.4,-.6],.36,3.4,10,.3);m.box("iron",[-.65,.78,1.35],[1.05,.28,.52]);
  m.box("ember",[-.65,.56,1.35],[.72,.12,.36]);torch(m,1.25,1.45,1.48);
  gothicDress(m,3.9,3.9,3.0);for(const y of [1.2,1.65,2.1])m.box("iron",[.96,y,-.25],[.78,.07,.82]);return m;
}
function tower(){
  const m=new Model("Watch Tower");base(m,3.9,3.9);m.cylinder("stone",[0,2.6,0],1.42,4.65,12,1.25);
  m.cylinder("stone2",[0,4.82,0],1.7,.45,12);crenels(m,1.6,5.28,12);m.cone("roof",[0,5.78,0],1.65,1.45,12);
  windowGlow(m,0,3.1,1.33,.3,.7);torch(m,1.25,4.85,1.1);gothicDress(m,3.9,3.9,4.8);
  for(let i=0;i<8;i++){const a=i*TAU/8;m.box("iron",[Math.cos(a)*1.47,3.8,Math.sin(a)*1.47],[.08,1.3,.08],-a)}return m;
}
function laboratory(){
  const m=new Model("Laboratory");base(m,3.9,3.9);m.cylinder("stone",[0,1.55,0],1.45,2.45,12,1.32);m.cone("roof",[0,3.25,0],1.9,1.2,12);
  for(const [x,c] of [[-.72,"soul"],[.72,"ember"]]){m.cylinder("iron",[x,1.22,1.35],.3,.9,12,.22);m.cylinder(c,[x,1.52,1.35],.18,.42,10,.15)}
  m.cylinder("iron",[.95,2.55,-.45],.22,2.5,10,.18);gothicDress(m,3.9,3.9,3.2);
  for(let i=0;i<5;i++){const a=i*TAU/5;m.cone("crystal",[Math.cos(a)*1.15,.62,Math.sin(a)*1.15],.12,.55,6)}return m;
}
function spellHall(){
  const m=new Model("Spell Hall");base(m,3.9,3.9);
  for(let i=0;i<6;i++){const a=i*TAU/6;m.cylinder("stone2",[Math.cos(a)*1.42,1.25,Math.sin(a)*1.42],.2,1.85,8,.15);m.cone("soul",[Math.cos(a)*1.42,2.35,Math.sin(a)*1.42],.16,.5,7)}
  m.cylinder("basalt",[0,.75,0],1.1,.9,16);m.cylinder("soul",[0,1.25,0],.65,.08,24);gothicDress(m,3.9,3.9,2.4);return m;
}
function yard(){
  const m=new Model("Builders Yard");base(m,3.9,3.9);
  for(const x of [-1.3,1.3])for(const z of [-1.3,1.3])m.box("wood",[x,1.35,z],[.22,2.5,.22]);
  for(const z of [-1.3,1.3])m.beam("wood",[-1.3,2.55,z],[1.3,2.55,z],.2);
  for(const x of [-1.3,1.3])m.beam("wood",[x,2.55,-1.3],[x,2.55,1.3],.2);
  m.stairs("wood",[0,.32,.65],2.2,.22,.4,5,-1);m.box("iron",[.9,.72,1.25],[.8,.18,.5]);
  gothicDress(m,3.9,3.9,2.5);m.beam3("iron",[-1.25,2.65,-1.25],[1.25,3.55,-1.25],.09);
  m.beam3("wood",[1.2,.4,-1.2],[1.2,3.45,-1.2],.2);m.beam3("wood",[1.2,3.45,-1.2],[-.75,3.45,-1.2],.18);
  m.box("iron",[-.68,2.62,-1.2],[.07,1.62,.07]);m.box("stone",[-.68,1.72,-1.2],[.52,.42,.5]);
  m.roofPanel("cloth",-1,2.75,2.12,1.55,2.7,.12);m.roofPanel("cloth",1,2.75,2.12,1.55,2.7,.12);
  for(const z of [-.8,0,.8]){m.box("wood",[-1.5,.45,z],[.72,.22,.28]);m.box("iron",[-1.5,.67,z],[.38,.08,.08]);}return m;
}
function wall(){
  const m=new Model("Wall");base(m,1.9,1.9);m.box("stone",[0,.95,0],[1.72,1.55,1.5]);
  for(const x of [-.62,0,.62])m.box("stone2",[x,1.92,0],[.38,.42,1.55]);
  for(const z of [-.62,.62])for(const x of [-.62,.62])m.cone("iron",[x,2.35,z],.09,.42,5);return m;
}

function rock(){
  const m=new Model("Corrupted Rocks");base(m,1.9,1.9);
  for(let i=0;i<11;i++){const a=i*2.3,r=.18+i*.024;m.cone(i%3===0?"crystal":"stone2",[Math.cos(a)*(.38+i*.035),.4+i*.045,Math.sin(a)*(.38+i*.035)],r,.62+i*.1,6)}
  for(let i=0;i<5;i++){const a=i*TAU/5;m.box("soul",[Math.cos(a)*.72,.22,Math.sin(a)*.72],[.12,.08,.34],-a)}
  return m;
}
function deadTree(){
  const m=new Model("Dead Tree");base(m,1.9,1.9);m.cylinder("darkwood",[0,1.45,0],.34,2.8,9,.22);
  for(const [a,y,l] of [[-.75,2.1,1.7],[.65,2.5,1.55],[-1.15,2.75,1.1],[1.35,1.72,1.25]]){const end=[Math.sin(a)*l,y+Math.cos(a)*l,Math.cos(a)*l*.2];m.beam3("wood",[0,y,0],end,.18);m.beam3("darkwood",end,[end[0]+Math.sin(a+.8)*.62,end[1]+.42,end[2]+Math.cos(a+.8)*.35],.09)}
  for(let i=0;i<6;i++){const a=i*TAU/6;m.beam("darkwood",[0,.18,0],[Math.cos(a)*.9,.05,Math.sin(a)*.9],.12)}return m;
}
function bones(){
  const m=new Model("Bones");base(m,1.9,1.9);
  for(let i=0;i<8;i++){const a=i*.83;m.beam("bone",[-.45+Math.cos(a)*.35,.25,-.3+Math.sin(a)*.3],[.45+Math.cos(a)*.3,.18,.3+Math.sin(a)*.25],.11)}
  m.cylinder("bone",[.28,.32,-.18],.32,.42,10,.28);
  for(const x of [-.13,.13])m.box("basalt",[.28+x,.39,.05],[.09,.08,.05]);
  m.box("bone",[.28,.25,.2],[.16,.1,.22]);return m;
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
    if(Math.max(Math.abs((x+x1)/2),Math.abs((z+z1)/2))<25.2)continue;
    const a=[x,h(x,z),z],b=[x1,h(x1,z),z],c=[x1,h(x1,z1),z1],d=[x,h(x,z1),z1];
    m.tri("earth",a,c,b);m.tri("earth",a,d,c)
  }
  for(let i=0;i<28;i++){const a=i*2.399,r=27+(i%5)*1.25,x=Math.cos(a)*r,z=Math.sin(a)*r;
    m.cone(i%4===0?"basalt":"stone",[x,h(x,z)+1.3,z],1.2+(i%3)*.45,3.5+(i%6)*1.15,7)}
  for(let i=0;i<18;i++){const a=i*TAU/18,r=31,x=Math.cos(a)*r,z=Math.sin(a)*r;
    m.box("stone",[x,h(x,z)+1.0,z],[1.2+(i%3)*.5,2+(i%4)*.8,.9],-a)}
  for(let i=0;i<16;i++){const a=i*2.399,r=27.5+(i%3)*1.1,x=Math.cos(a)*r,z=Math.sin(a)*r,y=h(x,z);
    m.cylinder("darkwood",[x,y+1.15,z],.18,2.3,7,.11);
    m.beam3("wood",[x,y+1.6,z],[x+Math.sin(a+.7)*1.05,y+2.35,z+Math.cos(a+.7)*.7],.11);
    if(i%4===0){m.box("stone2",[x+1.1,y+.65,z],[1.4,1.3,.32],-a);m.cone("ember",[x+1.1,y+1.45,z],.12,.38,7)}
  }
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
