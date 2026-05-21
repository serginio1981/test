'use strict';

// Transporte y planificador del secuenciador.
// Usa el patrón clásico de Web Audio: un temporizador impreciso programa
// notas con antelación contra el reloj de muestreo (preciso) del AudioContext.
class Sequencer {
  constructor(engine, synths, song) {
    this.engine = engine;
    this.synths = synths; // { bass, lead, chord }
    this.song = song;
    this.bpm = song.bpm;
    this.isPlaying = false;
    this.currentStep = 0;
    this.nextTime = 0;
    this.lookAhead = 0.12;
    this.timer = null;
    this.queue = []; // { step, time } pendiente de mostrar
  }

  get stepDur() {
    return 60 / this.bpm / 2; // corchea
  }

  start() {
    if (this.isPlaying) return;
    this.isPlaying = true;
    this.currentStep = 0;
    this.nextTime = this.engine.now + 0.08;
    this.queue.length = 0;
    this.timer = setInterval(() => this._tick(), 25);
  }

  stop() {
    if (!this.isPlaying) return;
    this.isPlaying = false;
    if (this.timer) clearInterval(this.timer);
    this.timer = null;
    this.queue.length = 0;
    Object.values(this.synths).forEach((s) => s.allOff());
  }

  _tick() {
    const horizon = this.engine.now + this.lookAhead;
    while (this.nextTime < horizon) {
      this._scheduleStep(this.currentStep, this.nextTime);
      this.queue.push({ step: this.currentStep, time: this.nextTime });
      this.nextTime += this.stepDur;
      this.currentStep = (this.currentStep + 1) % this.song.steps;
    }
  }

  _scheduleStep(step, time) {
    const d = this.stepDur;
    const s = this.song;

    const b = s.bass[step];
    if (b != null && b >= 0) this.synths.bass.playNote(b, time, d * 0.92);

    const l = s.lead[step];
    if (l != null && l >= 0) this.synths.lead.playNote(l, time, d * 0.88);

    const stepsPerBar = s.steps / s.chords.length;
    if (step % stepsPerBar === 0) {
      const notes = chordNotes(s.chords[step / stepsPerBar]);
      if (notes.length) this.synths.chord.playChord(notes, time, d * stepsPerBar * 0.96);
    }
  }

  // Devuelve el paso visible más reciente ya sonando, o null.
  drainVisual() {
    const now = this.engine.now;
    let step = null;
    while (this.queue.length && this.queue[0].time <= now) {
      step = this.queue.shift().step;
    }
    return step;
  }
}
