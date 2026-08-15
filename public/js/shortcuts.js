export default class ShortcutManager {
  constructor() {
    this.shortcuts = new Map();
    document.addEventListener('keydown', this.handleKeydown.bind(this));
  }
  
  register(combo, callback, description) {
    const key = combo.toLowerCase().replace(/\s/g, '');
    this.shortcuts.set(key, { callback, description });
  }
  
  unregister(combo) {
    const key = combo.toLowerCase().replace(/\s/g, '');
    this.shortcuts.delete(key);
  }
  
  handleKeydown(e) {
    if (e.target.tagName === 'INPUT' || e.target.tagName === 'TEXTAREA') {
      if (e.key !== 'Escape') return;
    }
    
    let parts = [];
    if (e.ctrlKey || e.metaKey) parts.push('ctrl');
    if (e.altKey) parts.push('alt');
    if (e.shiftKey) parts.push('shift');
    if (e.key !== 'Control' && e.key !== 'Alt' && e.key !== 'Shift' && e.key !== 'Meta') {
      parts.push(e.key.toLowerCase());
    }
    
    const keyCombo = parts.join('+');
    
    if (this.shortcuts.has(keyCombo)) {
      e.preventDefault();
      this.shortcuts.get(keyCombo).callback(e);
    }
  }
  
  getAll() {
    return Array.from(this.shortcuts.entries()).map(([combo, data]) => ({
      combo,
      description: data.description
    }));
  }
}
