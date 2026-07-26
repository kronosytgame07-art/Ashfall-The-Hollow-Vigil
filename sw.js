const CACHE='ashfall-v8';
const CORE=['./','./index.html','./manifest.json','./assets/app-icon.svg','./assets/vendor/three-r128.min.js',
  './assets/scenery/ash.webp','./assets/scenery/forest.webp','./assets/scenery/ice.webp','./assets/scenery/swamp.webp','./assets/scenery/volcano.webp',
  ...['gold','wood','soul','gems','trophy','attack','build','settings'].map(n=>`./assets/ui/icons/${n}.webp`),
  ...['walk-1','walk-2','walk-3','walk-4','back-1','back-2','back-3','back-4','work-1','work-2','work-3','work-4'].map(n=>`./assets/village/villager/${n}.webp`),
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
