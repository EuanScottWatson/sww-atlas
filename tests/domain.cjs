const assert = require('node:assert/strict');
const {
  statistics,
  dayEntries,
  eventsDuringTrip,
  hasMappedPlace,
  crossYearAllocations,
  flag,
  sharedField,
  calendarRange,
  placeFor,
  journeyCount
} = require('../src/domain');
const trips = [{
  id: 1,
  name: 'A',
  year: 2025,
  start: '2025-12-30',
  end: '2026-01-02',
  travel: 10,
  accommodation: 20,
  total: 30,
  flights: 2,
  leave: 1
}, {
  id: 2,
  name: 'A',
  year: 2026,
  start: '2025-12-30',
  end: '2026-01-02',
  travel: 10,
  accommodation: 20,
  total: 30,
  flights: 2,
  leave: 1
}, {
  id: 3,
  name: 'B',
  year: 2026,
  start: '2026-01-02',
  end: '2026-01-03',
  travel: 5,
  total: 5,
  flights: 0,
  leave: 1
}];
assert.equal(statistics(trips).spend, 35);
assert.equal(statistics(trips).days, 5);
assert.equal(statistics(trips, 2026).days, 3);
assert.equal(statistics(trips, 2026, 1).spend, 35);
assert.equal(statistics(trips, 2025).spend, 30);
const data = {
  trips,
  places: {
    A: {
      country: 'Japan',
      lat: 10,
      lon: 20
    }
  },
  events: [{
    id: 7,
    name: 'Concert',
    start: '2026-01-02',
    end: '2026-01-02'
  }],
  'calendar-overrides': [[2026, 'B', '2026-01-02', '2026-01-03', '2026-01-04']]
};
assert.deepEqual(dayEntries(data, '2026-01-02').map(x => x.record.name), ['A', 'Concert']);
assert.deepEqual(dayEntries(data, '2026-01-03').map(x => x.record.name), ['B']);
assert.deepEqual(calendarRange(data, {
  ...trips[2],
  calendar_confirmed: true
}), ['2026-01-02', '2026-01-03']);
assert.equal(placeFor(data, trips[0]).country, 'Japan');
assert.equal(flag('Japan'), '🇯🇵');
assert.equal(flag('United States of America'), '🇺🇸');
assert.equal(flag('unknown'), '🌐');
assert.equal(sharedField({
  group: '2023-world'
}, 'total', []), true);
assert.equal(sharedField({
  group: 'journey-1',
  travel: null
}, 'travel', [{
  group: 'journey-1',
  shared_fields: ['travel']
}]), true);
assert.equal(sharedField({
  group: 'journey-1',
  total: 50
}, 'total', []), false);

assert.equal(journeyCount([{id:1,name:'A',start:'2025-01-01',end:'2025-01-02',group:'j'}, {id:2,name:'A',start:'2025-01-01',end:'2025-01-02',group:'j'}, {id:3,name:'B',start:'2025-01-03',end:'2025-01-04',group:'j'}]), 1);

assert.deepEqual(eventsDuringTrip(data, trips[2]).map(event => event.name), []);
assert.deepEqual(eventsDuringTrip(data, trips[0]).map(event => event.name), ['Concert']);
assert.equal(hasMappedPlace(data, trips[0]), true);
assert.equal(hasMappedPlace(data, {...trips[0], lat: null, lon: null}), false);
assert.equal(hasMappedPlace(data, {...trips[0], pins: [{lat: 91, lon: 1}]}), false);
assert.equal(crossYearAllocations(data, trips[0]).length, 2);
assert.equal(crossYearAllocations(data, trips[2]).length, 0);

console.log('domain tests passed');
