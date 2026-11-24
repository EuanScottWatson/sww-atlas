import React, { useMemo, useRef, useState } from 'react';
import { Alert, Linking, Pressable, Text, TextInput, View } from 'react-native';
import MapView, { Marker } from 'react-native-maps';
import { colors, styles } from './theme';
import { Button, Chip, Detail, Heading, Notice, dateRange, money, shortDate, todayISO } from './ui';
const {
  allocationMonth,
  calendarRange,
  crossYearAllocations,
  dayEntries,
  eventsDuringTrip,
  hasMappedPlace,
  flag,
  journeyCount,
  placeFor,
  scopedTrips,
  sharedField,
  statistics,
  tripCountries,
  uniqueCosts,
  uniqueVisits
} = require('./domain');
export function YearPicker({
  year,
  setYear,
  data
}) {
  const [open, setOpen] = useState(false);
  const years = [...new Set((data.trips || []).map(t => t.year).filter(Boolean).concat(new Date().getFullYear()))].sort((a, b) => b - a);
  return <View><Chip title={year === 'all' ? 'All years' : String(year)} active onPress={() => setOpen(!open)} />{open && <View style={styles.chips}><Chip title="All years" active={year === 'all'} onPress={() => {
        setYear('all');
        setOpen(false);
      }} />{years.map(y => <Chip key={y} title={String(y)} active={Number(year) === y} onPress={() => {
        setYear(y);
        setOpen(false);
      }} />)}</View>}</View>;
}
function OptionPicker({label, value, options, onChange}) {
  const [open, setOpen] = useState(false);
  const selected = options.find(option => option[0] === value);
  return <View><Chip title={`${label}: ${selected?.[1] || 'All'}`} onPress={() => setOpen(!open)} />{open && <View style={styles.chips}>{options.map(([key, name]) => <Chip key={key} title={name} active={value === key} onPress={() => { onChange(key); setOpen(false); }} />)}</View>}</View>;
}
const monthOptions = [['all','All'], ...['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'].map((name,index)=>[index+1,name])];
function TripRow({
  trip,
  data,
  onPress
}) {
  const country = tripCountries(data, trip);
  return <Pressable accessibilityRole="button" onPress={onPress} style={styles.row}><View style={styles.rowMain}><Text style={styles.rowTitle}>{trip.name}</Text><Text style={styles.tiny}>{country.map(flag).join(' ')} {country.join(', ')}</Text><Text style={styles.tiny}>{dateRange(trip)}</Text></View><Text style={styles.rowValue}>{money(trip.total)}  ›</Text></Pressable>;
}
export function TripsScreen({
  data,
  year,
  setYear,
  onOpen,
  onAdd,
  onJourney
}) {
  const [query, setQuery] = useState(''),
    [status, setStatus] = useState('all'),
    [region, setRegion] = useState('all'),
    [month, setMonth] = useState('all'),
    [sort, setSort] = useState('newest');
  const today = todayISO();
  const rows = useMemo(() => {
    let list = scopedTrips(data.trips || [], year, month).filter(t => {
      const hay = [t.name, t.notes, t.locations, t.journey_name, ...tripCountries(data, t)].filter(Boolean).join(' ').toLowerCase();
      return hay.includes(query.toLowerCase().trim()) && (region === 'all' || t.region === region) && (status === 'all' || status === 'upcoming' && t.start && t.start > today || status === 'past' && t.start && t.start <= today || status === 'undated' && !t.start);
    });
    if (year === 'all') {
      const seen = new Map();
      list = list.filter(t => {
        if (!t.start || !t.end) return true;
        const key = JSON.stringify([t.name, t.start, t.end]);
        if (!seen.has(key)) {
          seen.set(key, new Set([t.year]));
          return true;
        }
        const years = seen.get(key);
        if (!years.has(t.year)) {
          years.add(t.year);
          return false;
        }
        return true;
      });
    }
    return list.sort((a, b) => sort === 'name' ? a.name.localeCompare(b.name) : sort === 'oldest' ? (a.start || '9999').localeCompare(b.start || '9999') : (b.start || '').localeCompare(a.start || ''));
  }, [data, year, month, status, region, sort, query, today]);
  return <><Heading title="Trips" subtitle={`${rows.length} records`} action={<Button title="＋ Add" onPress={onAdd} />} /><YearPicker year={year} setYear={setYear} data={data} /><TextInput style={[styles.input, {
      marginBottom: 12
    }]} placeholder="Search trips, places or notes" placeholderTextColor={colors.muted} accessibilityLabel="Search trips" value={query} onChangeText={setQuery} /><View style={styles.chips}>{[['all', 'All'], ['upcoming', 'Upcoming'], ['past', 'Past'], ['undated', 'Undated']].map(([k, v]) => <Chip key={k} title={v} active={status === k} onPress={() => setStatus(k)} />)}</View><OptionPicker label="Region" value={region} options={['all','UK','Europe','Africa','North America','South America','Asia','Oceania'].map(x=>[x,x==='all'?'All':x])} onChange={setRegion}/><OptionPicker label="Month" value={month} options={monthOptions} onChange={setMonth}/><OptionPicker label="Sort" value={sort} options={[["newest","Newest"],["oldest","Oldest"],["name","Name"]]} onChange={setSort}/><Pressable onPress={onJourney} accessibilityRole="button"><Text style={styles.link}>＋ Add a multi-stop journey</Text></Pressable><Text style={styles.section}>Destination                         Total</Text>{rows.length ? rows.map(t => <TripRow key={`${t.id}`} trip={t} data={data} onPress={() => onOpen('trips', t)} />) : <Notice>No trips match these filters.</Notice>}</>;
}
function Bars({
  rows,
  year,
  metric
}) {
  const years = year === 'all' ? [...new Set(rows.map(r => r.year))].sort() : Array.from({
    length: 12
  }, (_, i) => i + 1);
  const entries = years.map(x => {
    const matches = year === 'all' ? rows.filter(t => t.year === x) : rows.filter(t => allocationMonth(t) === x);
    const v = metric === 'days' ? statistics(rows, year === 'all' ? x : year, year === 'all' ? 'all' : x).days : matches.reduce((n, t) => n + (Number(t[metric]) || 0), 0);
    return {
      label: year === 'all' ? String(x) : ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][x - 1],
      value: v
    };
  });
  const max = Math.max(1, ...entries.map(x => x.value));
  return <>{entries.map(e => <View key={e.label} style={styles.barRow}><Text style={styles.barLabel}>{e.label}</Text><View style={styles.barTrack}><View style={[styles.barFill, {
          width: `${Math.max(0, e.value / max * 100)}%`
        }]} /></View><Text style={styles.barValue}>{metric === 'total' ? money(e.value) : e.value}</Text></View>)}</>;
}
export function StatsScreen({
  data,
  year,
  setYear,
  onOpen,
  onEditAnnual
}) {
  const [metric, setMetric] = useState('total'),
    [month, setMonth] = useState('all');
  const s = statistics(data.trips || [], year, month);
  const today = todayISO();
  const dated = (data.trips || []).filter(t => t.start).sort((a, b) => a.start.localeCompare(b.start));
  const next = dated.find(t => t.start > today),
    current = dated.find(t => t.start <= today && t.end >= today),
    recent = [...dated].reverse().find(t => t.start <= today);
  const summaries = data.summaries || {};
  return <><Heading title="Statistics" subtitle="Your travel, in numbers" /><YearPicker year={year} setYear={y => {
      setYear(y);
      setMonth('all');
    }} data={data} /><OptionPicker label="Month" value={month} options={monthOptions} onChange={setMonth}/><View style={styles.statGrid}>{[['Total spend', money(s.spend)], ['Days away', s.days], ['Trip records', s.rows.length], ['Flights', s.flights], ['Leave days', s.leave]].map(([label, v]) => <View style={styles.stat} key={label}><Text style={styles.statNum}>{v}</Text><Text style={styles.statLabel}>{label}</Text></View>)}</View><Text style={styles.section}>Highlights</Text>{[['Current', current], ['Next', next], ['Latest', recent]].map(([label, t]) => <Pressable key={label} style={styles.detail} onPress={() => t && onOpen('trips', t)}><Text style={styles.muted}>{label}</Text><Text style={styles.detailValue}>{t ? `${t.name} · ${shortDate(t.start)}` : 'None recorded'}</Text></Pressable>)}{next && <Text style={styles.tiny}>Next trip in {Math.max(0, Math.ceil((new Date(`${next.start}T12:00:00`) - new Date()) / 86400000))} days</Text>}<Text style={styles.section}>{year === 'all' ? 'Yearly' : 'Monthly'} breakdown</Text><View style={styles.chips}>{[['total', 'Spend'], ['days', 'Days away'], ['flights', 'Flights'], ['leave', 'Leave']].map(([k, v]) => <Chip key={k} title={v} active={metric === k} onPress={() => setMetric(k)} />)}</View><Bars rows={s.rows} year={year} metric={metric} /><Text style={styles.section}>Cost split</Text><View style={{
      height: 12,
      flexDirection: 'row',
      backgroundColor: colors.panel
    }}><View style={{
        height: 12,
        width: `${s.travel + s.accommodation ? s.travel / (s.travel + s.accommodation) * 100 : 0}%`,
        backgroundColor: colors.accent
      }} /><View style={{
        height: 12,
        width: `${s.travel + s.accommodation ? s.accommodation / (s.travel + s.accommodation) * 100 : 0}%`,
        backgroundColor: '#efaa75'
      }} /></View><Detail label="Travel" value={money(s.travel)} /><Detail label="Accommodation" value={money(s.accommodation)} /><Text style={styles.tiny}>Component costs can differ from recorded totals.</Text><Text style={styles.section}>Recorded allocations</Text>{(year === 'all' ? [...new Set(s.rows.map(t => t.year))].sort((a, b) => b - a) : month === 'all' ? Array.from({
      length: 12
    }, (_, i) => i + 1) : [month]).map(x => {
      const a = statistics(data.trips, year === 'all' ? x : year, year === 'all' ? 'all' : x);
      return <View key={x} style={styles.detail}><View><Text style={styles.body}>{year === 'all' ? x : ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][x - 1]}</Text><Text style={styles.tiny}>{a.days} days · {a.flights} flights · {a.leave} leave</Text><Text style={styles.tiny}>Travel {money(a.travel)} · stay {money(a.accommodation)}</Text></View><Text style={styles.detailValue}>{money(a.spend)}</Text></View>;
    })}{year !== 'all' && summaries[year] && <><Text style={styles.section}>Original worksheet figures</Text><Button title="Edit annual figures" kind="secondary" onPress={onEditAnnual} /><View style={styles.spacer} /><Notice>These preserved reference figures are separate from live calculations.</Notice>{[['Travel', money(summaries[year].travel)], ['Accommodation', money(summaries[year].accommodation)], ['Spend', money(summaries[year].total)], ['Days', summaries[year].days], ['Flights', summaries[year].flights], ['Leave allowance', summaries[year].leave_total], ['Leave remaining', summaries[year].leave_left], ['Leave bought', summaries[year].bought], ['Other leave usage', summaries[year].other_usage], ['Percent away', summaries[year].percent], ['Paid back', money(summaries[year].paid_back)]].map(([label, v]) => <Detail key={label} label={label} value={v} />)}{summaries[year].notes ? <Text style={styles.muted}>{summaries[year].notes}</Text> : null}</>}{s.rows.some(t => t.review) && <><Text style={styles.section}>Import notes</Text><Text style={styles.muted}>Entries marked for review retain their original notes.</Text>{s.rows.filter(t => t.review).map(t => <TripRow key={t.id} trip={t} data={data} onPress={() => onOpen('trips',t)} />)}</>}</>;
}
const iso = (y, m, d) => `${y}-${String(m + 1).padStart(2, '0')}-${String(d).padStart(2, '0')}`;
export function CalendarScreen({
  data,
  onOpen,
  onAddEvent,
  calendar,
  setCalendar
}) {
  const {cursor, mode, selected, query} = calendar;
  const change = (key, value) => setCalendar(current => ({...current, [key]:value}));
  const setCursor = value => change('cursor',value);
  const setMode = value => change('mode',value);
  const setSelected = value => change('selected',value);
  const setQuery = value => change('query',value);
  const y = cursor.getFullYear(),
    m = cursor.getMonth(),
    days = new Date(y, m + 1, 0).getDate(),
    offset = (new Date(y, m, 1).getDay() + 6) % 7;
  const first = iso(y, m, 1),
    last = iso(y, m, days);
  const entries = dayEntries(data, selected);
  const searchResults = query.trim() ? [...(data.events || []).map(record => ({kind:'events',record})), ...uniqueVisits(data.trips || []).map(record => ({kind:'trips',record}))].filter(({record}) => `${record.name} ${record.notes || ''}`.toLowerCase().includes(query.trim().toLowerCase())).sort((a, b) => (b.record.start || '').localeCompare(a.record.start || '')) : [];
  return <><Heading title="Calendar" subtitle="Trips and personal events" action={<Button title="＋ Event" onPress={() => onAddEvent(selected)} />} /><TextInput style={[styles.input, {
      marginBottom: 12
    }]} placeholder="Search events and trips" placeholderTextColor={colors.muted} value={query} onChangeText={setQuery} accessibilityLabel="Search events and trips" />{query.trim() ? <>{searchResults.length ? searchResults.map(({kind,record}) => <Pressable key={`${kind}${record.id}`} onPress={() => onOpen(kind, record)} style={styles.row}><View style={styles.rowMain}><Text style={styles.rowTitle}>{record.name}</Text><Text style={styles.tiny}>{kind === 'trips' ? 'Trip' : 'Personal event'} · {dateRange(record)}</Text></View><Text style={styles.link}>›</Text></Pressable>) : <Notice>No matching entries found.</Notice>}</> : <><View style={styles.chips}>{[['month', 'Month'], ['agenda', 'Agenda'], ['year', 'Year']].map(([k, v]) => <Chip key={k} title={v} active={mode === k} onPress={() => setMode(k)} />)}</View><View style={styles.headingRow}><Button title="‹" kind="secondary" onPress={() => {
          const d = new Date(y, mode === 'year' ? m - 12 : m - 1, 1);
          setCursor(d);
          setSelected(iso(d.getFullYear(), d.getMonth(), 1));
        }} /><Text style={styles.body}>{mode === 'year' ? y : cursor.toLocaleDateString('en-GB', {
            month: 'long',
            year: 'numeric'
          })}</Text><Button title="›" kind="secondary" onPress={() => {
          const d = new Date(y, mode === 'year' ? m + 12 : m + 1, 1);
          setCursor(d);
          setSelected(iso(d.getFullYear(), d.getMonth(), 1));
        }} /></View>{mode === 'month' ? <><View style={styles.calendarGrid}>{['M', 'T', 'W', 'T', 'F', 'S', 'S'].map((d, i) => <View key={i} style={{
            width: '14.2857%',
            alignItems: 'center',
            paddingBottom: 8
          }}><Text style={styles.tiny}>{d}</Text></View>)}{Array.from({
            length: offset
          }, (_, i) => <View key={`blank${i}`} style={styles.calendarDay} />)}{Array.from({
            length: days
          }, (_, i) => {
            const d = iso(y, m, i + 1),
              has = dayEntries(data, d).length > 0;
            return <Pressable key={d} accessibilityRole="button" accessibilityLabel={`${shortDate(d)}, ${has ? 'has entries' : 'no entries'}`} onPress={() => setSelected(d)} style={[styles.calendarDay, selected === d && styles.calendarSelected]}><Text style={[styles.calendarDayText, selected === d && styles.calendarSelectedText]}>{i + 1}</Text>{has && <View style={[styles.calendarDot, selected === d && {
                backgroundColor: colors.dark
              }]} />}</Pressable>;
          })}</View><Text style={styles.section}>{shortDate(selected)}</Text>{entries.length ? entries.map(({
          kind,
          record
        }) => <Pressable key={`${kind}${record.id}`} onPress={() => onOpen(kind, record)} style={styles.row}><View style={styles.rowMain}><Text style={styles.rowTitle}>{record.name}</Text><Text style={styles.tiny}>{kind === 'trips' ? 'Trip' : 'Personal event'}</Text></View><Text style={styles.link}>›</Text></Pressable>) : <Notice>Nothing recorded on this day.</Notice>}<View style={styles.spacer} /><Button title="＋ Add event on this day" kind="secondary" onPress={() => onAddEvent(selected)} /></> : mode === 'agenda' ? <>{Array.from({
          length: days
        }, (_, i) => {
          const d = iso(y, m, i + 1),
            list = dayEntries(data, d);
          return list.length ? <View key={d}><Text style={styles.section}>{shortDate(d)}</Text>{list.map(({
              kind,
              record
            }) => <Pressable key={`${kind}${record.id}`} style={styles.row} onPress={() => onOpen(kind, record)}><View style={styles.rowMain}><Text style={styles.rowTitle}>{record.name}</Text><Text style={styles.tiny}>{kind === 'trips' ? 'Trip' : 'Personal event'}</Text></View><Text style={styles.link}>›</Text></Pressable>)}</View> : null;
        })}</> : <>{Array.from({
          length: 12
        }, (_, i) => {
          const d = new Date(y, i, 1),
            start = iso(y, i, 1),
            end = iso(y, i, new Date(y, i + 1, 0).getDate()),
            count = (data.events || []).filter(e => e.start && e.end && e.start <= end && e.end >= start).length,
            tripCount = (data.trips || []).filter(t => {
              const [a, b] = calendarRange(data, t);
              return a && b && a <= end && b >= start;
            }).length;
          return <Pressable key={i} style={styles.row} onPress={() => {
            setCursor(d);
            setSelected(start);
            setMode('month');
          }}><View style={styles.rowMain}><Text style={styles.rowTitle}>{d.toLocaleDateString('en-GB', {
                  month: 'long'
                })}</Text><Text style={styles.tiny}>{count} personal events · {tripCount} trip records</Text></View><Text style={styles.link}>›</Text></Pressable>;
        })}</>}</>}</>;
}
export function MapScreen({
  data,
  onOpen,
  api
}) {
  const [country, setCountry] = useState(''),
    [selected, setSelected] = useState(null),
    [overview, setOverview] = useState(null),
    [query, setQuery] = useState(''),
    [mode, setMode] = useState('visited'),
    [region, setRegion] = useState({
      latitude: 40,
      longitude: 0,
      latitudeDelta: 100,
      longitudeDelta: 100
    });
  const map = useRef(null),
    placeRequest = useRef(0);
  const today = todayISO();
  const trips = (data.trips || []).filter(t => t.start && (mode === 'all' || (mode === 'visited' ? t.start <= today : t.start > today)));
  const countries = [...new Set(trips.flatMap(t => tripCountries(data, t)))].sort((a, b) => a.localeCompare(b));
  const groups = new Map();
  for (const t of trips) {
    const p = placeFor(data, t),
      pins = p.pins || [{
        name: t.locations || p.label || t.name,
        lat: p.lat,
        lon: p.lon
      }];
    for (const pin of pins) {
      if (pin.lat == null || pin.lon == null || !Number.isFinite(Number(pin.lat)) || !Number.isFinite(Number(pin.lon)) || Math.abs(Number(pin.lat)) > 90 || Math.abs(Number(pin.lon)) > 180) continue;
      const key = `${Number(pin.lat).toFixed(4)},${Number(pin.lon).toFixed(4)}`;
      if (!groups.has(key)) groups.set(key, {
        ...pin,
        trips: [],
        country: tripCountries(data, t).join(', ')
      });
      groups.get(key).trips.push(t);
    }
  }
  const unmapped = uniqueVisits(trips.filter(t => !hasMappedPlace(data,t) && (!country || tripCountries(data,t).includes(country)) && `${t.name} ${tripCountries(data,t).join(' ')}`.toLowerCase().includes(query.trim().toLowerCase())));
  const pins = [...groups.values()].filter(p => (!country || p.trips.some(t => tripCountries(data, t).includes(country))) && `${p.name} ${p.country}`.toLowerCase().includes(query.toLowerCase()));
  const clusterSize = region.longitudeDelta > 20 ? Math.max(0.1, region.longitudeDelta / 25) : 0;
  const clusters = new Map();
  for (const p of pins) {
    const key = clusterSize ? `${Math.round(Number(p.lat) / clusterSize)},${Math.round(Number(p.lon) / clusterSize)}` : `${p.lat},${p.lon}`;
    if (!clusters.has(key)) clusters.set(key, []);
    clusters.get(key).push(p);
  }
  const openPlace = async p => {
    const id = ++placeRequest.current;
    setSelected(p);
    setOverview(null);
    try {
      const params = `name=${encodeURIComponent(p.name)}&country=${encodeURIComponent(p.country)}&lat=${p.lat}&lon=${p.lon}`;
      const result = await api(`/api/place?${params}`);
      if (id === placeRequest.current) setOverview(result);
    } catch (e) {
      if (id === placeRequest.current) setOverview({
        error: e.message
      });
    }
  };
  return <><Heading title="Map" subtitle="Your recorded places and countries" /><View style={styles.chips}>{[['visited', 'Visited'], ['upcoming', 'Upcoming'], ['all', 'All']].map(([k, v]) => <Chip key={k} title={v} active={mode === k} onPress={() => {
        setMode(k);
        setCountry('');
        setSelected(null);
      }} />)}</View><TextInput style={[styles.input, {
      marginBottom: 12
    }]} placeholder="Filter places" placeholderTextColor={colors.muted} accessibilityLabel="Filter places" value={query} onChangeText={setQuery} /><MapView ref={map} style={styles.map} initialRegion={region} onRegionChangeComplete={setRegion}>{[...clusters.entries()].map(([key, items]) => {
        const p = items[0],
          coordinate = {
            latitude: items.reduce((n, x) => n + Number(x.lat), 0) / items.length,
            longitude: items.reduce((n, x) => n + Number(x.lon), 0) / items.length
          };
        return <Marker key={key} coordinate={coordinate} title={items.length > 1 ? `${items.length} places` : p.name} pinColor={colors.accent} onPress={() => {
          if (items.length > 1) {
            map.current?.animateToRegion({
              ...coordinate,
              latitudeDelta: Math.max(region.latitudeDelta / 3, .1),
              longitudeDelta: Math.max(region.longitudeDelta / 3, .1)
            }, 350);
          } else openPlace(p);
        }} />;
      })}</MapView><Text style={styles.tiny}>Tap a pin for visit history. Locations are approximate. Map tiles require a connection.</Text>{selected && <><Text style={styles.section}>{selected.name}</Text><Text style={styles.muted}>{selected.country}</Text>{overview?.extract ? <Text style={styles.body}>{overview.extract}</Text> : overview ? <Text style={styles.muted}>Place overview unavailable.</Text> : <Text style={styles.muted}>Loading place overview…</Text>}{overview?.url && <Pressable accessibilityRole="link" onPress={() => Linking.openURL(overview.url).catch(() => Alert.alert('Unable to open link', 'Please try again.'))}><Text style={styles.link}>Open Wikipedia ↗</Text></Pressable>}<Text style={styles.section}>Your visits</Text>{uniqueVisits(selected.trips).map(t => <TripRow key={t.id} trip={t} data={data} onPress={() => onOpen('trips', t)} />)}</>}{unmapped.length > 0 && <><Text style={styles.section}>Trips without map pins</Text><Text style={styles.muted}>These destinations have no recorded coordinates.</Text>{unmapped.map(t => <TripRow key={t.id} trip={t} data={data} onPress={() => onOpen('trips',t)} />)}</>}<Text style={styles.section}>Countries · {countries.length}</Text><View style={styles.chips}><Chip title="All countries" active={!country} onPress={() => setCountry('')} />{countries.map(c => <Chip key={c} title={`${flag(c)} ${c} (${journeyCount(trips.filter(t => tripCountries(data, t).includes(c)))})`} active={country === c} onPress={() => {
        setCountry(c);
        setSelected(null);
        const coords = [...groups.values()].filter(p => p.trips.some(t => tripCountries(data, t).includes(c))).map(p => ({
          latitude: Number(p.lat),
          longitude: Number(p.lon)
        }));
        if (coords.length === 1) map.current?.animateToRegion({
          ...coords[0],
          latitudeDelta: 4,
          longitudeDelta: 4
        }, 350);else if (coords.length > 1) map.current?.fitToCoordinates(coords, {
          edgePadding: {
            top: 40,
            right: 40,
            bottom: 40,
            left: 40
          },
          animated: true
        });
      }} />)}</View></>;
}
export function RecordDetail({
  kind,
  record,
  data,
  onEdit,
  onDelete,
  onOpen
}) {
  const isTrip = kind === 'trips',
    country = isTrip ? tripCountries(data, record) : [],
    group = record.group ? (data.trips || []).filter(t => t.group === record.group) : [],
    seen = new Set(),
    stops = group.filter(t => { const key = JSON.stringify([t.name,t.start,t.end]); if (seen.has(key)) return false; seen.add(key); return true; }),
    shared = ['travel','accommodation','total','flights','days','leave'].filter(k => sharedField(record,k,data.trips || [])),
    allocations = isTrip ? crossYearAllocations(data,record) : [],
    relatedEvents = isTrip ? eventsDuringTrip(data,record) : [],
    relatedTrips = !isTrip && record.start ? dayEntries(data,record.start).filter(item => item.kind === 'trips') : [],
    display = (key, value) => shared.includes(key) ? 'Shared across journey' : value;
  return <><Heading title={record.name} subtitle={isTrip ? country.join(', ') || 'Trip' : 'Personal event'} action={<Button title="Edit" kind="secondary" onPress={onEdit} />} /><Detail label="Dates" value={dateRange(record)} />{isTrip && <><Detail label="Travel" value={display('travel', money(record.travel))} /><Detail label="Accommodation" value={display('accommodation', money(record.accommodation))} /><Detail label="Recorded total" value={display('total', money(record.total))} /><Detail label="Flights" value={display('flights', record.flights)} /><Detail label="Days recorded" value={display('days', record.days)} /><Detail label="Leave days" value={display('leave', record.leave)} /><Detail label="Allocation year" value={record.year} /><Detail label="Region" value={record.region} />{shared.length > 0 && <Notice>Shared journey fields: {shared.join(', ')}. These figures are recorded once for the journey.</Notice>}{stops.length > 1 && <><Text style={styles.section}>Journey · {record.journey_name || 'Linked stops'}</Text><Text style={styles.muted}>Recorded journey totals: {uniqueCosts(stops).some(t => t.total != null) ? money(uniqueCosts(stops).reduce((n, t) => n + (Number(t.total) || 0), 0)) : 'Not recorded'}</Text>{stops.map(t => <Pressable key={t.id} style={styles.row} onPress={() => onOpen('trips', t)}><View style={styles.rowMain}><Text style={styles.rowTitle}>{t.name}</Text><Text style={styles.tiny}>{dateRange(t)}</Text></View><Text style={styles.link}>›</Text></Pressable>)}</>}{allocations.length > 1 && <><Text style={styles.section}>Across worksheet years</Text><Notice>The same trip appears in more than one annual worksheet. Repeated costs count once in all-time totals.</Notice>{allocations.map(row => <View key={row.id} style={styles.detail}><View style={styles.rowMain}><Text style={styles.body}>{row.year}</Text><Text style={styles.tiny}>Days: {row.days ?? '—'} · Leave: {row.leave ?? '—'}</Text><Text style={styles.tiny}>Travel: {money(row.travel)} · Accommodation: {money(row.accommodation)}</Text></View><Text style={styles.detailValue}>{money(row.total)}</Text></View>)}</>}{relatedEvents.length > 0 && <><Text style={styles.section}>Events during these dates</Text><Text style={styles.tiny}>Events recorded in the calendar during this trip.</Text>{relatedEvents.map(event => <Pressable key={event.id} style={styles.row} onPress={() => onOpen('events',event)}><View style={styles.rowMain}><Text style={styles.rowTitle}>{event.name}</Text><Text style={styles.tiny}>{dateRange(event)}</Text></View><Text style={styles.link}>›</Text></Pressable>)}</>}{record.review && <><Text style={styles.section}>Needs review</Text><Text style={styles.muted}>This imported entry is marked for review.</Text></>}</>}<Text style={styles.section}>Notes</Text><Text style={styles.body}>{record.notes || 'No notes recorded.'}</Text>{relatedTrips.length > 0 && <><Text style={styles.section}>Trips on this day</Text>{relatedTrips.map(({record:trip}) => <TripRow key={trip.id} trip={trip} data={data} onPress={() => onOpen('trips',trip)} />)}</>}<View style={styles.spacer} /><Button title={isTrip ? 'Delete trip' : 'Delete event'} kind="danger" onPress={onDelete} /></>;
}
