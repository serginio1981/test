'use strict';

// Núcleo de audio: motor, sintetizador sustractivo y utilidades de notas.

const NOTE_NAMES = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'];

function midiToFreq(m) {
  return 440 * Math.pow(2, (m - 69) / 12);
}

function midiToName(m) {
  const pc = ((m % 12) + 12) % 12;
  return NOTE_NAMES[pc] + (Math.floor(m / 12) - 1);
}

function isBlackKey(m) {
  const pc = ((m % 12) + 12) % 12;
  return pc === 1 || pc === 3 || pc === 6 || pc === 8 || pc === 10;
}

// Salida estéreo: bus seco + delay con realimentación filtrada + compresor suave.
class AudioEngine {
  constructor() {
    const Ctx = window.AudioContext || window.webkitAudioContext;
    this.ctx = new Ctx();

    this.compressor = this.ctx.createDynamicsCompressor();
    this.compressor.threshold.value = -10;
    this.compressor.knee.value = 22;
    this.compressor.ratio.value = 8;
    this.compressor.attack.value = 0.004;
    this.compressor.release.value = 0.25;

    this.masterGain = this.ctx.createGain();
    this.masterGain.gain.value = 0.8;

    this.delayInput = this.ctx.createGain();
    this.delay = this.ctx.createDelay(2.0);
    this.delay.delayTime.value = 0.32;
    this.feedback = this.ctx.createGain();
    this.feedback.gain.value = 0.34;
    this.delayTone = this.ctx.createBiquadFilter();
    this.delayTone.type = 'lowpass';
    this.delayTone.frequency.value = 2600;
    this.delayWet = this.ctx.createGain();
    this.delayWet.gain.value = 1.0;

    this.delayInput.connect(this.delay);
    this.delay.connect(this.delayTone);
    this.delayTone.connect(this.feedback);
    this.feedback.connect(this.delay);
    this.delayTone.connect(this.delayWet);
    this.delayWet.connect(this.masterGain);

    this.masterGain.connect(this.compressor);
    this.compressor.connect(this.ctx.destination);
  }

  resume() {
    if (this.ctx.state !== 'running') return this.ctx.resume();
    return Promise.resolve();
  }

  get now() {
    return this.ctx.currentTime;
  }
}

const DEFAULT_PARAMS = {
  waveform: 'sawtooth',
  voices: 1,
  detune: 14,
  attack: 0.01,
  decay: 0.2,
  sustain: 0.7,
  release: 0.25,
  cutoff: 1800,
  resonance: 6,
  filterEnv: 2200,
  filterDecay: 0.25,
  volume: 0.7,
  delaySend: 0,
};

// Voz: osciladores en unísono -> filtro pasa-bajos -> envolvente de amplitud.
class Synth {
  constructor(engine, params) {
    this.engine = engine;
    this.ctx = engine.ctx;
    this.params = Object.assign({}, DEFAULT_PARAMS, params || {});
    this.muted = false;

    this.output = this.ctx.createGain();
    this.output.gain.value = this.params.volume;
    this.output.connect(engine.masterGain);

    this.send = this.ctx.createGain();
    this.send.gain.value = this.params.delaySend;
    this.output.connect(this.send);
    this.send.connect(engine.delayInput);

    this.voices = new Map();
  }

  refresh() {
    this.output.gain.value = this.params.volume;
    this.send.gain.value = this.params.delaySend;
  }

  setParam(name, value) {
    this.params[name] = value;
    if (name === 'volume') this.output.gain.value = value;
    if (name === 'delaySend') this.send.gain.value = value;
  }

