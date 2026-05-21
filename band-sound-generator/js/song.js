'use strict';

// Datos de la canción «Estrechez de Corazón» (Los Prisioneros).
// Interpretación editable en Mi menor · progresión Em – C – G – D.
// El secuenciador trabaja con 32 pasos = 4 compases de corcheas en 4/4.

const CHORD_LIBRARY = [
  { name: 'Em', notes: [52, 55, 59] },
  { name: 'C', notes: [48, 52, 55] },
  { name: 'G', notes: [50, 55, 59] },
  { name: 'D', notes: [50, 54, 57] },
  { name: 'Am', notes: [48, 52, 57] },
  { name: 'Bm', notes: [50, 54, 59] },
  { name: 'A', notes: [49, 52, 57] },
  { name: 'B', notes: [51, 54, 59] },
  { name: 'F#m', notes: [49, 54, 57] },
  { name: 'D7', notes: [50, 54, 57, 60] },
  { name: 'G7', notes: [50, 53, 55, 59] },
  { name: 'Cmaj7', notes: [48, 52, 55, 59] },
  { name: 'Em7', notes: [50, 52, 55, 59] },
  { name: 'A7', notes: [49, 52, 55, 57] },
];

function chordNotes(name) {
  const c = CHORD_LIBRARY.find((x) => x.name === name);
  return c ? c.notes.slice() : [];
}

const DEFAULT_SONG = {
  bpm: 144,
  steps: 32,
  // Bajo motor en corcheas con saltos de octava (null = silencio).
  bass: [
    40, null, 40, 40, 35, null, 40, 43,
    36, null, 36, 36, 31, null, 36, 40,
    31, null, 31, 43, 38, null, 31, 35,
    38, null, 38, 38, 33, null, 38, 42,
  ],
  // Riff de sintetizador lead sobre la progresión.
  lead: [
    64, 67, null, 71, null, 69, 67, null,
    64, null, 67, 64, null, 67, 69, null,
    71, null, 74, 71, 67, null, 69, 71,
    69, null, 66, 69, 62, null, 66, null,
  ],
  // Un acorde por compás (8 pasos).
  chords: ['Em', 'C', 'G', 'D'],
};

// Patches iniciales de cada sintetizador.
const DEFAULT_PATCHES = {
  keyboard: {
    waveform: 'sawtooth', voices: 2, detune: 14,
    attack: 0.01, decay: 0.25, sustain: 0.65, release: 0.35,
    cutoff: 1700, resonance: 8, filterEnv: 2600, filterDecay: 0.3,
    volume: 0.7, delaySend: 0.3,
  },
  bass: {
    waveform: 'sawtooth', voices: 1, detune: 0,
    attack: 0.005, decay: 0.12, sustain: 0.5, release: 0.12,
    cutoff: 600, resonance: 7, filterEnv: 1400, filterDecay: 0.14,
    volume: 0.85, delaySend: 0,
  },
  lead: {
    waveform: 'sawtooth', voices: 2, detune: 16,
    attack: 0.01, decay: 0.18, sustain: 0.55, release: 0.3,
    cutoff: 1500, resonance: 9, filterEnv: 3200, filterDecay: 0.2,
    volume: 0.6, delaySend: 0.45,
  },
  chord: {
    waveform: 'square', voices: 2, detune: 10,
    attack: 0.06, decay: 0.4, sustain: 0.7, release: 0.4,
    cutoff: 1300, resonance: 4, filterEnv: 900, filterDecay: 0.5,
    volume: 0.38, delaySend: 0.2,
  },
};
