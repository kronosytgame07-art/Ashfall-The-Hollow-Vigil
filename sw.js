const CACHE='ashfall-v11';
const CORE=['./','./index.html','./manifest.json','./assets/app-icon.svg','./assets/vendor/three-r128.min.js',
  './assets/scenery/ash.webp','./assets/scenery/forest.webp','./assets/scenery/ice.webp','./assets/scenery/swamp.webp','./assets/scenery/volcano.webp',
  ...['gold','wood','soul','gems','trophy','attack','build','settings'].map(n=>`./assets/ui/icons/${n}.webp`),
  ...['front','back','left','right'].flatMap(d=>[1,2,3,4].map(n=>`./assets/village/villager/${d}-${n}.webp`)),
  ...[1,2,3,4,5,6].map(n=>`./assets/village/villager/work-${n}.webp`),
  './assets/village/construction/frame-0.webp',
  ...['guerrier','archer','brute','hero'].flatMap(t=>['front','back','left','right'].flatMap(d=>[0,1,2,3].map(n=>`./assets/troops/${t}-walk-${d}/frame-${n}.webp`))),
  ...['guerrier','archer','brute','hero'].flatMap(t=>['front','back','left','right'].flatMap(d=>[0,1,2,3].map(n=>`./assets/troops/${t}-attack-${d}/frame-${n}.webp`))),
  ...['dead-tree','pine','iron-rock','moss-rock','thorns','bones','crystal','stump'].map(n=>`./assets/village/obstacles/${n}.webp`)];
self.addEventListener('install',event=>event.waitUntil(caches.open(CACHE).then(cache=>cache.addAll(CORE)).then(()=>self.skipWaiting())));
self.addEventListener('activate',event=>event.waitUntil(caches.keys().then(keys=>Promise.all(keys.filter(key=>key!==CACHE).map(key=>caches.delete(key)))).then(()=>self.clients.claim())));
self.addEventListener('fetch',event=>{
  if(event.request.method!=='GET')return;
  if(event.request.mode==='navigate'){
    event.respondWith(fetch(event.request).then(response=>{
      const copy=response.clone();caches.open(CACHE).then(cache=>cache.put('./index.html',copy));return response;
    }).catch(()=>caches.match('./index.html')));
    return;
  }
  event.respondWith(caches.match(event.request).then(hit=>hit||fetch(event.request).then(response=>{
    if(response&&response.ok&&new URL(event.request.url).origin===location.origin){
      const copy=response.clone();caches.open(CACHE).then(cache=>cache.put(event.request,copy));
    }
    return response;
  }).catch(()=>caches.match('./index.html'))));
});
