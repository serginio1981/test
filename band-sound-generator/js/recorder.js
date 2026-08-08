'use strict';

// Grabación de la mezcla final con MediaRecorder.
// Toma el audio post-compresor y lo expone como un Blob al detenerse.
class Recorder {
  constructor(engine) {
    this.engine = engine;
    this.ctx = engine.ctx;
    this.dest = null;
    this.recorder = null;
    this.chunks = [];
    this.isRecording = false;
    this.mimeType = 'audio/webm';
    this.startedAt = 0;
  }

  static isSupported() {
    return typeof window !== 'undefined' && !!window.MediaRecorder;
  }

  _ensureDest() {
    if (this.dest) return true;
    if (typeof this.ctx.createMediaStreamDestination !== 'function') return false;
    this.dest = this.ctx.createMediaStreamDestination();
    this.engine.compressor.connect(this.dest);
    return true;
  }

  _chooseMime() {
    if (!Recorder.isSupported()) return null;
    const candidates = [
      'audio/webm;codecs=opus',
      'audio/webm',
      'audio/mp4',
      'audio/ogg;codecs=opus',
    ];
    for (const m of candidates) {
      if (MediaRecorder.isTypeSupported && MediaRecorder.isTypeSupported(m)) return m;
    }
    return null;
  }

  start() {
    if (this.isRecording) return false;
    if (!Recorder.isSupported()) return false;
    if (!this._ensureDest()) return false;
    const mime = this._chooseMime();
    if (mime) this.mimeType = mime;
    try {
      this.recorder = mime
        ? new MediaRecorder(this.dest.stream, { mimeType: mime })
        : new MediaRecorder(this.dest.stream);
    } catch (e) {
      return false;
    }
    this.chunks = [];
    this.recorder.ondataavailable = (e) => {
      if (e.data && e.data.size > 0) this.chunks.push(e.data);
    };
    this.recorder.start(100);
    this.isRecording = true;
    this.startedAt = Date.now();
    return true;
  }

  stop() {
    return new Promise((resolve) => {
      if (!this.isRecording || !this.recorder) return resolve(null);
      const rec = this.recorder;
      const mime = rec.mimeType || this.mimeType;
      rec.onstop = () => {
        const blob = new Blob(this.chunks, { type: mime });
        this.isRecording = false;
        this.chunks = [];
        resolve(blob);
      };
      rec.stop();
    });
  }

  extensionFor(blob) {
    const t = (blob && blob.type) || this.mimeType || '';
    if (t.includes('mp4')) return 'm4a';
    if (t.includes('ogg')) return 'ogg';
    return 'webm';
  }
}
