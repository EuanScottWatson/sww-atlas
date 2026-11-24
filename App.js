import React, { useCallback, useEffect, useMemo, useState } from 'react';
import { ActivityIndicator, Alert, KeyboardAvoidingView, Platform, Pressable, SafeAreaView, ScrollView, StyleSheet, Text, TextInput, View } from 'react-native';
import AsyncStorage from '@react-native-async-storage/async-storage';
import MapView, { Marker } from 'react-native-maps';
import { StatusBar } from 'expo-status-bar';

const DEFAULT_SERVER = 'http://192.168.32.48:7780';
const fields = [
  ['name', 'Trip name'], ['country', 'Country'], ['start', 'Start date (YYYY-MM-DD)'], ['end', 'End date (YYYY-MM-DD)'], ['year', 'Allocation year'],
  ['travel', 'Travel cost (£)'], ['accommodation', 'Accommodation cost (£)'], ['total', 'Total cost (£)'],
  ['flights', 'Flights'], ['days', 'Days recorded'], ['leave', 'Leave days'], ['notes', 'Notes'],
];
const numeric = new Set(['travel', 'accommodation', 'total', 'flights', 'days', 'leave', 'year']);
const dateLabel = value => value ? new Date(`${value}T12:00:00`).toLocaleDateString('en-GB', { day: 'numeric', month: 'short', year: 'numeric' }) : 'Date not set';
const dateRange = trip => trip.start ? `${dateLabel(trip.start)}${trip.end && trip.end !== trip.start ? ` – ${dateLabel(trip.end)}` : ''}` : 'Dates not set';

async function request(server, path, body) {
  const response = await fetch(`${server}${path}`, body ? { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body) } : undefined);
  const result = await response.json();
  if (!response.ok) throw new Error(result.error || 'The server could not complete the request.');
  return result;
}

function Action({ title, onPress, secondary = false, disabled = false }) {
  return <Pressable accessibilityRole="button" disabled={disabled} onPress={onPress} style={[styles.button, secondary && styles.secondaryButton, disabled && styles.disabled]}><Text style={[styles.buttonText, secondary && styles.secondaryText]}>{title}</Text></Pressable>;
}

