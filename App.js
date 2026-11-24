import React, { useCallback, useEffect, useRef, useState } from 'react';
import { ActivityIndicator, Alert, Image, KeyboardAvoidingView, Platform, Pressable, RefreshControl, SafeAreaView, ScrollView, Text, View } from 'react-native';
import { StatusBar } from 'expo-status-bar';
import { colors, styles } from './src/theme';
import { Button } from './src/ui';
import { CalendarScreen, MapScreen, RecordDetail, StatsScreen, TripsScreen } from './src/screens';
import { JourneyEditor, RecordEditor } from './src/editor';
const SERVERS = ['http://192.168.32.48:7780', 'http://100.94.227.14:7780'];
const TABS = [['Trips', '☷'], ['Statistics', '▥'], ['Map', '◇'], ['Calendar', '▦']];
async function request(base, path, body, timeout = 12000) {
  const controller = new AbortController(),
    timer = setTimeout(() => controller.abort(), timeout);
  try {
    const response = await fetch(`${base}${path}`, {
      ...(body ? {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify(body)
      } : {}),
      signal: controller.signal
    });
    const result = await response.json();
    if (!response.ok) throw new Error(result.error || 'Request failed');
    return result;
  } catch (e) {
    if (e.name === 'AbortError') throw new Error(body ? 'The request timed out. Check the website before trying again; the server may have saved it.' : 'Connection timed out.');
    throw e;
  } finally {
    clearTimeout(timer);
  }
}
export default function App() {
  const [data, setData] = useState(null),
    [server, setServer] = useState(null),
    [loading, setLoading] = useState(true),
    [saving, setSaving] = useState(false),
    [error, setError] = useState(''),
    [tab, setTab] = useState('Trips'),
    [year, setYear] = useState('all'),
    [page, setPage] = useState(null);
  const [selected, setSelected] = useState(null),
    [kind, setKind] = useState(null);
  const scroll = useRef(null);
  const load = useCallback(async () => {
    setLoading(true);
    setError('');
    let last;
    for (const base of SERVERS) {
      try {
        const result = await request(base, '/api/data', null, 5000);
        setData(result);
        setServer(base);
        setLoading(false);
        return true;
      } catch (e) {
        last = e;
      }
    }
    setError(`Unable to connect to the travel server. ${last?.message || ''}`);
    setLoading(false);
    return false;
  }, []);
  useEffect(() => {
    load();
  }, [load]);
  const api = useCallback((path, body) => {
    if (!server) throw Error('No connection to the server.');
    return request(server, path, body);
  }, [server]);
  const top = () => scroll.current?.scrollTo({
    y: 0,
    animated: false
  });
  const open = (recordKind, record) => {
    setKind(recordKind);
    setSelected(record);
    setPage('detail');
    top();
  };
  const leaveDraft = callback => {
    if (page === 'edit' || page === 'journey') Alert.alert('Discard changes?', 'Your unsaved changes will be lost.', [{
      text: 'Keep editing',
      style: 'cancel'
    }, {
      text: 'Discard',
      style: 'destructive',
      onPress: callback
    }]);else callback();
  };
  const navigate = next => leaveDraft(() => {
    setTab(next);
    setPage(null);
    setSelected(null);
    top();
  });
  const back = () => leaveDraft(() => {
    if (page === 'edit' && selected) {
      setPage('detail');
    } else {
      setPage(null);
      setSelected(null);
    }
    top();
  });
  const save = async (recordKind, record, id) => {
    setSaving(true);
    try {
      const saved = await api('/api/save', {
        kind: recordKind,
        id: id || null,
        record
      });
      setKind(recordKind);
      setSelected(saved);
      setPage('detail');
      top();
      await load();
    } catch (e) {
      Alert.alert('Could not confirm save', `${e.message}\n\nIf the connection was interrupted, check the existing records before trying again.`);
    } finally {
      setSaving(false);
    }
  };
  const saveJourney = async (group, records) => {
    setSaving(true);
    try {
      const result = await api('/api/save-journey', {
        group,
        records
      });
      setKind('trips');
      setSelected(result.trips[0]);
      setPage('detail');
      top();
      await load();
    } catch (e) {
      Alert.alert('Could not confirm save', `${e.message}\n\nCheck existing trips before trying again.`);
    } finally {
      setSaving(false);
    }
  };
  const remove = () => Alert.alert('Delete this entry?', 'The server keeps a previous version in its history.', [{
    text: 'Cancel',
    style: 'cancel'
  }, {
    text: 'Delete',
    style: 'destructive',
    onPress: async () => {
      setSaving(true);
      try {
        await api('/api/delete', {
          kind,
          id: selected.id
        });
        setPage(null);
        setSelected(null);
        await load();
      } catch (e) {
        Alert.alert('Could not confirm deletion', e.message);
      } finally {
        setSaving(false);
      }
    }
  }]);
  const addEvent = date => {
    setKind('events');
    setSelected(null);
    setPage('edit');
    setInitialDate(date);
    top();
  };
  const [initialDate, setInitialDate] = useState(null);
  return <SafeAreaView style={styles.safe}><StatusBar style="light" /><KeyboardAvoidingView style={styles.flex} behavior={Platform.OS === 'ios' ? 'padding' : undefined}><View style={styles.header}><View style={styles.inline}><Image source={require('./assets/icon.png')} style={{
            width: 34,
            height: 34,
            borderRadius: 6
          }} accessibilityLabel="SWW Atlas emblem" /><Text style={styles.brand}>THE SWW ATLAS</Text></View><Text style={styles.headerMeta}>{server ? 'YOUR TRAVEL RECORD' : 'OFFLINE'}</Text></View>{loading && !data ? <ActivityIndicator style={styles.flex} color={colors.accent} /> : <ScrollView ref={scroll} keyboardShouldPersistTaps="handled" contentContainerStyle={styles.content} refreshControl={<RefreshControl refreshing={loading} onRefresh={load} tintColor={colors.accent} />}>
 {!!error && <View style={styles.notice}><Text style={styles.error}>{error}</Text><View style={styles.spacer} /><Button title="Try again" kind="secondary" onPress={load} /></View>}
 {page && <Pressable accessibilityRole="button" onPress={back} style={{
          paddingVertical: 8,
          marginBottom: 12
        }}><Text style={styles.link}>‹ Back</Text></Pressable>}
 {data && (page === 'detail' && selected ? <RecordDetail kind={kind} record={selected} data={data} onOpen={open} onEdit={() => {
          setPage('edit');
          top();
        }} onDelete={remove} /> : page === 'edit' ? <RecordEditor key={`${kind}-${selected?.id || initialDate || 'new'}`} kind={kind} record={selected || undefined} initialDate={initialDate} data={data} api={api} saving={saving} onSave={save} onCancel={back} /> : page === 'journey' ? <JourneyEditor saving={saving} onSave={saveJourney} onCancel={back} /> : tab === 'Trips' ? <TripsScreen data={data} year={year} setYear={setYear} onOpen={open} onAdd={() => {
          setKind('trips');
          setSelected(null);
          setInitialDate(null);
          setPage('edit');
          top();
        }} onJourney={() => {
          setPage('journey');
          top();
        }} /> : tab === 'Statistics' ? <StatsScreen data={data} year={year} setYear={setYear} onOpen={open} /> : tab === 'Map' ? <MapScreen data={data} onOpen={open} api={api} /> : <CalendarScreen data={data} onOpen={open} onAddEvent={addEvent} />)}
 </ScrollView>}<View style={styles.nav}>{TABS.map(([label, icon]) => <Pressable key={label} accessibilityRole="tab" accessibilityState={{
          selected: tab === label
        }} style={styles.tab} onPress={() => navigate(label)}><Text style={[styles.tabIcon, tab === label && styles.tabActive]}>{icon}</Text><Text style={[styles.tabText, tab === label && styles.tabActive]}>{label}</Text></Pressable>)}</View></KeyboardAvoidingView></SafeAreaView>;
}
