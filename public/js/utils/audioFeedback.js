/**
 * Web Audio API Sound Synthesizer for Antigravity Library System
 * Pure native Web Audio synthesis — zero external audio files, works 100% offline.
 */
class SoundEngine {
  constructor() {
    this.ctx = null;
    let isEnabled = true;
    try {
      if (typeof window !== 'undefined' && window.localStorage) {
        isEnabled = window.localStorage.getItem('sl_sound_enabled') !== 'false';
      }
    } catch (_) {}
    this.enabled = isEnabled;
  }

  _initContext() {
    if (!this.ctx) {
      const AudioCtx = (typeof window !== 'undefined') ? (window.AudioContext || window.webkitAudioContext) : null;
      if (AudioCtx) {
        this.ctx = new AudioCtx();
      }
    }
    if (this.ctx && this.ctx.state === 'suspended') {
      try { this.ctx.resume(); } catch (_) {}
    }
  }

  toggleSound(forceState) {
    if (typeof forceState === 'boolean') {
      this.enabled = forceState;
    } else {
      this.enabled = !this.enabled;
    }
    try {
      if (typeof window !== 'undefined' && window.localStorage) {
        window.localStorage.setItem('sl_sound_enabled', this.enabled ? 'true' : 'false');
      }
    } catch (_) {}
    return this.enabled;
  }

  play(type = 'click') {
    if (!this.enabled) return;
    try {
      this._initContext();
      if (!this.ctx) return;

      const now = this.ctx.currentTime;

      if (type === 'success') {
        // High-end pleasant two-tone major chord (F#5 -> B5)
        const osc1 = this.ctx.createOscillator();
        const osc2 = this.ctx.createOscillator();
        const gain = this.ctx.createGain();

        osc1.type = 'sine';
        osc2.type = 'sine';

        osc1.frequency.setValueAtTime(587.33, now); // D5
        osc1.frequency.exponentialRampToValueAtTime(880, now + 0.12); // A5

        osc2.frequency.setValueAtTime(739.99, now); // F#5
        osc2.frequency.exponentialRampToValueAtTime(1174.66, now + 0.12); // D6

        gain.gain.setValueAtTime(0.08, now);
        gain.gain.exponentialRampToValueAtTime(0.001, now + 0.35);

        osc1.connect(gain);
        osc2.connect(gain);
        gain.connect(this.ctx.destination);

        osc1.start(now);
        osc2.start(now);
        osc1.stop(now + 0.35);
        osc2.stop(now + 0.35);

      } else if (type === 'click') {
        // Subtle soft tap
        const osc = this.ctx.createOscillator();
        const gain = this.ctx.createGain();

        osc.type = 'sine';
        osc.frequency.setValueAtTime(440, now);
        osc.frequency.exponentialRampToValueAtTime(220, now + 0.04);

        gain.gain.setValueAtTime(0.04, now);
        gain.gain.exponentialRampToValueAtTime(0.001, now + 0.04);

        osc.connect(gain);
        gain.connect(this.ctx.destination);

        osc.start(now);
        osc.stop(now + 0.04);

      } else if (type === 'warning') {
        // Subtle double pulse
        const osc = this.ctx.createOscillator();
        const gain = this.ctx.createGain();

        osc.type = 'triangle';
        osc.frequency.setValueAtTime(320, now);
        osc.frequency.setValueAtTime(280, now + 0.08);

        gain.gain.setValueAtTime(0.06, now);
        gain.gain.exponentialRampToValueAtTime(0.001, now + 0.2);

        osc.connect(gain);
        gain.connect(this.ctx.destination);

        osc.start(now);
        osc.stop(now + 0.2);

      } else if (type === 'delete') {
        // Low descent
        const osc = this.ctx.createOscillator();
        const gain = this.ctx.createGain();

        osc.type = 'sine';
        osc.frequency.setValueAtTime(300, now);
        osc.frequency.exponentialRampToValueAtTime(140, now + 0.15);

        gain.gain.setValueAtTime(0.06, now);
        gain.gain.exponentialRampToValueAtTime(0.001, now + 0.15);

        osc.connect(gain);
        gain.connect(this.ctx.destination);

        osc.start(now);
        osc.stop(now + 0.15);
      }
    } catch (e) {
      // Ignore audio synthesis errors on locked autoplay policies
    }
  }
}

export const AudioFeedback = new SoundEngine();
