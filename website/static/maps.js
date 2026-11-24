/* Detailed travel maps. Leaflet and clustering are served locally; OSM supplies map tiles. */
let travelMap=null,miniMap=null,pickerMap=null,travelClusters=null;
let travelSearch='',travelSelection='',placeLabels=false,travelMarkers=new Map(),travelGroups=[];
let travelViewport=null,travelScopeKey='',travelResizeObserver=null;
function destroyMaps(){
 if(travelMap){travelViewport={center:travelMap.getCenter(),zoom:travelMap.getZoom()};travelMap.remove();travelMap=null}
 if(miniMap){miniMap.remove();miniMap=null}
 if(travelResizeObserver){travelResizeObserver.disconnect();travelResizeObserver=null}
 travelMarkers.clear();travelClusters=null;
}
function mapTrips(){return scope().filter(t=>t.start&&(mapMode==='all'||(mapMode==='visited'?t.start<=today:t.start>today)))}
function visits(rows){const seen=new Set();return rows.filter(t=>{const k=[t.name,t.start,t.end].join('|');if(seen.has(k))return false;seen.add(k);return true})}
function journeyCount(rows){const seen=new Set();for(const t of visits(rows))seen.add(t.group?'journey:'+t.group:'trip:'+t.id);return seen.size}
function placeVisitLabel(rows){const stays=visits(rows).length,trips=journeyCount(rows);return `${trips} ${trips===1?'trip':'trips'}${stays!==trips?` · ${stays} stays`:''}`}
function destinationGroups(rows){
 const groups=new Map();
 for(const t of rows){const p=place(t),pins=p.pins||[{name:t.locations||p.label||t.name,lat:p.lat,lon:p.lon}];
  for(const pin of pins){if(pin.lat==null||pin.lon==null||!Number.isFinite(+pin.lat)||!Number.isFinite(+pin.lon))continue;
   const name=pin.name||t.name,key=`${name.toLowerCase()}|${(+pin.lat).toFixed(4)}|${(+pin.lon).toFixed(4)}`;
   if(!groups.has(key))groups.set(key,{key,name,lat:+pin.lat,lon:+pin.lon,rows:[],countries:new Set()});
   const g=groups.get(key);g.rows.push(t);countries(t).forEach(c=>g.countries.add(c));
  }
 }
 return [...groups.values()].map(g=>({...g,visits:visits(g.rows).sort((a,b)=>b.start.localeCompare(a.start)),countries:[...g.countries].sort()})).sort((a,b)=>a.name.localeCompare(b.name));
}
function mapPage(){
 const ts=mapTrips(),cs=visitedCountries(scope(),mapMode),groups=destinationGroups(ts),tripCount=journeyCount(ts);
 return intro('Map','Explore your destinations. Hover for a name; select a place to learn about it.')+
 `<div class="travel-stats"><span><strong>${cs.length}</strong> countries</span><span><strong>${groups.length}</strong> mapped places</span><span><strong>${tripCount}</strong> ${mapMode==='upcoming'?'planned trips':'trips'}</span><span class="travel-stats-note">${year==='all'?'Your complete travel collection':year}</span></div>
 <div class="travel-toolbar"><div class="segments"><button data-map-mode="visited" class="${mapMode==='visited'?'active':''}">Visited</button><button data-map-mode="upcoming" class="${mapMode==='upcoming'?'active':''}">Upcoming</button><button data-map-mode="all" class="${mapMode==='all'?'active':''}">All trips</button></div><label class="country-select-label"><span class="sr-only">Filter by country</span><select id="map-country"><option value="">Every country</option>${cs.map(c=>`<option ${c===selectedCountry?'selected':''}>${esc(c)}</option>`).join('')}</select></label><label class="map-label-toggle"><input type="checkbox" id="place-labels" ${placeLabels?'checked':''}> Place labels</label></div>
 <div class="travel-layout"><section class="panel travel-canvas" id="map-container" aria-label="Travel map"><div id="travel-map" aria-label="Detailed map of your trips"></div><div class="travel-map-shortcuts"><button data-map-region="all">All places</button><button data-map-region="europe">Europe</button><button data-map-region="uk">UK</button></div><div class="travel-map-actions"><button id="map-fit" title="Fit the selected destinations">⌖ Fit places</button><button id="map-fullscreen" aria-label="Expand map">⛶</button></div><div id="map-tile-notice" class="tile-notice hidden" role="status">Map background couldn’t load. Your destinations are still available.</div></section>
 <section class="panel destination-sidebar"><div id="destination-details"></div><div class="destination-list-head"><h3 id="destination-list-title">${esc(selectedCountry||'Explore destinations')}</h3><small id="destination-list-count"></small><input id="map-search" type="search" aria-label="Search map destinations" placeholder="Find a place or trip…" value="${esc(travelSearch)}"></div><div id="destination-list" class="destination-list"></div></section></div>
 <div class="map-footnote"><span><i class="map-key-pin"></i>Visited place</span><span><i class="map-key-pin future"></i>Upcoming place</span><span><i class="map-key-cluster">3</i>Nearby places · select to explore</span><span>Hover for a name · click for a place overview</span></div>
 <section class="country-section"><div class="panel-head"><div><h2>Your countries</h2><small>Select a country to focus the map and your destinations.</small></div>${selectedCountry?'<button id="map-clear-country">Show every country</button>':''}</div><div class="country-grid">${cs.map(c=>{const rows=visits(ts.filter(t=>countries(t).includes(c)));return `<button class="country-card ${c===selectedCountry?'chosen':''}" data-country="${esc(c)}"><span class="country-card-icon">${countryFlag(c)}</span><strong>${esc(c)}</strong><small>${journeyCount(rows)} ${journeyCount(rows)===1?'trip':'trips'} · since ${Math.min(...rows.map(t=>+t.start.slice(0,4)))}</small></button>`}).join('')||'<div class="empty">No dated trips in this selection yet.</div>'}</div></section>`;
}
function countryFlag(country){const subdivisions={'England':'gbeng','Scotland':'gbsct','Wales':'gbwls'};if(subdivisions[country])return String.fromCodePoint(0x1f3f4,...[...subdivisions[country]].map(c=>0xe0000+c.charCodeAt(0)),0xe007f);if(country==='Northern Ireland')return '<span class="ni-flag" aria-label="Northern Ireland">🇬🇧<small>NI</small></span>';const codes={'United Kingdom':'GB','France':'FR','Italy':'IT','Vatican City':'VA','China':'CN','Hong Kong':'HK','Macau':'MO','United States of America':'US','Ireland':'IE','Iceland':'IS','Portugal':'PT','Austria':'AT','Spain':'ES','Morocco':'MA','Trinidad and Tobago':'TT','Netherlands':'NL','Norway':'NO','Liechtenstein':'LI','Belgium':'BE','Costa Rica':'CR','Mexico':'MX','Japan':'JP','Singapore':'SG','Maldives':'MV','Sweden':'SE','Albania':'AL','Estonia':'EE','Croatia':'HR','Latvia':'LV','Greece':'GR','Jamaica':'JM','Malta':'MT','South Korea':'KR','Hungary':'HU','Lithuania':'LT','Turkey':'TR'};return codes[country]?[...codes[country]].map(c=>String.fromCodePoint(127397+c.charCodeAt(0))).join(''):'◎'}
function tileLayer(map,main=false){
 const config=data.map_config||{};
 if(config.url){const layer=L.tileLayer(config.url,{maxZoom:19,minZoom:1,attribution:config.attribution,crossOrigin:false});if(main){let failed=0;layer.on('tileerror',()=>{if(++failed>=3)$('#map-tile-notice')?.classList.remove('hidden')});layer.on('tileload',()=>{failed=0;$('#map-tile-notice')?.classList.add('hidden')})}layer.addTo(map);return layer}
 const attribution='© <a href="https://openfreemap.org" target="_blank" rel="noopener">OpenFreeMap</a> © <a href="https://openmaptiles.org/" target="_blank" rel="noopener">OpenMapTiles</a> Data from <a href="https://www.openstreetmap.org/copyright" target="_blank" rel="noopener">OpenStreetMap</a>';
 map.attributionControl.addAttribution(attribution);
 try{const layer=L.maplibreGL({style:'/english-map-style.json',attributionControl:false,interactive:false}).addTo(map);if(main){const gl=layer.getMaplibreMap();let failures=0;gl.on('error',()=>{if(++failures>=3)$('#map-tile-notice')?.classList.remove('hidden')});gl.on('idle',()=>{failures=0;$('#map-tile-notice')?.classList.add('hidden')})}return layer}catch(e){if(main)$('#map-tile-notice')?.classList.remove('hidden');return null}
}
function renderMaps(){
 if(!window.L)return;
 if($('#mini-world')&&!miniMap){
  miniMap=L.map('mini-world',{zoomControl:false,scrollWheelZoom:false,dragging:false,doubleClickZoom:false,touchZoom:false,boxZoom:false,keyboard:false,attributionControl:true,minZoom:1,maxZoom:5});
  miniMap.attributionControl.setPrefix(false);tileLayer(miniMap);const groups=destinationGroups(scope().filter(t=>t.start&&t.start<=today));
  groups.forEach(g=>L.circleMarker([g.lat,g.lon],{radius:3,color:'#fff',weight:1,fillColor:'#d65740',fillOpacity:1,interactive:false}).addTo(miniMap));
  if(groups.length)miniMap.fitBounds(groups.map(g=>[g.lat,g.lon]),{padding:[15,40],maxZoom:4});else miniMap.setView([30,10],2);
 }
 if($('#travel-map')&&!travelMap)createTravelMap();
}
function markerIcon(g,selected=false){const future=g.visits.every(t=>t.start>today);return L.divIcon({className:`destination-marker ${future?'planned':''} ${selected?'is-selected':''}`,html:'<span class="destination-marker-dot"></span>',iconSize:[26,26],iconAnchor:[13,13],tooltipAnchor:[0,-13]})}
function previewHtml(g){const n=g.visits.length,last=g.visits[0];return `<div class="map-hover-name">${esc(g.name)}</div><div class="map-hover-country">${esc(g.countries.join(' · '))}</div><div class="map-hover-date">${placeVisitLabel(g.visits)} · ${last.start>today?'Next':'Latest'} ${shortDate(last.start)}</div><div class="map-hover-hint">Click for a place overview</div>`}
function createTravelMap(){
 const map=L.map('travel-map',{zoomControl:false,scrollWheelZoom:true,wheelPxPerZoomLevel:90,zoomSnap:.5,zoomDelta:1,minZoom:1,maxZoom:19,worldCopyJump:true}).setView([35,5],2);travelMap=map;
 map.attributionControl.setPrefix(false);L.control.zoom({position:'bottomright'}).addTo(map);L.control.scale({imperial:false,position:'bottomleft',maxWidth:100}).addTo(map);tileLayer(map,true);
 travelGroups=destinationGroups(mapTrips());
 travelClusters=L.markerClusterGroup({maxClusterRadius:42,showCoverageOnHover:false,spiderfyOnMaxZoom:true,disableClusteringAtZoom:13,animate:!matchMedia('(prefers-reduced-motion: reduce)').matches,iconCreateFunction:cluster=>L.divIcon({html:`<span>${cluster.getChildCount()}</span>`,className:'destination-cluster',iconSize:[38,38]})});
 travelGroups.forEach(g=>{const marker=L.marker([g.lat,g.lon],{icon:markerIcon(g,g.key===travelSelection),keyboard:true,alt:g.name,riseOnHover:true});marker.destination=g;marker.bindTooltip(previewHtml(g),{className:'destination-tooltip',direction:'top',opacity:1,offset:[0,-1]});marker.on('click',()=>selectDestination(g.key));marker.on('add',()=>{const el=marker.getElement();if(el){el.setAttribute('aria-label',`${g.name}, ${g.countries.join(', ')}, ${placeVisitLabel(g.visits)}`);el.addEventListener('focus',()=>marker.openTooltip());el.addEventListener('blur',()=>marker.closeTooltip())}});travelMarkers.set(g.key,marker)});
 travelClusters.addTo(map);
 travelClusters.on('clustermouseover',e=>{const gs=e.layer.getAllChildMarkers().map(m=>m.destination);e.layer.bindTooltip(`<strong>${gs.length} places nearby</strong><div class="map-hover-country">${gs.slice(0,5).map(g=>esc(g.name)).join(' · ')}${gs.length>5?'…':''}</div><div class="map-hover-hint">Click to zoom in</div>`,{className:'destination-tooltip',direction:'top',opacity:1}).openTooltip()});
 travelClusters.on('clustermouseout',e=>e.layer.closeTooltip());
 const key=`${year}|${mapMode}|${selectedCountry}`;refreshDestinations(false);
 if(travelViewport&&key===travelScopeKey)map.setView(travelViewport.center,travelViewport.zoom,{animate:false});else fitDestinations(false);
 travelScopeKey=key;map.on('zoomend',updatePlaceLabels);map.on('click',closeDestinationDetails);
 $('#map-search').oninput=e=>{travelSearch=e.target.value;refreshDestinations(true)};
 $('#map-country').onchange=e=>chooseMapCountry(e.target.value);
 $('#place-labels').onchange=e=>{placeLabels=e.target.checked;updatePlaceLabels()};
 $('#map-fit').onclick=()=>fitDestinations(true);
 $('#map-fullscreen').onclick=async()=>{try{if(document.fullscreenElement)await document.exitFullscreen();else await $('.travel-layout').requestFullscreen()}catch{toast('Your browser could not expand the map')}};
 $('.travel-layout').onfullscreenchange=()=>setTimeout(()=>map.invalidateSize(),100);
 document.querySelectorAll('[data-map-region]').forEach(b=>b.onclick=()=>{if(b.dataset.mapRegion==='uk')map.flyToBounds([[49.8,-8.3],[59.2,2]],{padding:[30,30],duration:.6});else if(b.dataset.mapRegion==='europe')map.flyToBounds([[35,-13],[61,33]],{padding:[30,30],duration:.6});else fitDestinations(true)});
 document.querySelectorAll('.country-card').forEach(b=>b.onclick=()=>chooseMapCountry(b.dataset.country));
 if($('#map-clear-country'))$('#map-clear-country').onclick=()=>chooseMapCountry('');
 travelResizeObserver=new ResizeObserver(()=>map.invalidateSize({pan:false}));travelResizeObserver.observe($('#travel-map'));
 if(travelSelection&&visibleDestinations().some(g=>g.key===travelSelection))showDestinationDetails(travelSelection);else travelSelection='';
}
function visibleDestinations(){const q=travelSearch.toLowerCase().trim();return travelGroups.filter(g=>(!selectedCountry||g.countries.includes(selectedCountry))&&(!q||(g.name+' '+g.countries.join(' ')+' '+g.rows.map(t=>t.name).join(' ')).toLowerCase().includes(q)))}
function unmappedTrips(){const mapped=new Set(travelGroups.flatMap(g=>g.rows.map(t=>t.id))),q=travelSearch.toLowerCase().trim();return visits(mapTrips().filter(t=>!mapped.has(t.id)&&(!selectedCountry||countries(t).includes(selectedCountry))&&(!q||(t.name+' '+countries(t).join(' ')).toLowerCase().includes(q))))}
function refreshDestinations(fit=false){
 if(!travelMap)return;const groups=visibleDestinations(),missing=unmappedTrips();travelClusters.clearLayers();groups.forEach(g=>travelClusters.addLayer(travelMarkers.get(g.key)));
 $('#destination-list-title').textContent=selectedCountry||'Explore destinations';$('#destination-list-count').textContent=`${groups.length} mapped places${missing.length?` · ${missing.length} country-only trips`:''}`;
 $('#destination-list').innerHTML=groups.map(g=>`<button class="destination-row ${g.key===travelSelection?'chosen':''}" data-destination="${esc(g.key)}"><span class="destination-row-icon">${countryFlag(g.countries[0])}</span><span class="destination-row-copy"><strong>${esc(g.name)}</strong><small>${esc(g.countries.join(' · '))}</small><span>${placeVisitLabel(g.visits)} · ${shortDate(g.visits[0].start)}</span></span><span class="destination-row-arrow">↗</span></button>`).join('')+(missing.length?`<div class="country-only-heading">Country recorded · town to add</div>${missing.map(t=>`<button class="destination-row unplaced" data-unmapped-trip="${t.id}"><span class="destination-row-icon">${countryFlag(countries(t)[0])}</span><span class="destination-row-copy"><strong>${esc(t.name)}</strong><small>${esc(countries(t).join(' · '))}</small><span>${shortDate(t.start)} · place overview</span></span><span>↗</span></button>`).join('')}`:'')||'<div class="empty">No destinations match. Try another place or country.</div>';
 document.querySelectorAll('[data-destination]').forEach(b=>b.onclick=()=>selectDestination(b.dataset.destination,true));document.querySelectorAll('[data-unmapped-trip]').forEach(b=>b.onclick=()=>openUnmappedPlace(data.trips.find(t=>t.id===+b.dataset.unmappedTrip)));
 if(travelSelection&&!groups.some(g=>g.key===travelSelection)){travelSelection='';$('#destination-details').innerHTML=''}
 if(fit)fitDestinations(true);updatePlaceLabels();
}
function fitDestinations(animate=true){if(!travelMap)return;const gs=visibleDestinations();if(gs.length)travelMap.fitBounds(gs.map(g=>[g.lat,g.lon]),{padding:[45,55],maxZoom:gs.length===1?10:7,animate,duration:.5});else{const feature=(world?.features||[]).find(f=>f.properties.ADMIN===selectedCountry);if(feature)travelMap.fitBounds(L.geoJSON(feature).getBounds(),{padding:[35,35],maxZoom:7,animate});else travelMap.setView([32,5],2,{animate})}}
function chooseMapCountry(country){selectedCountry=country;travelSelection='';travelSearch='';travelViewport=null;render()}
function selectDestination(key,focus=false){
 const g=travelGroups.find(g=>g.key===key);if(!g||!travelMap)return;travelSelection=key;
 travelMarkers.forEach((marker,k)=>marker.setIcon(markerIcon(marker.destination,k===key)));
 document.querySelectorAll('[data-destination]').forEach(b=>b.classList.toggle('chosen',b.dataset.destination===key));showDestinationDetails(key);
 const marker=travelMarkers.get(key);if(focus){travelMap.setView(marker.getLatLng(),Math.max(9,travelMap.getZoom()),{animate:true});travelClusters.zoomToShowLayer(marker,()=>marker.openTooltip())}else marker.openTooltip();
}
function closeDestinationDetails(){
 travelSelection='';if($('#destination-details'))$('#destination-details').innerHTML='';travelMarkers.forEach(m=>{m.setIcon(markerIcon(m.destination));m.closeTooltip()});document.querySelectorAll('.destination-row.chosen').forEach(b=>b.classList.remove('chosen'));
 if(travelMap)travelMap.closePopup();
}
function openUnmappedPlace(t){
 const rows=mapTrips().filter(r=>r.name===t.name&&countries(r).join(',')===countries(t).join(','));
 const g={key:'unmapped:'+t.name,name:t.name,countries:countries(t),rows,visits:visits(rows).sort((a,b)=>b.start.localeCompare(a.start)),lat:null,lon:null};travelSelection=g.key;showDestinationDetails(g.key,g);
}
function showDestinationDetails(key,provided=null){
 const g=provided||travelGroups.find(g=>g.key===key);if(!g)return;const rows=g.visits;
 $('#destination-details').innerHTML=`<div class="destination-detail-card"><button id="destination-back" class="place-panel-back">← Destinations</button><button id="destination-close" class="destination-close" aria-label="Close place overview">×</button><div class="place-overview-country">${countryFlag(g.countries[0])} ${esc(g.countries.join(' · '))}</div><h2>${esc(g.name)}</h2><div class="wiki-overview" id="wiki-overview" aria-live="polite"><div class="wiki-loading"><span></span><span></span><span></span><small>Loading place overview…</small></div></div><details class="place-visit-history"><summary>Your visits <span>${placeVisitLabel(rows)}</span></summary><div class="destination-visits">${rows.map(t=>`<div class="destination-visit"><span><strong>${esc(t.name)}</strong><small>${shortDate(t.start)} → ${shortDate(t.end)}</small></span><button data-visit-trip="${t.id}" class="text-link">Edit trip</button></div>`).join('')}</div></details></div>`;
 document.querySelectorAll('[data-visit-trip]').forEach(b=>b.onclick=()=>edit('trips',+b.dataset.visitTrip));$('#destination-close').onclick=closeDestinationDetails;$('#destination-back').onclick=closeDestinationDetails;
 loadPlaceOverview(g,key);
}
async function loadPlaceOverview(g,key){
 const query=new URLSearchParams({name:g.name,country:g.countries.join(', ')});if(g.lat!=null){query.set('lat',g.lat);query.set('lon',g.lon)}
 try{const info=await api('/api/place?'+query);if(travelSelection!==key||!$('#wiki-overview'))return;
  $('#wiki-overview').innerHTML=info.available?`${info.image?`<figure class="wiki-place-image"><img src="${esc(info.image.url)}" alt="${esc(info.title)}" loading="lazy"><figcaption><a href="${esc(info.image.source)}" target="_blank" rel="noopener">${esc(info.image.artist)} · ${esc(info.image.license)}</a></figcaption></figure>`:''}${info.description?`<p class="wiki-description">${esc(info.description)}</p>`:''}${info.title.toLowerCase()!==g.name.toLowerCase()?`<small class="wiki-article-title">About ${esc(info.title)}</small>`:''}<p class="wiki-extract">${esc(info.extract)}</p><div class="wiki-source"><a href="${esc(info.url)}" target="_blank" rel="noopener">Read on Wikipedia ↗</a><a href="${esc(info.license_url)}" target="_blank" rel="noopener">${esc(info.license)}</a></div>`:`<p class="wiki-extract">No reliable overview was found for this place.</p><a class="wiki-link" href="${esc(info.url)}" target="_blank" rel="noopener">Search Wikipedia ↗</a>`;
  const image=$('#wiki-overview img');if(image)image.onerror=()=>image.closest('figure').remove();
 }catch(e){if(travelSelection!==key||!$('#wiki-overview'))return;$('#wiki-overview').innerHTML=`<p class="wiki-extract">The place overview is unavailable right now.</p><a class="wiki-link" href="https://en.wikipedia.org/wiki/Special:Search?search=${encodeURIComponent(g.name+' '+g.countries.join(' '))}" target="_blank" rel="noopener">Find it on Wikipedia ↗</a>`}
}
function updatePlaceLabels(){if(!travelMap)return;travelMarkers.forEach(marker=>{const g=marker.destination,permanent=placeLabels&&travelMap.getZoom()>=6,tooltip=marker.getTooltip();if(tooltip&&!!tooltip.options.permanent===permanent)return;marker.unbindTooltip();marker.bindTooltip(permanent?esc(g.name):previewHtml(g),{permanent,className:permanent?'destination-name-label':'destination-tooltip',direction:'top',opacity:1,offset:[0,-1]})})}
function pinPicker(){
 const box=$('#pin-picker');if(!box.classList.contains('hidden')){if(pickerMap){pickerMap.remove();pickerMap=null}box.classList.add('hidden');return}
 box.classList.remove('hidden');box.innerHTML='<div id="picker-map" style="height:300px"></div><div class="manual-pin-controls"><p>Click the map to choose a location.</p><label>Place name<input id="manual-pin-name" placeholder="Name this place"></label><button type="button" id="manual-pin-add" disabled>Add selected place</button></div>'; 
 if(pickerMap){pickerMap.remove();pickerMap=null}
 const latInput=$('#fields [name="lat"]'),lonInput=$('#fields [name="lon"]'),hasPin=latInput.value!==''&&lonInput.value!=='';pickerMap=L.map('picker-map',{minZoom:1,maxZoom:19});pickerMap.attributionControl.setPrefix(false);tileLayer(pickerMap);
 const chooseIcon=L.divIcon({className:'destination-marker is-selected',html:'<span class="destination-marker-dot"></span>',iconSize:[26,26],iconAnchor:[13,13]});let pin;
 if(hasPin){const ll=[+latInput.value,+lonInput.value];pickerMap.setView(ll,9);pin=L.marker(ll,{icon:chooseIcon}).addTo(pickerMap)}else{const c=$('#fields [name="country"]').value.split(',')[0].trim(),feature=(world?.features||[]).find(f=>f.properties.ADMIN.toLowerCase()===c.toLowerCase());if(feature)pickerMap.fitBounds(L.geoJSON(feature).getBounds(),{maxZoom:7});else pickerMap.setView([45,5],3)}
 pickerMap.on('click',e=>{latInput.value=e.latlng.lat.toFixed(5);lonInput.value=e.latlng.lng.toFixed(5);if(pin)pin.setLatLng(e.latlng);else pin=L.marker(e.latlng,{icon:chooseIcon}).addTo(pickerMap);$('#manual-pin-add').disabled=false});
 $('#manual-pin-add').onclick=()=>{const name=$('#manual-pin-name').value.trim();if(!name){$('#manual-pin-name').focus();return}addEditorPlace({name,lat:+latInput.value,lon:+lonInput.value});latInput.value='';lonInput.value='';$('#manual-pin-name').value='';$('#manual-pin-add').disabled=true;if(pin){pickerMap.removeLayer(pin);pin=null}};
}
