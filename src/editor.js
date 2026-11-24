import React, { useState } from 'react';
import { Alert, Pressable, Text, View } from 'react-native';
import MapView, { Marker } from 'react-native-maps';
import { colors, styles } from './theme';
import { Button, Chip, Field, Heading, Notice, shortDate } from './ui';
const {
  placeFor,
  sharedField
} = require('./domain');
const numeric = ['travel', 'accommodation', 'total', 'flights', 'days', 'leave'];
const regions = ['UK', 'Europe', 'Africa', 'North America', 'South America', 'Asia', 'Oceania'];
function inputDate(value) {
  return value ? shortDate(value) : '';
}
function isoDate(value) {
  if (!value) return null;
  const m = String(value).trim().match(/^(\d{1,2})\/(\d{1,2})\/(\d{4})$/);
  if (!m) throw Error('Enter dates as DD/MM/YYYY.');
  const d = Number(m[1]),
    month = Number(m[2]),
    y = Number(m[3]),
    dt = new Date(Date.UTC(y, month - 1, d));
  if (dt.getUTCFullYear() !== y || dt.getUTCMonth() !== month - 1 || dt.getUTCDate() !== d) throw Error('Enter a valid date.');
  return `${y}-${String(month).padStart(2, '0')}-${String(d).padStart(2, '0')}`;
}
function formatDraft(record) {
  return {
    ...record,
    start: inputDate(record.start),
    end: inputDate(record.end)
  };
}
export function RecordEditor({
  kind,
  record,
  initialDate,
  data,
  api,
  onSave,
  onCancel,
  saving
}) {
  const isTrip = kind === 'trips',
    original = record || {},
    p = isTrip ? placeFor(data, original) : {},
    [draft, setDraft] = useState(() => formatDraft({
      ...original,
      start: original.start || initialDate || null,
      end: original.end || initialDate || null,
      country: original.country ?? p.country ?? ''
    })),
    [places, setPlaces] = useState(() => p.pins?.map(pin => ({
      ...pin
    })) || (p.lat != null && p.lon != null ? [{
      name: p.label || original.name,
      lat: p.lat,
      lon: p.lon
    }] : [])),
    [placesChanged, setPlacesChanged] = useState(false),
    [query, setQuery] = useState(''),
    [results, setResults] = useState([]),
    [placeName, setPlaceName] = useState(''),
    [coordinate, setCoordinate] = useState(null),
    [showMap, setShowMap] = useState(false),
    [error, setError] = useState('');
  const update = (key, value) => setDraft(d => ({
    ...d,
    [key]: value
  }));
  async function findPlaces() {
    try {
      if (query.trim().length < 2) throw Error('Enter at least two characters.');
      setResults(await api(`/api/place-search?q=${encodeURIComponent(query.trim())}`));
    } catch (e) {
      Alert.alert('Place search', e.message);
    }
  }
  function addPlace(pin) {
    if (places.some(p => Math.abs(Number(p.lat) - Number(pin.lat)) < .0001 && Math.abs(Number(p.lon) - Number(pin.lon)) < .0001)) return;
    setPlaces([...places, {
      name: pin.name,
      lat: Number(pin.lat),
      lon: Number(pin.lon)
    }]);
    setPlacesChanged(true);
    if (pin.country && !draft.country) update('country', pin.country);
    setResults([]);
    setQuery('');
  }
  function submit() {
    try {
      if (!draft.name?.trim()) throw Error('Enter a name.');
      const start = isoDate(draft.start),
        end = isoDate(draft.end);
      if (start && end && end < start) throw Error('End date must be on or after start date.');
      if (!isTrip && (!start || !end)) throw Error('Enter a start and end date.');
      const r = {
        ...draft,
        name: draft.name.trim(),
        start,
        end
      };
      if (isTrip) {
        r.year = Number(draft.year || start?.slice(0, 4));
        if (!Number.isInteger(r.year) || r.year < 1900 || r.year > 2200) throw Error('Enter a valid allocation year.');
        for (const k of numeric) {
          r[k] = draft[k] === '' || draft[k] == null ? null : Number(draft[k]);
          if (r[k] != null && (!Number.isFinite(r[k]) || r[k] < 0)) throw Error('Costs and counts must be positive numbers.');
        }
        const costsChanged = Number(r.travel || 0) !== Number(original.travel || 0) || Number(r.accommodation || 0) !== Number(original.accommodation || 0);
        const totalChanged = String(draft.total ?? '') !== String(original.total ?? '');
        if (!record && r.total == null || record && costsChanged && !totalChanged && !sharedField(original, 'total', data.trips || [])) r.total = Math.round(((r.travel || 0) + (r.accommodation || 0)) * 100) / 100;
        if (record && (start !== original.start || end !== original.end)) r.calendar_confirmed = true;
        if (placesChanged) {
          r.pins = places;
          r.locations = places.map(p => p.name).join('; ');
          r.lat = null;
          r.lon = null;
        }
      }
      setError('');
      onSave(kind, r, record?.id);
    } catch (e) {
      setError(e.message);
    }
  }
  return <><Heading title={record ? 'Edit entry' : isTrip ? 'Add trip' : 'Add event'} subtitle="Dates use DD/MM/YYYY" /><Field label={isTrip ? 'Destination' : 'Event name'} value={draft.name} onChangeText={v => update('name', v)} />{isTrip && <Field label="Country or countries" value={draft.country} onChangeText={v => update('country', v)} />}<View style={styles.inline}><View style={styles.half}><Field label="Start date" value={draft.start} placeholder="DD/MM/YYYY" onChangeText={v => update('start', v)} /></View><View style={styles.half}><Field label="End date" value={draft.end} placeholder="DD/MM/YYYY" onChangeText={v => update('end', v)} /></View></View>{isTrip && <><Field label="Allocation year" numeric value={draft.year} placeholder="Defaults to start year" onChangeText={v => update('year', v)} /><Text style={styles.label}>Region</Text><View style={styles.chips}>{regions.map(r => <Chip key={r} title={r} active={(draft.region || 'Europe') === r} onPress={() => update('region', r)} />)}</View><View style={styles.inline}><View style={styles.half}><Field label="Travel (£)" numeric value={draft.travel} onChangeText={v => update('travel', v)} /></View><View style={styles.half}><Field label="Accommodation (£)" numeric value={draft.accommodation} onChangeText={v => update('accommodation', v)} /></View></View><Field label="Recorded total (£)" numeric value={draft.total} placeholder="Calculated for new trips if blank" onChangeText={v => update('total', v)} /><View style={styles.inline}><View style={styles.half}><Field label="Flights" numeric value={draft.flights} onChangeText={v => update('flights', v)} /></View><View style={styles.half}><Field label="Leave days" numeric value={draft.leave} onChangeText={v => update('leave', v)} /></View></View><Field label="Recorded days" numeric value={draft.days} onChangeText={v => update('days', v)} /><Text style={styles.section}>Journey</Text><Text style={styles.tiny}>Link this trip to an existing journey, or leave it standalone.</Text><View style={styles.chips}><Chip title="Standalone" active={!draft.group} onPress={() => setDraft(d => ({
          ...d,
          group: '',
          journey_name: '',
          shared_fields: []
        }))} />{[...new Map((data.trips || []).filter(t => t.group).map(t => [t.group, t])).values()].map(t => <Chip key={t.group} title={t.journey_name || t.group} active={draft.group === t.group} onPress={() => setDraft(d => ({
          ...d,
          group: t.group,
          journey_name: t.journey_name || '',
          shared_fields: d.group === t.group ? d.shared_fields || [] : []
        }))} />)}</View>{!!draft.group && <><Text style={styles.label}>Stop type</Text><View style={styles.chips}><Chip title="Stay" active={draft.trip_role !== 'day-trip'} onPress={() => update('trip_role', 'stop')} /><Chip title="Day trip" active={draft.trip_role === 'day-trip'} onPress={() => update('trip_role', 'day-trip')} /></View><Text style={styles.label}>Fields shared across the journey</Text><View style={styles.chips}>{['travel', 'flights'].map(k => <Chip key={k} title={k} active={(draft.shared_fields || []).includes(k)} onPress={() => update('shared_fields', (draft.shared_fields || []).includes(k) ? draft.shared_fields.filter(x => x !== k) : [...(draft.shared_fields || []), k])} />)}</View></>}<Text style={styles.section}>Places</Text><Field label="Find a place" value={query} onChangeText={setQuery} /><Button title="Search places" kind="secondary" onPress={findPlaces} />{results.map((r, i) => <Pressable key={`${r.name}${i}`} style={styles.row} onPress={() => addPlace(r)}><View style={styles.rowMain}><Text style={styles.rowTitle}>{r.name}</Text><Text style={styles.tiny}>{r.display}</Text></View><Text style={styles.link}>＋</Text></Pressable>)}{places.map((pin, i) => <View key={`${pin.name}${i}`} style={styles.detail}><Text style={styles.body}>{pin.name}</Text><Pressable onPress={() => {
          setPlaces(places.filter((_, index) => index !== i));
          setPlacesChanged(true);
        }}><Text style={styles.link}>Remove</Text></Pressable></View>)}<View style={styles.spacer} /><Button title={showMap ? 'Close map' : 'Choose a pin on the map'} kind="secondary" onPress={() => setShowMap(!showMap)} />{showMap && <><View style={styles.spacer} /><MapView style={styles.map} initialRegion={{
          latitude: 51,
          longitude: 0,
          latitudeDelta: 30,
          longitudeDelta: 30
        }} onPress={e => setCoordinate(e.nativeEvent.coordinate)}>{coordinate && <Marker coordinate={coordinate} />}</MapView><Text style={styles.muted}>Tap the map, then name the place.</Text><Field label="Place name" value={placeName} onChangeText={setPlaceName} /><Button title="Add selected pin" kind="secondary" onPress={() => {
          if (!coordinate || !placeName.trim()) {
            Alert.alert('Choose a place', 'Tap the map and enter a name.');
            return;
          }
          addPlace({
            name: placeName.trim(),
            lat: coordinate.latitude,
            lon: coordinate.longitude
          });
          setShowMap(false);
          setPlaceName('');
          setCoordinate(null);
        }} /></>}<View style={styles.spacer} /><Text style={styles.label}>Review status</Text><View style={styles.chips}><Chip title={draft.review ? 'Needs review' : 'Reviewed'} active={!!draft.review} onPress={() => update('review', !draft.review)} /></View></>}{!isTrip && <><Text style={styles.label}>Event type</Text><View style={styles.chips}><Chip title="Personal event" active={(draft.kind || 'event') === 'event'} onPress={() => update('kind', 'event')} /><Chip title="Calendar context" active={draft.kind === 'context'} onPress={() => update('kind', 'context')} /></View></>}<Field label="Notes" multiline value={draft.notes} onChangeText={v => update('notes', v)} />{!!error && <Text accessibilityRole="alert" style={styles.error}>{error}</Text>}<View style={styles.spacer} /><Button title={saving ? 'Saving…' : 'Save'} disabled={saving} onPress={submit} /><View style={styles.spacer} /><Button title="Cancel" kind="secondary" onPress={onCancel} /></>;
}
function blankStop() {
  return {
    name: '',
    country: '',
    start: '',
    end: '',
    accommodation: '',
    region: 'Europe'
  };
}
export function JourneyEditor({
  onSave,
  onCancel,
  saving
}) {
  const [name, setName] = useState(''),
    [travel, setTravel] = useState(''),
    [flights, setFlights] = useState(''),
    [leave, setLeave] = useState(''),
    [stops, setStops] = useState([blankStop(), blankStop()]),
    [error, setError] = useState('');
  const change = (i, key, v) => setStops(s => s.map((item, index) => index === i ? {
    ...item,
    [key]: v
  } : item));
  function submit() {
    try {
      if (!name.trim()) throw Error('Enter a journey name.');
      if (stops.length < 2) throw Error('Add at least two stops.');
      const group = `journey-${Date.now().toString(36)}-${Math.random().toString(36).slice(2, 12)}`;
      for (const n of [travel, flights, leave, ...stops.map(s => s.accommodation)]) if (n !== '' && (!Number.isFinite(Number(n)) || Number(n) < 0)) throw Error('Costs and counts must be positive numbers.');
      const records = stops.map((s, i) => {
        const start = isoDate(s.start),
          end = isoDate(s.end);
        if (!s.name.trim() || !start || !end || end < start) throw Error(`Enter a destination and valid dates for stop ${i + 1}.`);
        const accommodation = s.accommodation === '' ? 0 : Number(s.accommodation),
          tr = i === 0 ? Number(travel || 0) : null;
        return {
          name: s.name.trim(),
          country: s.country,
          start,
          end,
          year: Number(start.slice(0, 4)),
          region: s.region,
          group,
          journey_name: name.trim(),
          trip_role: 'stop',
          travel: tr,
          accommodation,
          total: Math.round(((tr || 0) + accommodation) * 100) / 100,
          flights: i === 0 && flights !== '' ? Number(flights) : null,
          leave: i === 0 && leave !== '' ? Number(leave) : null,
          days: null,
          shared_fields: i === 0 ? ['travel', ...(flights !== '' ? ['flights'] : []), ...(leave !== '' ? ['leave'] : [])] : [],
          notes: '',
          review: false,
          source: ''
        };
      });
      setError('');
      onSave(group, records);
    } catch (e) {
      setError(e.message);
    }
  }
  return <><Heading title="New journey" subtitle="Add at least two stops; shared costs are recorded once." /><Field label="Journey name" value={name} onChangeText={setName} /><Field label="Journey travel (£)" numeric value={travel} onChangeText={setTravel} /><View style={styles.inline}><View style={styles.half}><Field label="Flights" numeric value={flights} onChangeText={setFlights} /></View><View style={styles.half}><Field label="Leave days" numeric value={leave} onChangeText={setLeave} /></View></View>{stops.map((s, i) => <View key={i}><Text style={styles.section}>Stop {i + 1}</Text><Field label="Destination" value={s.name} onChangeText={v => change(i, 'name', v)} /><Field label="Country" value={s.country} onChangeText={v => change(i, 'country', v)} /><View style={styles.inline}><View style={styles.half}><Field label="Start (DD/MM/YYYY)" value={s.start} onChangeText={v => change(i, 'start', v)} /></View><View style={styles.half}><Field label="End (DD/MM/YYYY)" value={s.end} onChangeText={v => change(i, 'end', v)} /></View></View><Field label="Accommodation (£)" numeric value={s.accommodation} onChangeText={v => change(i, 'accommodation', v)} /><Text style={styles.label}>Region</Text><View style={styles.chips}>{regions.map(r => <Chip key={r} title={r} active={s.region === r} onPress={() => change(i, 'region', r)} />)}</View>{stops.length > 2 && <Button title="Remove stop" kind="secondary" onPress={() => setStops(stops.filter((_, index) => index !== i))} />}</View>)}<View style={styles.spacer} /><Button title="＋ Add stop" kind="secondary" onPress={() => setStops([...stops, blankStop()])} /><Text style={styles.tiny}>You can add map places to each stop after saving.</Text>{!!error && <Text style={styles.error}>{error}</Text>}<View style={styles.spacer} /><Button title={saving ? 'Saving…' : 'Save journey'} disabled={saving} onPress={submit} /><View style={styles.spacer} /><Button title="Cancel" kind="secondary" onPress={onCancel} /></>;
}

