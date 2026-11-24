const assert = require('node:assert/strict');
const {
  statistics,
  dayEntries,
  flag,
  sharedField,
  calendarRange,
  placeFor
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
console.log('domain tests passed');
