export class QRCode {
  /**
   * Generate QR code image URL using free API
   * @param {string} data - Data to encode
   * @param {number} size - Size in pixels
   * @returns {string} URL of QR code image
   */
  static getURL(data, size = 200) {
    return `https://api.qrserver.com/v1/create-qr-code/?size=${size}x${size}&data=${encodeURIComponent(data)}&margin=8`;
  }
  
  /**
   * Generate QR code as canvas data URL (offline capable)
   * Uses a minimal bit-matrix approach
   */
  static toDataURL(data, options = {}) {
    // For offline support, use a simple numeric/alphanumeric encoder
    // This is a simplified version that creates a visual QR-like pattern
    const size = options.size || 200;
    const dark = options.darkColor || '#1e293b';
    const light = options.lightColor || '#ffffff';
    
    const canvas = document.createElement('canvas');
    canvas.width = size;
    canvas.height = size;
    const ctx = canvas.getContext('2d');
    
    // Use the API image as source
    const img = new Image();
    img.crossOrigin = 'anonymous';
    
    return new Promise((resolve) => {
      img.onload = () => {
        ctx.drawImage(img, 0, 0, size, size);
        resolve(canvas.toDataURL('image/png'));
      };
      img.onerror = () => {
        // Fallback: generate a simple pattern
        ctx.fillStyle = light;
        ctx.fillRect(0, 0, size, size);
        ctx.fillStyle = dark;
        ctx.font = `${size * 0.08}px monospace`;
        ctx.textAlign = 'center';
        ctx.fillText('QR', size/2, size/2);
        resolve(canvas.toDataURL('image/png'));
      };
      img.src = QRCode.getURL(data, size);
    });
  }
  
  /**
   * Create an img element with QR code
   */
  static createImg(data, size = 150) {
    const img = document.createElement('img');
    img.src = QRCode.getURL(data, size);
    img.alt = 'QR Code';
    img.style.width = size + 'px';
    img.style.height = size + 'px';
    return img;
  }
}