  _voice(midi, time, velocity) {
    const p = this.params;
    const freq = midiToFreq(midi);

    const amp = this.ctx.createGain();
    amp.gain.value = 0;

    const filter = this.ctx.createBiquadFilter();
    filter.type = 'lowpass';
    filter.Q.value = p.resonance;
    filter.connect(amp);
    amp.connect(this.output);

    const oscs = [];
    const n = Math.max(1, Math.min(3, p.voices | 0));
    for (let i = 0; i < n; i++) {
      const osc = this.ctx.createOscillator();
      osc.type = p.waveform;
      osc.frequency.value = freq;
      osc.detune.value = n === 1 ? 0 : (i - (n - 1) / 2) * p.detune;
      osc.connect(filter);
      osc.start(time);
      oscs.push(osc);
    }

    const peak = velocity / Math.sqrt(n);
    amp.gain.setValueAtTime(0, time);
    amp.gain.linearRampToValueAtTime(peak, time + p.attack + 0.001);
    amp.gain.linearRampToValueAtTime(peak * p.sustain, time + p.attack + p.decay + 0.002);

    const base = Math.max(p.cutoff, 40);
    const top = Math.max(Math.min(p.cutoff + p.filterEnv, 18000), 40);
    filter.frequency.setValueAtTime(top, time);
    filter.frequency.exponentialRampToValueAtTime(base, time + p.attack + p.filterDecay + 0.01);

    return { oscs, amp, filter };
  }

  _endVoice(v, time, release) {
    const rel = Math.max(release, 0.01);
    const g = v.amp.gain;
    if (g.cancelAndHoldAtTime) {
      g.cancelAndHoldAtTime(time);
    } else {
      g.cancelScheduledValues(time);
    }
    g.setTargetAtTime(0, time, rel / 3);
    const stopAt = time + rel * 1.6 + 0.12;
    v.oscs.forEach((o) => {
      try {
        o.stop(stopAt);
      } catch (e) {
        /* ya detenido */
      }
    });
    v.oscs[0].onended = () => {
      v.oscs.forEach((o) => {
        try {
          o.disconnect();
        } catch (e) {
          /* noop */
        }
      });
      try {
        v.filter.disconnect();
      } catch (e) {
        /* noop */
      }
      try {
        v.amp.disconnect();
      } catch (e) {
        /* noop */
      }
    };
  }

  noteOn(midi, when, velocity) {
    if (this.muted) return;
    const t = Math.max(when || this.engine.now, this.engine.now);
    if (this.voices.has(midi)) {
      this._endVoice(this.voices.get(midi), t, 0.03);
      this.voices.delete(midi);
    }
    this.voices.set(midi, this._voice(midi, t, velocity == null ? 0.85 : velocity));
  }

  noteOff(midi, when) {
    const v = this.voices.get(midi);
    if (!v) return;
    this.voices.delete(midi);
    this._endVoice(v, Math.max(when || this.engine.now, this.engine.now), this.params.release);
  }

  // Nota programada con duración fija (usado por el secuenciador).
  playNote(midi, time, duration, velocity) {
    if (this.muted) return;
    const v = this._voice(midi, time, velocity == null ? 0.8 : velocity);
    this._endVoice(v, time + duration, this.params.release);
  }

  playChord(midis, time, duration, velocity) {
    midis.forEach((m) => this.playNote(m, time, duration, velocity == null ? 0.5 : velocity));
  }

  allOff() {
    const t = this.engine.now;
    this.voices.forEach((v) => this._endVoice(v, t, 0.06));
    this.voices.clear();
  }
}

// ---- Batería sintetizada -------------------------------------------------
// Tres voces (kick, snare, hi-hat) totalmente sintetizadas — sin samples.
// Comparten el bus de audio del motor con los demás instrumentos.

const DEFAULT_DRUM_PARAMS = {
  kickStart: 140,
  kickEnd: 50,
  kickPitchDecay: 0.05,
  kickDecay: 0.3,
  kickLevel: 0.95,
  snareTone: 200,
  snareDecay: 0.18,
  snareNoise: 0.6,
  snareBody: 0.45,
  hihatHP: 7000,
  hihatDecay: 0.06,
  hihatLevel: 0.32,
  volume: 0.85,
  delaySend: 0,
};

class Drums {
  constructor(engine, params) {
    this.engine = engine;
    this.ctx = engine.ctx;
    this.params = Object.assign({}, DEFAULT_DRUM_PARAMS, params || {});
    this.muted = false;

    this.output = this.ctx.createGain();
    this.output.gain.value = this.params.volume;
    this.output.connect(engine.masterGain);

    this.send = this.ctx.createGain();
    this.send.gain.value = this.params.delaySend;
    this.output.connect(this.send);
    this.send.connect(engine.delayInput);
  }

  refresh() {
    this.output.gain.value = this.params.volume;
    this.send.gain.value = this.params.delaySend;
  }