export default function App() {
  const [server, setServer] = useState(DEFAULT_SERVER);
  const [serverInput, setServerInput] = useState(DEFAULT_SERVER);
  const [trips, setTrips] = useState([]);
  const [tab, setTab] = useState('Home');
  const [selected, setSelected] = useState(null);
  const [draft, setDraft] = useState(null);
  const [search, setSearch] = useState('');
  const [placeQuery, setPlaceQuery] = useState('');
  const [placeResults, setPlaceResults] = useState([]);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState('');

  const load = useCallback(async address => {
    setLoading(true); setError('');
    try { const data = await request(address, '/api/data'); setTrips((data.trips || []).map(t => ({ ...(data.places?.[t.name] || {}), ...t })));  }
    catch (e) { setError(`Could not connect to the server: ${e.message}`); }
    finally { setLoading(false); }
  }, []);
  useEffect(() => { (async () => { const saved = await AsyncStorage.getItem('atlas-server'); const address = saved || DEFAULT_SERVER; setServer(address); setServerInput(address); await load(address); })().catch(e => { setError(e.message); setLoading(false); }); }, [load]);
  const sorted = useMemo(() => [...trips].sort((a, b) => (b.start || '').localeCompare(a.start || '')), [trips]);
  const filtered = useMemo(() => sorted.filter(t => `${t.name} ${t.country || ''} ${t.year || ''}`.toLowerCase().includes(search.toLowerCase())), [sorted, search]);
  const now = new Date();
  const today = [now.getFullYear(), String(now.getMonth() + 1).padStart(2, '0'), String(now.getDate()).padStart(2, '0')].join('-');
  const next = [...sorted].reverse().find(t => t.start && t.start >= today);
  const countries = new Set(trips.filter(t => t.start && t.country).map(t => t.country.trim().toLowerCase())).size;
  const pins = trips.flatMap(t => (t.pins?.length ? t.pins : t.lat != null && t.lon != null ? [{ name: t.name, lat: t.lat, lon: t.lon }] : []).filter(p => Number.isFinite(Number(p.lat)) && Number.isFinite(Number(p.lon))).map(p => ({ ...p, trip: t })));

  const save = async () => {
    if (!draft.name?.trim() || (!draft.year && !draft.start)) { Alert.alert('Missing details', 'Add a name and an allocation year or start date.'); return; }
    const record = { ...draft, year: draft.year || draft.start.slice(0, 4) };
    for (const key of numeric) record[key] = record[key] === '' || record[key] == null ? null : Number(record[key]);
    if ([...numeric].some(key => record[key] != null && (!Number.isFinite(record[key]) || record[key] < 0))) { Alert.alert('Check the numbers', 'Enter positive numbers for costs and counts.'); return; }
    if (!draft.id && record.total == null && (record.travel != null || record.accommodation != null)) record.total = (record.travel || 0) + (record.accommodation || 0);
    setSaving(true);
    try { const saved = await request(server, '/api/save', { kind: 'trips', id: draft.id || null, record }); setDraft(null); setSelected(saved); await load(server); }
    catch (e) { Alert.alert('Could not save trip', e.message); }
    finally { setSaving(false); }
  };
  const showTrip = trip => { setSelected(trip); setDraft(null); };
  const nav = name => { const go = () => { setTab(name); setSelected(null); setDraft(null); setPlaceResults([]); }; if (draft) Alert.alert('Discard changes?', 'Your unsaved changes will be lost.', [{ text: 'Keep editing', style: 'cancel' }, { text: 'Discard', style: 'destructive', onPress: go }]); else go(); };
  const closeDraft = () => Alert.alert('Discard changes?', 'Your unsaved changes will be lost.', [{ text: 'Keep editing', style: 'cancel' }, { text: 'Discard', style: 'destructive', onPress: () => setDraft(null) }]);
  const tripRow = trip => <Pressable key={trip.id} style={styles.tripRow} onPress={() => showTrip(trip)} accessibilityRole="button"><View style={styles.rowContent}><Text style={styles.tripName}>{trip.name}</Text><Text style={styles.muted}>{[trip.country, dateRange(trip)].filter(Boolean).join('  ·  ')}</Text></View><Text style={styles.chevron}>›</Text></Pressable>;
  return <SafeAreaView style={styles.safe}><StatusBar style="dark"/><KeyboardAvoidingView behavior={Platform.OS === 'ios' ? 'padding' : undefined} style={styles.flex}>
    <View style={styles.header}><Pressable onPress={() => { if (draft) closeDraft(); else setSelected(null); }}><Text style={styles.eyebrow}>{selected || draft ? '‹  BACK' : 'PERSONAL TRAVEL JOURNAL'}</Text></Pressable><Text style={styles.title}>{draft ? (draft.id ? 'Edit trip' : 'New trip') : selected ? selected.name : tab === 'Home' ? 'The SWW Atlas' : tab}</Text></View>
    {loading && !trips.length ? <ActivityIndicator style={styles.loading} color="#315c49"/> : <ScrollView keyboardShouldPersistTaps="handled" contentContainerStyle={styles.content}>
      {!!error && <View style={styles.notice}><Text style={styles.error}>{error}</Text><Action title="Try again" secondary onPress={() => load(server)}/></View>}
      {draft ? <><Text style={styles.intro}>Details are saved to your travel server.</Text>{fields.map(([key, label]) => <View key={key} style={styles.field}><Text style={styles.label}>{label}</Text><TextInput value={String(draft[key] ?? '')} onChangeText={value => setDraft({ ...draft, [key]: value })} placeholder={key === 'start' || key === 'end' ? 'YYYY-MM-DD' : ''} keyboardType={numeric.has(key) ? 'decimal-pad' : 'default'} multiline={key === 'notes'} style={[styles.input, key === 'notes' && styles.notes]} /></View>)}<Text style={styles.section}>PLACES</Text><Text style={styles.muted}>Search for a place to add it to the map. Existing places are kept.</Text><TextInput value={placeQuery} onChangeText={setPlaceQuery} placeholder="Search for a place" style={styles.input}/><Action title="Search places" secondary onPress={async () => { try { setPlaceResults(await request(server, `/api/place-search?q=${encodeURIComponent(placeQuery)}`)); } catch (e) { Alert.alert('Place search', e.message); } }}/>{placeResults.map((p, i) => <Pressable key={`${p.name}-${i}`} style={styles.tripRow} onPress={() => { setDraft({ ...draft, country: draft.country || p.country, pins: [...(draft.pins || []), { name: p.name, lat: p.lat, lon: p.lon }] }); setPlaceResults([]); setPlaceQuery(''); }}><Text style={styles.body}>{p.display}</Text></Pressable>)}{(draft.pins || []).map((p, i) => <View key={`${p.name}-${i}`} style={styles.detailRow}><Text style={styles.body}>{p.name}</Text><Pressable onPress={() => setDraft({ ...draft, pins: draft.pins.filter((_, index) => index !== i) })}><Text style={styles.link}>Remove</Text></Pressable></View>)}<Action title={saving ? 'Saving…' : 'Save trip'} disabled={saving} onPress={save}/><Action title="Cancel" secondary onPress={closeDraft}/></> : selected ? <><Text style={styles.intro}>{selected.country || 'A journey in your atlas'}</Text><Text style={styles.detailDate}>{dateRange(selected)}</Text><View style={styles.rule}/>{[['Travel', selected.travel], ['Accommodation', selected.accommodation], ['Total', selected.total], ['Flights', selected.flights], ['Days', selected.days], ['Leave', selected.leave]].filter(([, v]) => v != null).map(([label, value]) => <View style={styles.detailRow} key={label}><Text style={styles.muted}>{label}</Text><Text style={styles.value}>{['Travel', 'Accommodation', 'Total'].includes(label) ? `£${Number(value).toFixed(2)}` : value}</Text></View>)}{!!selected.notes && <><Text style={styles.section}>Notes</Text><Text style={styles.body}>{selected.notes}</Text></>}<View style={styles.spacer}/><Action title="Edit trip" onPress={() => setDraft({ ...selected })}/></> : tab === 'Settings' ? <><Text style={styles.intro}>Connect to your private travel server.</Text><Text style={styles.label}>SERVER ADDRESS</Text><TextInput autoCapitalize="none" autoCorrect={false} keyboardType="url" value={serverInput} onChangeText={setServerInput} style={styles.input}/><Action title="Save and connect" onPress={async () => { const address = serverInput.trim().replace(/\/+$/, ''); if (!/^https?:\/\//i.test(address)) { Alert.alert('Invalid address', 'Enter an address beginning with http:// or https://.'); return; } try { await AsyncStorage.setItem('atlas-server', address); setServer(address); await load(address); } catch (e) { Alert.alert('Could not save address', e.message); } }}/><Text style={styles.muted}>Use your home network or Tailscale. Your server has no sign-in and should remain private.</Text></> : tab === 'Map' ? <><Text style={styles.intro}>Places from your recorded trips.</Text><MapView style={styles.map} initialRegion={{ latitude: 48, longitude: 4, latitudeDelta: 45, longitudeDelta: 50 }}>{pins.map((p, i) => <Marker key={`${p.trip.id}-${i}`} coordinate={{ latitude: Number(p.lat), longitude: Number(p.lon) }} title={p.name} description={p.trip.name} onCalloutPress={() => showTrip(p.trip)}/>)}</MapView><Text style={styles.muted}>Tap a pin, then its label, to open the trip. Only trips with recorded coordinates appear.</Text></> : tab === 'Trips' ? <><TextInput placeholder="Search trips, countries or years" value={search} onChangeText={setSearch} style={styles.input}/><Action title="＋  Add trip" onPress={() => setDraft({ name: '', start: '', end: '', country: '', notes: '' })}/><Text style={styles.section}>{filtered.length} TRIPS</Text>{filtered.map(tripRow)}{!filtered.length && <Text style={styles.muted}>No trips found.</Text>}</> : <><Text style={styles.intro}>A record of the places you’ve been, and the journeys still to come.</Text><View style={styles.stats}><View><Text style={styles.statNumber}>{trips.length}</Text><Text style={styles.statLabel}>TRIP RECORDS</Text></View><View><Text style={styles.statNumber}>{countries}</Text><Text style={styles.statLabel}>COUNTRIES RECORDED</Text></View></View><Text style={styles.section}>NEXT JOURNEY</Text>{next ? tripRow(next) : <Text style={styles.muted}>No upcoming trips recorded.</Text>}<View style={styles.sectionRow}><Text style={styles.section}>RECENT JOURNEYS</Text><Pressable onPress={() => nav('Trips')}><Text style={styles.link}>View all →</Text></Pressable></View>{sorted.filter(t => t.start && t.start < today).slice(0, 4).map(tripRow)}<View style={styles.spacer}/><Action title="＋  Add a trip" onPress={() => setDraft({ name: '', start: '', end: '', country: '', notes: '' })}/></>}
    </ScrollView>}
    <View style={styles.tabs}>{['Home', 'Trips', 'Map', 'Settings'].map(name => <Pressable key={name} accessibilityRole="tab" accessibilityState={{ selected: tab === name && !selected && !draft }} style={styles.tab} onPress={() => nav(name)}><Text style={[styles.tabText, tab === name && styles.activeTab]}>{name}</Text></Pressable>)}</View>
  </KeyboardAvoidingView></SafeAreaView>;
}
const styles = StyleSheet.create({
  safe:{flex:1,backgroundColor:'#f7f5ee'},flex:{flex:1},header:{paddingHorizontal:24,paddingTop:18,paddingBottom:15,borderBottomWidth:1,borderColor:'#e0e4d9'},eyebrow:{fontSize:10,letterSpacing:2,color:'#52725e',fontWeight:'700',marginBottom:8},title:{fontSize:32,fontFamily:Platform.OS === 'ios' ? 'Georgia' : 'serif',color:'#203e31'},content:{padding:24,paddingBottom:40},intro:{fontSize:16,lineHeight:24,color:'#66776b',marginBottom:24},stats:{flexDirection:'row',gap:48,paddingVertical:22,borderTopWidth:1,borderBottomWidth:1,borderColor:'#dce3d9'},statNumber:{fontSize:30,color:'#244d3b',fontFamily:Platform.OS === 'ios' ? 'Georgia' : 'serif'},statLabel:{fontSize:10,letterSpacing:1,color:'#728478',marginTop:5},section:{fontSize:11,letterSpacing:1.5,fontWeight:'700',color:'#597463',marginTop:30,marginBottom:12},sectionRow:{flexDirection:'row',alignItems:'baseline',justifyContent:'space-between'},link:{color:'#436c56',fontWeight:'600'},tripRow:{flexDirection:'row',alignItems:'center',paddingVertical:16,borderBottomWidth:1,borderColor:'#e2e6dc'},rowContent:{flex:1},tripName:{fontSize:18,color:'#243c31',fontWeight:'600',marginBottom:6},muted:{fontSize:13,lineHeight:20,color:'#78877b'},chevron:{fontSize:26,color:'#8fa194'},button:{backgroundColor:'#315c49',padding:16,alignItems:'center',borderRadius:8,marginVertical:8},buttonText:{color:'#fff',fontWeight:'700',fontSize:15},secondaryButton:{backgroundColor:'transparent',borderColor:'#a6b7a9',borderWidth:1},secondaryText:{color:'#315c49'},disabled:{opacity:0.5},field:{marginBottom:16},label:{fontSize:12,fontWeight:'700',color:'#536d5b',marginBottom:8},input:{borderWidth:1,borderColor:'#ced9cc',backgroundColor:'#fffefb',borderRadius:8,paddingHorizontal:14,paddingVertical:13,fontSize:16,color:'#203e31',marginBottom:10},notes:{minHeight:110,textAlignVertical:'top'},detailDate:{fontSize:17,color:'#355844'},detailRow:{flexDirection:'row',justifyContent:'space-between',paddingVertical:12,borderBottomWidth:1,borderColor:'#e2e6dc'},value:{fontSize:15,color:'#233c30',fontWeight:'600'},body:{fontSize:15,lineHeight:23,color:'#334d3e'},rule:{height:1,backgroundColor:'#dce3d9',marginVertical:20},spacer:{height:24},map:{height:450,borderRadius:8,marginBottom:14},tabs:{flexDirection:'row',borderTopWidth:1,borderColor:'#dce3d9',backgroundColor:'#f7f5ee'},tab:{flex:1,alignItems:'center',paddingVertical:16},tabText:{fontSize:12,color:'#87978b'},activeTab:{color:'#244d3b',fontWeight:'700'},loading:{flex:1},notice:{padding:14,backgroundColor:'#f8e9df',borderRadius:8,marginBottom:20},error:{color:'#883e2c',lineHeight:20}
});
