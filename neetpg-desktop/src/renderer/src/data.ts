// Subject colour map — subtle tints over a mostly-monochrome dark base.
// Covers all 19 NEET-PG subjects; falls back to a neutral grey otherwise.
export const SUBJECT_COLORS: Record<string, { color: string; dim: string; label: string }> = {
  anatomy: { color: '#5bb8c4', dim: 'rgba(91,184,196,0.10)', label: 'Anatomy' },
  physiology: { color: '#5bc48a', dim: 'rgba(91,196,138,0.10)', label: 'Physiology' },
  biochemistry: { color: '#e0a84c', dim: 'rgba(224,168,76,0.10)', label: 'Biochemistry' },
  pathology: { color: '#c46b8a', dim: 'rgba(196,107,138,0.10)', label: 'Pathology' },
  microbiology: { color: '#9b7ce8', dim: 'rgba(155,124,232,0.10)', label: 'Microbiology' },
  pharmacology: { color: '#7b8cef', dim: 'rgba(123,140,239,0.10)', label: 'Pharmacology' },
  'forensic-medicine': { color: '#b07a5b', dim: 'rgba(176,122,91,0.10)', label: 'Forensic' },
  'community-medicine': { color: '#6abf9a', dim: 'rgba(106,191,154,0.10)', label: 'Community Med' },
  medicine: { color: '#6b8cef', dim: 'rgba(107,140,239,0.10)', label: 'Medicine' },
  surgery: { color: '#d98a6b', dim: 'rgba(217,138,107,0.10)', label: 'Surgery' },
  'obstetrics-gynaecology': { color: '#d57ab0', dim: 'rgba(213,122,176,0.10)', label: 'OBG' },
  pediatrics: { color: '#7ac4d5', dim: 'rgba(122,196,213,0.10)', label: 'Paediatrics' },
  orthopaedics: { color: '#8a9bc4', dim: 'rgba(138,155,196,0.10)', label: 'Orthopaedics' },
  ent: { color: '#5bbcb0', dim: 'rgba(91,188,176,0.10)', label: 'ENT' },
  ophthalmology: { color: '#6b9bef', dim: 'rgba(107,155,239,0.10)', label: 'Ophthalmology' },
  dermatology: { color: '#e0976b', dim: 'rgba(224,151,107,0.10)', label: 'Dermatology' },
  psychiatry: { color: '#a78ce8', dim: 'rgba(167,140,232,0.10)', label: 'Psychiatry' },
  radiology: { color: '#8a90a8', dim: 'rgba(138,144,168,0.10)', label: 'Radiology' },
  anaesthesia: { color: '#5bc4a8', dim: 'rgba(91,196,168,0.10)', label: 'Anaesthesia' },
  general: { color: '#8a90a8', dim: 'rgba(138,144,168,0.10)', label: 'General' }
}

export function subjectInfo(subject: string): { color: string; dim: string; label: string } {
  return SUBJECT_COLORS[subject] || SUBJECT_COLORS.general
}

export const SR_STATUS_LABELS: Record<string, { label: string; color: string }> = {
  new: { label: 'New', color: '#7a80a0' },
  learning: { label: 'Learning', color: '#f0b449' },
  review: { label: 'Review', color: '#6b8cef' },
  relearning: { label: 'Relearning', color: '#ef6b6b' },
  mature: { label: 'Mature', color: '#4ecb8d' }
}

export const ICONS: Record<string, string> = {
  ambient: `<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="4"/><path d="M12 2v2m0 16v2M4.93 4.93l1.41 1.41m11.32 11.32l1.41 1.41M2 12h2m16 0h2M6.34 17.66l-1.41 1.41M19.07 4.93l-1.41 1.41"/></svg>`,
  dashboard: `<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="3" width="7" height="9" rx="1.5"/><rect x="14" y="3" width="7" height="5" rx="1.5"/><rect x="3" y="16" width="7" height="5" rx="1.5"/><rect x="14" y="12" width="7" height="9" rx="1.5"/></svg>`,
  settings: `<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="3"/><path d="M19.4 15a1.65 1.65 0 00.33 1.82l.06.06a2 2 0 01-2.83 2.83l-.06-.06a1.65 1.65 0 00-1.82-.33 1.65 1.65 0 00-1 1.51V21a2 2 0 01-4 0v-.09A1.65 1.65 0 009 19.4a1.65 1.65 0 00-1.82.33l-.06.06a2 2 0 01-2.83-2.83l.06-.06A1.65 1.65 0 004.68 15a1.65 1.65 0 00-1.51-1H3a2 2 0 010-4h.09A1.65 1.65 0 004.6 9a1.65 1.65 0 00-.33-1.82l-.06-.06a2 2 0 012.83-2.83l.06.06A1.65 1.65 0 009 4.68a1.65 1.65 0 001-1.51V3a2 2 0 014 0v.09a1.65 1.65 0 001 1.51 1.65 1.65 0 001.82-.33l.06-.06a2 2 0 012.83 2.83l-.06.06A1.65 1.65 0 0019.4 9a1.65 1.65 0 001.51 1H21a2 2 0 010 4h-.09a1.65 1.65 0 00-1.51 1z"/></svg>`,
  quiz: `<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M9.09 9a3 3 0 015.83 1c0 2-3 3-3 3"/><circle cx="12" cy="12" r="10"/><line x1="12" y1="17" x2="12.01" y2="17"/></svg>`,
  image: `<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="3" width="18" height="18" rx="2"/><circle cx="8.5" cy="8.5" r="1.5"/><path d="M21 15l-5-5L5 21"/></svg>`,
  pause: `<svg width="18" height="18" viewBox="0 0 24 24" fill="currentColor"><rect x="6" y="4" width="4" height="16" rx="1"/><rect x="14" y="4" width="4" height="16" rx="1"/></svg>`,
  play: `<svg width="18" height="18" viewBox="0 0 24 24" fill="currentColor"><path d="M8 5v14l11-7z"/></svg>`,
  prev: `<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><polyline points="15 18 9 12 15 6"/></svg>`,
  next: `<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><polyline points="9 6 15 12 9 18"/></svg>`,
  sync: `<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><polyline points="23 4 23 10 17 10"/><polyline points="1 20 1 14 7 14"/><path d="M3.51 9a9 9 0 0114.85-3.36L23 10M1 14l4.64 4.36A9 9 0 0020.49 15"/></svg>`,
  check: `<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round"><polyline points="20 6 9 17 4 12"/></svg>`,
  x: `<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>`,
  clock: `<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"><circle cx="12" cy="12" r="10"/><polyline points="12 6 12 12 16 14"/></svg>`,
  minimize: `<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><line x1="5" y1="12" x2="19" y2="12"/></svg>`,
  menu: `<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"><line x1="4" y1="7" x2="20" y2="7"/><line x1="4" y1="12" x2="20" y2="12"/><line x1="4" y1="17" x2="20" y2="17"/></svg>`,
  collapse: `<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><polyline points="15 18 9 12 15 6"/></svg>`
}

export const ANIM_MS = { slow: 1000, normal: 600, fast: 300 } as const