  setParam(name, value) {
    this.params[name] = value;
    if (name === 'volume') this.output.gain.value = value;
    if (name === 'delaySend') this.send.gain.value = value;
  }

  _noiseBuffer(seconds) {
    const len = Math.max(1, Math.floor(this.ctx.sampleRate * seconds));
    const buf = this.ctx.createBuffer(1, len, this.ctx.sampleRate);
    const data = buf.getChannelData(0);
    for (let i = 0; i < data.length; i++) data[i] = Math.random() * 2 - 1;
    return buf;
  }

  kick(time) {
    if (this.muted) return;
    const p = this.params;
    const osc = this.ctx.createOscillator();
    osc.type = 'sine';
    const amp = this.ctx.createGain();
    osc.connect(amp);
    amp.connect(this.output);
    osc.frequency.setValueAtTime(p.kickStart, time);
    osc.frequency.exponentialRampToValueAtTime(Math.max(p.kickEnd, 20), time + p.kickPitchDecay);
    amp.gain.setValueAtTime(0, time);
    amp.gain.linearRampToValueAtTime(p.kickLevel, time + 0.003);
    amp.gain.exponentialRampToValueAtTime(0.001, time + p.kickDecay);
    osc.start(time);
    const stopAt = time + p.kickDecay + 0.05;
    osc.stop(stopAt);
    osc.onended = () => {
      try { osc.disconnect(); amp.disconnect(); } catch (e) { /* noop */ }
    };
  }

  snare(time) {
    if (this.muted) return;
    const p = this.params;
    const noise = this.ctx.createBufferSource();
    noise.buffer = this._noiseBuffer(p.snareDecay + 0.05);
    const hp = this.ctx.createBiquadFilter();
    hp.type = 'highpass';
    hp.frequency.value = 1200;
    const nGain = this.ctx.createGain();
    noise.connect(hp);
    hp.connect(nGain);
    nGain.connect(this.output);
    nGain.gain.setValueAtTime(0, time);
    nGain.gain.linearRampToValueAtTime(p.snareNoise, time + 0.002);
    nGain.gain.exponentialRampToValueAtTime(0.001, time + p.snareDecay);

    const osc = this.ctx.createOscillator();
    osc.type = 'triangle';
    osc.frequency.setValueAtTime(p.snareTone, time);
    osc.frequency.exponentialRampToValueAtTime(Math.max(p.snareTone * 0.6, 60), time + p.snareDecay * 0.6);
    const oGain = this.ctx.createGain();
    osc.connect(oGain);
    oGain.connect(this.output);
    oGain.gain.setValueAtTime(0, time);
    oGain.gain.linearRampToValueAtTime(p.snareBody, time + 0.002);
    oGain.gain.exponentialRampToValueAtTime(0.001, time + p.snareDecay * 0.6);

    const stopAt = time + p.snareDecay + 0.06;
    noise.start(time);
    noise.stop(stopAt);
    osc.start(time);
    osc.stop(stopAt);
    osc.onended = () => {
      try { noise.disconnect(); hp.disconnect(); nGain.disconnect(); osc.disconnect(); oGain.disconnect(); } catch (e) { /* noop */ }
    };
  }

  hihat(time) {
    if (this.muted) return;
    const p = this.params;
    const noise = this.ctx.createBufferSource();
    noise.buffer = this._noiseBuffer(p.hihatDecay + 0.04);
    const hp = this.ctx.createBiquadFilter();
    hp.type = 'highpass';
    hp.frequency.value = p.hihatHP;
    const gain = this.ctx.createGain();
    noise.connect(hp);
    hp.connect(gain);
    gain.connect(this.output);
    gain.gain.setValueAtTime(0, time);
    gain.gain.linearRampToValueAtTime(p.hihatLevel, time + 0.001);
    gain.gain.exponentialRampToValueAtTime(0.001, time + p.hihatDecay);
    const stopAt = time + p.hihatDecay + 0.04;
    noise.start(time);
    noise.stop(stopAt);
    noise.onended = () => {
      try { noise.disconnect(); hp.disconnect(); gain.disconnect(); } catch (e) { /* noop */ }
    };
  }

  // Métodos para uniformidad con Synth (los disparos son cortos y sin sostén).
  allOff() {}
  noteOn() {}
  noteOff() {}
  playNote() {}
  playChord() {}
}