const annualFields = [
  ['travel', 'Travel (£)'],
  ['accommodation', 'Accommodation (£)'],
  ['total', 'Total (£)'],
  ['days', 'Days'],
  ['flights', 'Flights'],
  ['percent', 'Percent away'],
  ['leave_total', 'Leave allowance / total'],
  ['other_usage', 'Other leave usage'],
  ['leave_left', 'Leave remaining'],
  ['bought', 'Leave bought'],
  ['paid_back', 'Paid back (£)']
];

export function AnnualEditor({ year, values, onSave, onCancel, saving }) {
  const [draft, setDraft] = useState(() => ({ ...values }));
  const [error, setError] = useState('');
  function submit() {
    const result = { ...values };
    for (const [key, label] of annualFields) {
      const input = draft[key];
      if (input == null || String(input).trim() === '') {
        result[key] = null;
        continue;
      }
      const number = Number(input);
      if (!Number.isFinite(number)) {
        setError(`Enter a valid number for ${label}.`);
        return;
      }
      result[key] = number;
    }
    setError('');
    onSave(year, result);
  }
  return <><Heading title="Annual figures" subtitle={`${year} worksheet reference`} /><Notice>These are your original worksheet figures. They do not recalculate from trips.</Notice>{annualFields.map(([key, label]) => <Field key={key} label={label} numeric value={draft[key]} onChangeText={value => setDraft(current => ({ ...current, [key]: value }))} />)}{!!error && <Text accessibilityRole="alert" style={styles.error}>{error}</Text>}<View style={styles.spacer} /><Button title={saving ? 'Saving…' : 'Save figures'} disabled={saving} onPress={submit} /><View style={styles.spacer} /><Button title="Cancel" kind="secondary" onPress={onCancel} /></>;
}
