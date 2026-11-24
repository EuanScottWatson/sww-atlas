import { StyleSheet } from 'react-native';
export const colors = {
  bg: '#071526',
  panel: '#0d2031',
  text: '#eef8fb',
  muted: '#a2b6c3',
  line: '#294253',
  accent: '#21d6dc',
  danger: '#ff8b80',
  dark: '#001d24'
};
export const styles = StyleSheet.create({
  safe: {
    flex: 1,
    backgroundColor: colors.bg
  },
  flex: {
    flex: 1
  },
  header: {
    paddingHorizontal: 20,
    paddingTop: 12,
    paddingBottom: 14,
    borderBottomWidth: 1,
    borderColor: colors.line,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between'
  },
  brand: {
    fontSize: 12,
    fontWeight: '800',
    letterSpacing: 1.4,
    color: colors.text
  },
  brandAccent: {
    color: colors.accent
  },
  headerMeta: {
    fontSize: 11,
    color: colors.muted
  },
  content: {
    paddingHorizontal: 20,
    paddingTop: 21,
    paddingBottom: 45
  },
  title: {
    fontSize: 34,
    lineHeight: 41,
    letterSpacing: -1,
    fontWeight: '800',
    color: colors.text
  },
  subtitle: {
    fontSize: 13,
    color: colors.muted,
    marginTop: 4,
    lineHeight: 19
  },
  headingRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    gap: 10,
    marginBottom: 20
  },
  headingMain: {
    flex: 1
  },
  section: {
    fontSize: 12,
    fontWeight: '800',
    letterSpacing: .8,
    textTransform: 'uppercase',
    color: colors.text,
    marginTop: 25,
    marginBottom: 12
  },
  body: {
    fontSize: 15,
    color: colors.text,
    lineHeight: 22
  },
  muted: {
    fontSize: 13,
    color: colors.muted,
    lineHeight: 20
  },
  tiny: {
    fontSize: 11,
    color: colors.muted,
    lineHeight: 16
  },
  error: {
    fontSize: 13,
    color: colors.danger,
    lineHeight: 19
  },
  button: {
    backgroundColor: colors.accent,
    borderRadius: 5,
    paddingHorizontal: 15,
    paddingVertical: 12,
    minHeight: 44,
    justifyContent: 'center',
    alignItems: 'center'
  },
  buttonText: {
    color: colors.dark,
    fontSize: 14,
    fontWeight: '800'
  },
  secondary: {
    backgroundColor: colors.panel,
    borderWidth: 1,
    borderColor: colors.line
  },
  secondaryText: {
    color: colors.text
  },
  danger: {
    backgroundColor: 'transparent',
    borderWidth: 1,
    borderColor: colors.danger
  },
  dangerText: {
    color: colors.danger
  },
  disabled: {
    opacity: .55
  },
  toolbar: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
    marginBottom: 12
  },
  input: {
    backgroundColor: colors.panel,
    color: colors.text,
    borderColor: colors.line,
    borderWidth: 1,
    borderRadius: 5,
    paddingHorizontal: 12,
    paddingVertical: 10,
    minHeight: 44,
    fontSize: 15
  },
  search: {
    flex: 1
  },
  field: {
    marginBottom: 16
  },
  label: {
    fontSize: 12,
    color: colors.muted,
    fontWeight: '700',
    marginBottom: 6
  },
  notes: {
    height: 100,
    textAlignVertical: 'top'
  },
  row: {
    borderBottomWidth: 1,
    borderColor: colors.line,
    paddingVertical: 15,
    flexDirection: 'row',
    alignItems: 'center',
    gap: 10
  },
  rowMain: {
    flex: 1
  },
  rowTitle: {
    fontSize: 15,
    color: colors.text,
    fontWeight: '700'
  },
  rowValue: {
    fontSize: 14,
    color: colors.text,
    fontWeight: '700',
    textAlign: 'right'
  },
  link: {
    color: colors.accent,
    fontSize: 14,
    fontWeight: '700'
  },
  chips: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 8,
    marginBottom: 12
  },
  chip: {
    borderWidth: 1,
    borderColor: colors.line,
    borderRadius: 5,
    paddingHorizontal: 11,
    paddingVertical: 9,
    minHeight: 40,
    justifyContent: 'center'
  },
  chipActive: {
    borderColor: colors.accent,
    backgroundColor: colors.panel
  },
  chipText: {
    fontSize: 12,
    color: colors.muted
  },
  chipTextActive: {
    color: colors.accent,
    fontWeight: '700'
  },
  statGrid: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    borderTopWidth: 1,
    borderColor: colors.line
  },
  stat: {
    width: '50%',
    paddingVertical: 16,
    borderBottomWidth: 1,
    borderColor: colors.line
  },
  statNum: {
    fontWeight: '800',
    fontSize: 25,
    color: colors.accent,
    letterSpacing: -.5
  },
  statLabel: {
    fontSize: 12,
    color: colors.muted,
    marginTop: 4
  },
  detail: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingVertical: 13,
    borderBottomWidth: 1,
    borderColor: colors.line,
    gap: 15
  },
  detailValue: {
    color: colors.text,
    fontSize: 14,
    fontWeight: '600',
    textAlign: 'right',
    flexShrink: 1
  },
  nav: {
    flexDirection: 'row',
    borderTopWidth: 1,
    borderColor: colors.line,
    backgroundColor: colors.bg,
    paddingBottom: 4
  },
  tab: {
    flex: 1,
    minHeight: 57,
    alignItems: 'center',
    justifyContent: 'center',
    gap: 2
  },
  tabText: {
    fontSize: 11,
    color: colors.muted
  },
  tabActive: {
    color: colors.accent,
    fontWeight: '800'
  },
  tabIcon: {
    fontSize: 19,
    color: colors.muted
  },
  notice: {
    backgroundColor: colors.panel,
    borderLeftWidth: 3,
    borderColor: colors.accent,
    padding: 14,
    marginBottom: 15
  },
  map: {
    height: 380,
    borderRadius: 6,
    marginBottom: 12
  },
  calendarGrid: {
    flexDirection: 'row',
    flexWrap: 'wrap'
  },
  calendarDay: {
    width: '14.2857%',
    height: 48,
    alignItems: 'center',
    justifyContent: 'center',
    borderWidth: .5,
    borderColor: colors.line
  },
  calendarDayText: {
    color: colors.text,
    fontSize: 14
  },
  calendarSelected: {
    backgroundColor: colors.accent
  },
  calendarSelectedText: {
    color: colors.dark,
    fontWeight: '800'
  },
  calendarDot: {
    width: 5,
    height: 5,
    borderRadius: 3,
    backgroundColor: colors.accent,
    marginTop: 4
  },
  barRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
    marginBottom: 9
  },
  barLabel: {
    color: colors.muted,
    fontSize: 11,
    width: 38
  },
  barTrack: {
    height: 14,
    backgroundColor: colors.panel,
    flex: 1
  },
  barFill: {
    height: 14,
    backgroundColor: colors.accent
  },
  barValue: {
    color: colors.text,
    fontSize: 11,
    width: 62,
    textAlign: 'right'
  },
  spacer: {
    height: 15
  },
  inline: {
    flexDirection: 'row',
    gap: 9,
    alignItems: 'center'
  },
  half: {
    flex: 1
  },
  divider: {
    height: 1,
    backgroundColor: colors.line,
    marginVertical: 15
  }
});
