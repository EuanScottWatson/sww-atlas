import React from 'react';
import { Pressable, Text, TextInput, View } from 'react-native';
import { colors, styles } from './theme';
export const money = n => n == null || n === '' ? '—' : `£${Number(n).toLocaleString('en-GB', {
  minimumFractionDigits: 2,
  maximumFractionDigits: 2
})}`;
export const shortDate = d => {
  if (!d) return 'Undated';
  const parts = d.split('-');
  return parts.length === 3 ? `${parts[2]}/${parts[1]}/${parts[0]}` : d;
};
export const dateRange = r => r.start ? `${shortDate(r.start)}${r.end && r.end !== r.start ? ` – ${shortDate(r.end)}` : ''}` : 'Undated';
export const todayISO = () => {
  const d = new Date();
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
};
export function Button({
  title,
  onPress,
  kind = 'primary',
  disabled = false
}) {
  return <Pressable accessibilityRole="button" disabled={disabled} onPress={onPress} style={[styles.button, kind === 'secondary' && styles.secondary, kind === 'danger' && styles.danger, disabled && styles.disabled]}><Text style={[styles.buttonText, kind === 'secondary' && styles.secondaryText, kind === 'danger' && styles.dangerText]}>{title}</Text></Pressable>;
}
export function Chip({
  title,
  onPress,
  active = false
}) {
  return <Pressable accessibilityRole="button" accessibilityState={{
    selected: active
  }} onPress={onPress} style={[styles.chip, active && styles.chipActive]}><Text style={[styles.chipText, active && styles.chipTextActive]}>{title}</Text></Pressable>;
}
export function Heading({
  title,
  subtitle,
  action
}) {
  return <View style={styles.headingRow}><View style={styles.headingMain}><Text accessibilityRole="header" style={styles.title}>{title}</Text>{subtitle ? <Text style={styles.subtitle}>{subtitle}</Text> : null}</View>{action}</View>;
}
export function Field({
  label,
  value,
  onChangeText,
  numeric = false,
  multiline = false,
  placeholder
}) {
  return <View style={styles.field}><Text style={styles.label}>{label}</Text><TextInput accessibilityLabel={label} value={String(value ?? '')} onChangeText={onChangeText} keyboardType={numeric ? 'decimal-pad' : 'default'} placeholder={placeholder} placeholderTextColor={colors.muted} multiline={multiline} style={[styles.input, multiline && styles.notes]} /></View>;
}
export function Detail({
  label,
  value
}) {
  return <View style={styles.detail}><Text style={styles.muted}>{label}</Text><Text style={styles.detailValue}>{value == null || value === '' ? '—' : String(value)}</Text></View>;
}
export function Notice({
  children
}) {
  return <View style={styles.notice}><Text style={styles.muted}>{children}</Text></View>;
}
