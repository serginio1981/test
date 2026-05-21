'use strict';

// Orquestación de la interfaz: transporte, piano roll, acordes,
// panel del sintetizador, teclado tocable y persistencia local.
(function () {
  const STORE_KEY = 'band-sound-generator:v1';

  const engine = new AudioEngine();
  const synths = {
    keyboard: new Synth(engine, DEFAULT_PATCHES.keyboard),
    bass: new Synth(engine, DEFAULT_PATCHES.bass),
    lead: new Synth(engine, DEFAULT_PATCHES.lead),
    chord: new Synth(engine, DEFAULT_PATCHES.chord),
  };

  let song = clone(DEFAULT_SONG);
  const sequencer = new Sequencer(engine, synths, song);

  const ROLLS = {
    lead: { low: 57, high: 81 },
    bass: { low: 28, high: 52 },
  };
  const rollState = {};
  let chordSlots = [];
  let currentPatch = 'keyboard';

  const KEY_LABELS = { keyboard: 'Teclado', bass: 'Bajo', lead: 'Lead', chord: 'Acordes' };

  function clone(o) {
    return JSON.parse(JSON.stringify(o));
  }
  function $(id) {
    return document.getElementById(id);
  }

  // ---------- persistencia ----------
  function saveState() {
    try {
      const patches = {};
      Object.keys(synths).forEach((k) => {
        patches[k] = synths[k].params;
      });
      localStorage.setItem(STORE_KEY, JSON.stringify({ song, patches }));
    } catch (e) {
      /* almacenamiento no disponible */
    }
  }

  function loadState() {
    try {
      const raw = localStorage.getItem(STORE_KEY);
      if (!raw) return;
      const data = JSON.parse(raw);
      if (data.song && Array.isArray(data.song.bass)) song = data.song;
      if (data.patches) {
        Object.keys(synths).forEach((k) => {
          if (data.patches[k]) {
            synths[k].params = Object.assign({}, DEFAULT_PARAMS, data.patches[k]);
            synths[k].refresh();
          }
        });
      }
    } catch (e) {
      /* datos corruptos: se ignoran */
    }
  }

  // ---------- piano roll ----------
  function buildRoll(track) {
    const { low, high } = ROLLS[track];
    const host = $('roll-' + track);
    host.innerHTML = '';
    host.className = 'roll';

    const labels = document.createElement('div');
    labels.className = 'roll-labels';
    const grid = document.createElement('div');
    grid.className = 'roll-grid';
    grid.style.gridTemplateColumns = 'repeat(' + song.steps + ', 1fr)';

    const cells = [];
    for (let midi = high; midi >= low; midi--) {
      const lab = document.createElement('div');
      lab.className = 'rlabel' + (midi % 12 === 0 ? ' c' : '');
      lab.textContent = midiToName(midi);
      labels.appendChild(lab);

      const row = [];
      for (let step = 0; step < song.steps; step++) {
        const cell = document.createElement('div');
        cell.className = 'cell';
        if (isBlackKey(midi)) cell.classList.add('blk');
        if (midi % 12 === 0) cell.classList.add('cline');
        if (step % 8 === 0) cell.classList.add('bar');
        cell.dataset.midi = midi;
        cell.dataset.step = step;
        cell.dataset.track = track;
        cell.title = midiToName(midi);
        cell.addEventListener('pointerdown', onCellDown);
        grid.appendChild(cell);
        row.push(cell);
      }
      cells.push(row);
    }

    const ph = document.createElement('div');
    ph.className = 'playhead';
    ph.style.width = 100 / song.steps + '%';
    grid.appendChild(ph);

    host.appendChild(labels);
    host.appendChild(grid);
    rollState[track] = { low, high, cells, playhead: ph };
    refreshRoll(track);
  }

  function refreshRoll(track) {
    const st = rollState[track];
    const data = song[track];
    for (let step = 0; step < song.steps; step++) {
      for (let r = 0; r < st.cells.length; r++) {
        st.cells[r][step].classList.remove('on');
      }
      const note = data[step];
      if (note != null && note >= 0) {
        const r = st.high - note;
        if (r >= 0 && r < st.cells.length) st.cells[r][step].classList.add('on');
      }
    }
  }

  function onCellDown(e) {
    e.preventDefault();
    const cell = e.currentTarget;
    const midi = +cell.dataset.midi;
    const step = +cell.dataset.step;
    const track = cell.dataset.track;
    engine.resume();
    if (song[track][step] === midi) {
      song[track][step] = null;
    } else {
      song[track][step] = midi;
      synths[track].playNote(midi, engine.now, 0.32, 0.8);
    }
    refreshRoll(track);
    saveState();
  }

  // ---------- acordes ----------
  function buildChords() {
    const row = $('chord-row');
    row.innerHTML = '';
    chordSlots = [];
    song.chords.forEach((name, i) => {
      const slot = document.createElement('div');
      slot.className = 'chord-slot';

      const label = document.createElement('div');
      label.className = 'chord-bar';
      label.textContent = 'Compás ' + (i + 1);

      const sel = document.createElement('select');
      CHORD_LIBRARY.forEach((c) => {
        const opt = document.createElement('option');
        opt.value = c.name;
        opt.textContent = c.name;
        if (c.name === name) opt.selected = true;
        sel.appendChild(opt);
      });
      sel.addEventListener('change', () => {
        song.chords[i] = sel.value;
        engine.resume();
        synths.chord.playChord(chordNotes(sel.value), engine.now, 0.7);
        saveState();
      });

      slot.appendChild(label);
      slot.appendChild(sel);
      row.appendChild(slot);
      chordSlots.push(slot);
    });
  }

  // ---------- panel del sintetizador ----------
  const WAVE_LABELS = { sine: 'Senoidal', triangle: 'Triangular', sawtooth: 'Sierra', square: 'Cuadrada' };
  const CONTROLS = [
    { param: 'waveform', label: 'Forma de onda', type: 'wave' },
    { param: 'voices', label: 'Voces (unísono)', min: 1, max: 3, step: 1 },
    { param: 'detune', label: 'Desafine', min: 0, max: 50, step: 1, unit: ' ¢' },
    { param: 'attack', label: 'Ataque', min: 0, max: 2, step: 0.01, unit: ' s' },
    { param: 'decay', label: 'Caída', min: 0, max: 2, step: 0.01, unit: ' s' },
    { param: 'sustain', label: 'Sostén', min: 0, max: 1, step: 0.01 },
    { param: 'release', label: 'Liberación', min: 0, max: 3, step: 0.01, unit: ' s' },
    { param: 'cutoff', label: 'Filtro · corte', min: 80, max: 12000, step: 20, unit: ' Hz' },
    { param: 'resonance', label: 'Resonancia', min: 0, max: 22, step: 0.5 },
    { param: 'filterEnv', label: 'Envolvente de filtro', min: 0, max: 8000, step: 50, unit: ' Hz' },
    { param: 'filterDecay', label: 'Caída del filtro', min: 0.02, max: 2, step: 0.01, unit: ' s' },
    { param: 'volume', label: 'Volumen', min: 0, max: 1, step: 0.01 },
    { param: 'delaySend', label: 'Envío a delay', min: 0, max: 1, step: 0.01 },
  ];

  function buildPatchTabs() {
    const tabs = $('patch-tabs');
    tabs.innerHTML = '';
    Object.keys(KEY_LABELS).forEach((key) => {
      const btn = document.createElement('button');
      btn.className = 'tab' + (key === currentPatch ? ' active' : '');
      btn.textContent = KEY_LABELS[key];
      btn.dataset.synth = key;
      btn.addEventListener('click', () => {
        currentPatch = key;
        Array.prototype.forEach.call(tabs.children, (c) => {
          c.classList.toggle('active', c.dataset.synth === key);
        });
        syncPatchPanel();
      });
      tabs.appendChild(btn);
    });
  }

  function buildPatchControls() {
    const host = $('patch-controls');
    host.innerHTML = '';
    CONTROLS.forEach((c) => {
      const wrap = document.createElement('div');
      wrap.className = 'ctl';

      const top = document.createElement('div');
      top.className = 'ctl-top';
      const label = document.createElement('label');
      label.textContent = c.label;
      const val = document.createElement('span');
      val.className = 'val';
      val.dataset.for = c.param;
      top.appendChild(label);
      top.appendChild(val);
      wrap.appendChild(top);

      if (c.type === 'wave') {
        const sel = document.createElement('select');
        Object.keys(WAVE_LABELS).forEach((w) => {
          const opt = document.createElement('option');
          opt.value = w;
          opt.textContent = WAVE_LABELS[w];
          sel.appendChild(opt);
        });
        sel.dataset.param = c.param;
        sel.addEventListener('change', () => {
          synths[currentPatch].setParam('waveform', sel.value);
          saveState();
          syncPatchPanel();
        });
        wrap.appendChild(sel);
      } else {
        const input = document.createElement('input');
        input.type = 'range';
        input.min = c.min;
        input.max = c.max;
        input.step = c.step;
        input.dataset.param = c.param;
        input.addEventListener('input', () => {
          synths[currentPatch].setParam(c.param, parseFloat(input.value));
          updateControlValue(c, val);
          saveState();
        });
        wrap.appendChild(input);
      }
      host.appendChild(wrap);
    });
  }

  function updateControlValue(c, valEl) {
    const v = synths[currentPatch].params[c.param];
    if (c.type === 'wave') {
      valEl.textContent = WAVE_LABELS[v] || v;
    } else if (c.step >= 1) {
      valEl.textContent = Math.round(v) + (c.unit || '');
    } else {
      valEl.textContent = v.toFixed(2) + (c.unit || '');
    }
  }

  function syncPatchPanel() {
    const host = $('patch-controls');
    CONTROLS.forEach((c) => {
      const v = synths[currentPatch].params[c.param];
      const field = host.querySelector('[data-param="' + c.param + '"]');
      if (field) field.value = v;
      const valEl = host.querySelector('.val[data-for="' + c.param + '"]');
      if (valEl) updateControlValue(c, valEl);
    });
  }

  // ---------- teclado tocable ----------
  const KEYMAP = {
    z: 0, s: 1, x: 2, d: 3, c: 4, v: 5, g: 6, b: 7, h: 8, n: 9, j: 10, m: 11, ',': 12,
    q: 12, 2: 13, w: 14, 3: 15, e: 16, r: 17, 5: 18, t: 19, 6: 20, y: 21, 7: 22, u: 23, i: 24,
  };
  let kbBase = 60;
  const keyEls = {};
  const pressedKeys = new Set();
  let mouseNote = null;

  function buildKeyboard() {
    const kb = $('keyboard');
    kb.innerHTML = '';
    Object.keys(keyEls).forEach((k) => delete keyEls[k]);

    const midis = [];
    for (let m = kbBase; m <= kbBase + 24; m++) midis.push(m);
    const whiteCount = midis.filter((m) => !isBlackKey(m)).length;
    const whiteW = 100 / whiteCount;

    midis.forEach((m) => {
      if (isBlackKey(m)) return;
      const k = document.createElement('div');
      k.className = 'wkey';
      k.style.width = whiteW + '%';
      const lab = document.createElement('span');
      lab.className = 'klabel';
      lab.textContent = midiToName(m);
      k.appendChild(lab);
      attachKey(k, m);
      kb.appendChild(k);
      keyEls[m] = k;
    });

    let whitesBefore = 0;
    midis.forEach((m) => {
      if (!isBlackKey(m)) {
        whitesBefore++;
        return;
      }
      const k = document.createElement('div');
      k.className = 'bkey';
      const bw = whiteW * 0.62;
      k.style.width = bw + '%';
      k.style.left = whitesBefore * whiteW - bw / 2 + '%';
      attachKey(k, m);
      kb.appendChild(k);
      keyEls[m] = k;
    });

    $('octLabel').textContent = midiToName(kbBase) + ' – ' + midiToName(kbBase + 24);
  }

  function attachKey(el, midi) {
    el.addEventListener('pointerdown', (e) => {
      e.preventDefault();
      engine.resume();
      if (el.setPointerCapture) {
        try {
          el.setPointerCapture(e.pointerId);
        } catch (err) {
          /* noop */
        }
      }
      mouseNote = midi;
      kbDown(midi);
    });
    el.addEventListener('pointerup', () => {
      if (mouseNote != null) {
        kbUp(mouseNote);
        mouseNote = null;
      }
    });
  }

  function kbDown(midi) {
    synths.keyboard.noteOn(midi);
    if (keyEls[midi]) keyEls[midi].classList.add('active');
  }

  function kbUp(midi) {
    synths.keyboard.noteOff(midi);
    if (keyEls[midi]) keyEls[midi].classList.remove('active');
  }

  function shiftOctave(d) {
    const next = Math.max(24, Math.min(84, kbBase + 12 * d));
    if (next === kbBase) return;
    synths.keyboard.allOff();
    pressedKeys.clear();
    mouseNote = null;
    kbBase = next;
    buildKeyboard();
  }

  // ---------- transporte ----------
  function togglePlay() {
    engine.resume();
    if (sequencer.isPlaying) {
      sequencer.stop();
      hidePlayheads();
    } else {
      sequencer.start();
    }
    updatePlayButton();
  }

  function updatePlayButton() {
    const btn = $('play');
    btn.textContent = sequencer.isPlaying ? '■ Detener' : '▶ Reproducir';
    btn.classList.toggle('playing', sequencer.isPlaying);
  }

  function setPlayheads(step) {
    const x = (step / song.steps) * 100;
    Object.keys(rollState).forEach((t) => {
      const ph = rollState[t].playhead;
      ph.style.left = x + '%';
      ph.style.display = 'block';
    });
    const bar = Math.floor(step / (song.steps / song.chords.length));
    chordSlots.forEach((s, i) => s.classList.toggle('active', i === bar));
  }

  function hidePlayheads() {
    Object.keys(rollState).forEach((t) => {
      rollState[t].playhead.style.display = 'none';
    });
    chordSlots.forEach((s) => s.classList.remove('active'));
  }

  // ---------- reconstrucción global ----------
  function rebuildAll() {
    sequencer.song = song;
    sequencer.bpm = song.bpm;
    buildChords();
    buildRoll('lead');
    buildRoll('bass');
    syncPatchPanel();
    $('bpm').value = song.bpm;
    $('bpmVal').textContent = song.bpm + ' BPM';
    refreshMuteButtons();
  }

  function refreshMuteButtons() {
    document.querySelectorAll('[data-mute]').forEach((btn) => {
      const muted = synths[btn.dataset.mute].muted;
      btn.classList.toggle('on', muted);
      btn.textContent = muted ? 'Silenciado' : 'Silenciar';
    });
  }

  function resetSong() {
    const wasPlaying = sequencer.isPlaying;
    sequencer.stop();
    hidePlayheads();
    updatePlayButton();
    song = clone(DEFAULT_SONG);
    Object.keys(synths).forEach((k) => {
      synths[k].params = Object.assign({}, DEFAULT_PARAMS, DEFAULT_PATCHES[k]);
      synths[k].muted = false;
      synths[k].refresh();
    });
    rebuildAll();
    saveState();
    if (wasPlaying) {
      sequencer.start();
      updatePlayButton();
    }
  }

  // ---------- conexiones de la interfaz ----------
  function wireTransport() {
    $('play').addEventListener('click', togglePlay);

    const bpm = $('bpm');
    bpm.addEventListener('input', () => {
      const v = parseInt(bpm.value, 10);
      sequencer.bpm = v;
      song.bpm = v;
      $('bpmVal').textContent = v + ' BPM';
      saveState();
    });

    const master = $('master');
    master.value = engine.masterGain.gain.value;
    $('masterVal').textContent = Math.round(master.value * 100) + '%';
    master.addEventListener('input', () => {
      engine.masterGain.gain.value = parseFloat(master.value);
      $('masterVal').textContent = Math.round(master.value * 100) + '%';
    });

    const dTime = $('delayTime');
    dTime.value = engine.delay.delayTime.value;
    $('delayTimeVal').textContent = Math.round(dTime.value * 1000) + ' ms';
    dTime.addEventListener('input', () => {
      engine.delay.delayTime.setTargetAtTime(parseFloat(dTime.value), engine.now, 0.05);
      $('delayTimeVal').textContent = Math.round(dTime.value * 1000) + ' ms';
    });

    const dFb = $('delayFb');
    dFb.value = engine.feedback.gain.value;
    $('delayFbVal').textContent = Math.round(dFb.value * 100) + '%';
    dFb.addEventListener('input', () => {
      engine.feedback.gain.value = parseFloat(dFb.value);
      $('delayFbVal').textContent = Math.round(dFb.value * 100) + '%';
    });

    $('reset').addEventListener('click', resetSong);
    $('octDown').addEventListener('click', () => shiftOctave(-1));
    $('octUp').addEventListener('click', () => shiftOctave(1));

    document.querySelectorAll('[data-mute]').forEach((btn) => {
      btn.addEventListener('click', () => {
        const s = synths[btn.dataset.mute];
        s.muted = !s.muted;
        if (s.muted) s.allOff();
        refreshMuteButtons();
      });
    });

    document.querySelectorAll('[data-clear]').forEach((btn) => {
      btn.addEventListener('click', () => {
        const track = btn.dataset.clear;
        song[track] = new Array(song.steps).fill(null);
        refreshRoll(track);
        saveState();
      });
    });
  }

  function wireKeyboardInput() {
    document.addEventListener('keydown', (e) => {
      const tag = e.target.tagName;
      if (tag === 'INPUT' || tag === 'SELECT' || tag === 'TEXTAREA' || tag === 'BUTTON') return;
      if (e.code === 'Space') {
        e.preventDefault();
        togglePlay();
        return;
      }
      if (e.key === 'ArrowLeft') {
        shiftOctave(-1);
        return;
      }
      if (e.key === 'ArrowRight') {
        shiftOctave(1);
        return;
      }
      if (e.repeat) return;
      const off = KEYMAP[e.key.toLowerCase()];
      if (off == null) return;
      const midi = kbBase + off;
      if (pressedKeys.has(midi)) return;
      pressedKeys.add(midi);
      engine.resume();
      kbDown(midi);
    });

    document.addEventListener('keyup', (e) => {
      const off = KEYMAP[e.key.toLowerCase()];
      if (off == null) return;
      const midi = kbBase + off;
      if (pressedKeys.has(midi)) {
        pressedKeys.delete(midi);
        kbUp(midi);
      }
    });

    document.addEventListener('pointerup', () => {
      if (mouseNote != null) {
        kbUp(mouseNote);
        mouseNote = null;
      }
    });

    window.addEventListener('blur', () => {
      pressedKeys.forEach((m) => kbUp(m));
      pressedKeys.clear();
    });
  }

  function draw() {
    if (sequencer.isPlaying) {
      const step = sequencer.drainVisual();
      if (step != null) setPlayheads(step);
    }
    requestAnimationFrame(draw);
  }

  // ---------- arranque ----------
  function init() {
    loadState();
    buildPatchTabs();
    buildPatchControls();
    rebuildAll();
    buildKeyboard();
    wireTransport();
    wireKeyboardInput();
    updatePlayButton();
    draw();
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }
})();
