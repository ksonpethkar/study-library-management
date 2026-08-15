export class DragDropList {
  constructor(containerId, { onReorder, handle }) {
    this.container = document.getElementById(containerId);
    this.onReorder = onReorder;
    this.handle = handle;
    if (this.container) this.enable();
  }

  enable() {
    // Basic placeholder for drag and drop logic
    console.log(`DragDropList enabled on ${this.container?.id}`);
  }

  disable() {
    console.log(`DragDropList disabled`);
  }

  getOrder() {
    if (!this.container) return [];
    return Array.from(this.container.children).map(child => child.dataset.id || child.id);
  }
}
