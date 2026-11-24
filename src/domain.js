/**
 * Calculate travel records using the existing server's allocation rules.
 */
const countries = require('./countries.json');
const countryCodes = Object.fromEntries(countries.map(country => [country.name.toLowerCase(), country.code]));
const countryAliases = {
  'united states': 'US',
  'united states of america': 'US',
  'usa': 'US',
  'united kingdom': 'GB',
  'hong kong': 'HK',
  'macau': 'MO',
  'vatican city': 'VA',
  'turkey': 'TR',
  'south korea': 'KR',
  'russia': 'RU',
  'czech republic': 'CZ',
  'england': 'england',
  'scotland': 'scotland',
  'wales': 'wales',
  'northern ireland': 'northern ireland'
};
const homeFlags = {
  england: '🏴\u{e0067}\u{e0062}\u{e0065}\u{e006e}\u{e0067}\u{e007f}',
  scotland: '🏴\u{e0067}\u{e0062}\u{e0073}\u{e0063}\u{e0074}\u{e007f}',
  wales: '🏴\u{e0067}\u{e0062}\u{e0077}\u{e006c}\u{e0073}\u{e007f}',
  'northern ireland': '🇬🇧'
};
const sharedGroups = {
  '2022-americas': ['travel', 'total', 'flights', 'days'],
  '2023-alps': ['travel', 'accommodation', 'total', 'days'],
  '2023-world': ['travel', 'total', 'days'],
  '2023-paris': ['travel', 'total', 'leave'],
  '2024-summer': ['days', 'leave'],
  '2024-autumn': ['days'],
  '2025-easter': ['days'],
  '2025-americas': ['flights', 'days', 'leave'],
  '2025-newyear': ['days', 'leave'],
  '2026-asia': ['travel', 'total', 'flights', 'days', 'leave']
};
function sharedField(trip, key, trips) {
  if (!trip.group) return false;
  if (sharedGroups[trip.group]?.includes(key)) return true;
  if (!['travel', 'flights', 'days', 'leave'].includes(key)) return false;
  return (trip.shared_fields || []).includes(key) || trip[key] == null && trips.some(t => t.group === trip.group && (t.shared_fields || []).includes(key));
}
const value = n => Number(n) || 0;
const sum = (rows, key) => rows.reduce((n, row) => n + value(row[key]), 0);
const allocationMonth = trip => trip.start ? trip.start.slice(0, 4) == trip.year ? Number(trip.start.slice(5, 7)) : 1 : 0;
function uniqueVisits(rows) {
  const seen = new Set();
  return rows.filter(t => {
    const key = [t.name,t.start,t.end].join('|');
    if (seen.has(key)) return false;
    seen.add(key);
    return true;
  });
}
function journeyCount(rows) {
  return new Set(uniqueVisits(rows).map(t => t.group ? `journey:${t.group}` : `trip:${t.id}`)).size;
}
function uniqueCosts(rows) {
  const seen = new Set();
  return rows.filter(t => {
    const key = JSON.stringify([t.name, t.start, t.end, t.travel, t.accommodation, t.total]);
    if (seen.has(key)) return false;
    seen.add(key);
    return true;
  });
}
function dateCount(rows, year = 'all', month = 'all') {
  const dates = new Set();
  for (const t of rows) {
    if (!t.start || !t.end || t.end < t.start) continue;
    const day = new Date(`${t.start}T12:00:00Z`),
      end = new Date(`${t.end}T12:00:00Z`);
    if (!Number.isFinite(day.getTime()) || (end - day) / 86400000 > 1000) continue;
    while (day <= end) {
      if ((year === 'all' || day.getUTCFullYear() === Number(year)) && (month === 'all' || day.getUTCMonth() + 1 === Number(month))) dates.add(day.toISOString().slice(0, 10));
      day.setUTCDate(day.getUTCDate() + 1);
    }
  }
  return dates.size;
}
function scopedTrips(trips, year = 'all', month = 'all') {
  return trips.filter(t => {
    if (year !== 'all' && t.year !== Number(year)) return false;
    if (month === 'all' || allocationMonth(t) === Number(month)) return true;
    if (!t.start || !t.end) return false;
    const y = year === 'all' ? t.year : Number(year),
      m = Number(month);
    const first = `${y}-${String(m).padStart(2, '0')}-01`,
      last = `${y}-${String(m).padStart(2, '0')}-${new Date(Date.UTC(y, m, 0)).getUTCDate()}`;
    return t.start <= last && t.end >= first;
  });
}
function statistics(trips, year = 'all', month = 'all') {
  const rows = scopedTrips(trips, year, month);
  const allocated = month === 'all' ? rows : rows.filter(t => allocationMonth(t) === Number(month));
  const costs = year === 'all' ? uniqueCosts(allocated) : allocated;
  return {
    rows,
    spend: sum(costs, 'total'),
    travel: sum(costs, 'travel'),
    accommodation: sum(costs, 'accommodation'),
    days: dateCount(rows, year, month),
    flights: sum(allocated, 'flights'),
    leave: sum(allocated, 'leave')
  };
}
function placeFor(data, trip) {
  return {
    ...(data.places?.[trip.name] || {}),
    ...Object.fromEntries(['country', 'lat', 'lon', 'pins'].filter(k => Object.hasOwn(trip, k)).map(k => [k, trip[k]]))
  };
}
function tripCountries(data, trip) {
  return String(placeFor(data, trip).country || '').split(',').map(s => s.trim()).filter(Boolean);
}
function flag(name) {
  const key = name.toLowerCase(),
    code = countryAliases[key] || countryCodes[key];
  if (homeFlags[code]) return homeFlags[code];
  return code && /^[A-Z]{2}$/.test(code) ? String.fromCodePoint(...[...code].map(c => c.charCodeAt(0) + 127397)) : '🌐';
}
function calendarRange(data, trip) {
  if (trip.calendar_confirmed) return [trip.start, trip.end];
  const match = (data['calendar-overrides'] || []).find(([y, n, s]) => y === trip.year && n === trip.name && s === trip.start);
  return match ? [match[3], match[4]] : [trip.start, trip.end];
}
function eventsDuringTrip(data, trip) {
  const [start, end] = calendarRange(data, trip);
  if (!start || !end || end < start) return [];
  return (data.events || []).filter(event => event.start && event.end && event.start <= end && event.end >= start)
    .slice().sort((a, b) => a.start.localeCompare(b.start) || a.name.localeCompare(b.name));
}
function hasMappedPlace(data, trip) {
  const place = placeFor(data, trip);
  const pins = place.pins || [{lat: place.lat, lon: place.lon}];
  return pins.some(pin => pin.lat != null && pin.lon != null && Number.isFinite(Number(pin.lat)) && Number.isFinite(Number(pin.lon)) && Math.abs(Number(pin.lat)) <= 90 && Math.abs(Number(pin.lon)) <= 180);
}
function crossYearAllocations(data, trip) {
  if (!trip.start || !trip.end) return [];
  const matches = (data.trips || []).filter(row => row.name === trip.name && row.start === trip.start && row.end === trip.end && row.year != null);
  return new Set(matches.map(row => row.year)).size > 1 ? matches.slice().sort((a, b) => a.year - b.year) : [];
}
function dayEntries(data, date) {
  const seen = new Set();
  const trips = (data.trips || []).filter(t => {
    const [a, b] = calendarRange(data, t),
      key = JSON.stringify([t.name, t.start, t.end]);
    if (!a || !b || a > date || b < date || seen.has(key)) return false;
    seen.add(key);
    return true;
  }).map(record => ({
    kind: 'trips',
    record
  }));
  return trips.concat((data.events || []).filter(e => e.start && e.end && e.start <= date && e.end >= date).map(record => ({
    kind: 'events',
    record
  })));
}
module.exports = {
  sharedField,
  allocationMonth,
  calendarRange,
  dateCount,
  dayEntries,
  eventsDuringTrip,
  hasMappedPlace,
  crossYearAllocations,
  flag,
  placeFor,
  scopedTrips,
  statistics,
  sum,
  tripCountries,
  uniqueCosts,
  uniqueVisits,
  journeyCount
};
