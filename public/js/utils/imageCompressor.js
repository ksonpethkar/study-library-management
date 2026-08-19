/**
 * ImageCompressor Utility
 * Provides 1:1 square cropping, 300x300px auto-compression, and live webcam selfie capture.
 */
const ImageCompressor = {
  /**
   * Compress an image file to a 1:1 square Data URL (300x300px)
   * @param {File} file 
   * @param {Object} options 
   * @returns {Promise<string>} Base64 Data URL
   */
  compress(file, options = {}) {
    const targetWidth = options.maxWidth || 300;
    const targetHeight = options.maxHeight || 300;
    const quality = options.quality || 0.82;

    return new Promise((resolve, reject) => {
      if (!file || !file.type.startsWith('image/')) {
        return reject(new Error('Please select a valid image file (JPG, PNG, WebP)'));
      }

      const reader = new FileReader();
      reader.onerror = () => reject(new Error('Failed to read image file'));
      reader.onload = (e) => {
        const img = new Image();
        img.onerror = () => reject(new Error('Failed to parse image data'));
        img.onload = () => {
          try {
            const canvas = document.createElement('canvas');
            canvas.width = targetWidth;
            canvas.height = targetHeight;
            const ctx = canvas.getContext('2d');

            // 1:1 Center Square Crop Math
            const minDim = Math.min(img.width, img.height);
            const srcX = (img.width - minDim) / 2;
            const srcY = (img.height - minDim) / 2;

            // Smooth image resizing
            ctx.imageSmoothingEnabled = true;
            ctx.imageSmoothingQuality = 'high';

            // Draw cropped & scaled image
            ctx.drawImage(img, srcX, srcY, minDim, minDim, 0, 0, targetWidth, targetHeight);

            // Export as compressed WebP or JPEG
            let dataUrl = canvas.toDataURL('image/webp', quality);
            if (!dataUrl || dataUrl.length < 50) {
              dataUrl = canvas.toDataURL('image/jpeg', quality);
            }
            resolve(dataUrl);
          } catch (err) {
            reject(err);
          }
        };
        img.src = e.target.result;
      };
      reader.readAsDataURL(file);
    });
  },

  /**
   * Capture a selfie using device webcam camera
   * @param {Object} options 
   * @returns {Promise<string>} Base64 Data URL
   */
  captureWebcam(options = {}) {
    const targetWidth = options.maxWidth || 300;
    const targetHeight = options.maxHeight || 300;
    const quality = options.quality || 0.82;

    return new Promise((resolve, reject) => {
      const modalContent = document.createElement('div');
      modalContent.style.cssText = 'display: flex; flex-direction: column; align-items: center; gap: 14px;';
      modalContent.innerHTML = `
        <div style="position: relative; width: 300px; height: 300px; border-radius: 50%; overflow: hidden; background: #000; border: 4px solid var(--color-primary); box-shadow: 0 4px 20px rgba(0,0,0,0.3);">
          <video id="webcam-video" autoplay playsinline style="width: 100%; height: 100%; object-fit: cover; transform: scaleX(-1);"></video>
          <div id="webcam-countdown" style="position: absolute; inset: 0; display: none; align-items: center; justify-content: center; font-size: 5rem; font-weight: 900; color: #ffffff; text-shadow: 0 2px 10px rgba(0,0,0,0.8); background: rgba(0,0,0,0.3);"></div>
        </div>

        <div style="font-size: 0.85rem; color: var(--color-text-secondary); text-align: center;">
          Center your face inside the circle badge and click <strong>Snap Photo</strong>.
        </div>

        <div style="display: flex; gap: 10px; justify-content: center; width: 100%; margin-top: 6px;">
          <button id="btn-cancel-cam" class="btn btn-secondary" style="font-weight: 600;">Cancel</button>
          <button id="btn-snap-cam" class="btn btn-primary" style="font-weight: 700; padding: 8px 24px;">📸 Snap Photo</button>
        </div>
      `;

      const modal = new Modal({
        title: '📷 Live Webcam Selfie Capture',
        content: modalContent,
        size: 'sm'
      });
      modal.show();

      let stream = null;
      const videoEl = modalContent.querySelector('#webcam-video');
      const snapBtn = modalContent.querySelector('#btn-snap-cam');
      const cancelBtn = modalContent.querySelector('#btn-cancel-cam');
      const countdownEl = modalContent.querySelector('#webcam-countdown');

      navigator.mediaDevices.getUserMedia({ video: { width: { ideal: 640 }, height: { ideal: 640 }, facingMode: 'user' } })
        .then(s => {
          stream = s;
          videoEl.srcObject = stream;
        })
        .catch(err => {
          modal.close();
          reject(new Error('Webcam camera access denied or unavailable: ' + (err.message || err)));
        });

      const cleanup = () => {
        if (stream) {
          stream.getTracks().forEach(track => track.stop());
        }
      };

      cancelBtn.onclick = () => {
        cleanup();
        modal.close();
        reject(new Error('Camera capture cancelled'));
      };

      snapBtn.onclick = () => {
        snapBtn.disabled = true;
        let count = 3;
        countdownEl.style.display = 'flex';
        countdownEl.innerText = count;

        const timer = setInterval(() => {
          count--;
          if (count > 0) {
            countdownEl.innerText = count;
          } else {
            clearInterval(timer);
            try {
              const canvas = document.createElement('canvas');
              canvas.width = targetWidth;
              canvas.height = targetHeight;
              const ctx = canvas.getContext('2d');

              ctx.imageSmoothingEnabled = true;
              ctx.imageSmoothingQuality = 'high';

              // Mirror video horizontally to match live preview
              ctx.translate(targetWidth, 0);
              ctx.scale(-1, 1);

              const vWidth = videoEl.videoWidth || 640;
              const vHeight = videoEl.videoHeight || 640;
              const minDim = Math.min(vWidth, vHeight);
              const srcX = (vWidth - minDim) / 2;
              const srcY = (vHeight - minDim) / 2;

              ctx.drawImage(videoEl, srcX, srcY, minDim, minDim, 0, 0, targetWidth, targetHeight);

              let dataUrl = canvas.toDataURL('image/webp', quality);
              if (!dataUrl || dataUrl.length < 50) {
                dataUrl = canvas.toDataURL('image/jpeg', quality);
              }

              cleanup();
              modal.close();
              resolve(dataUrl);
            } catch (err) {
              cleanup();
              modal.close();
              reject(err);
            }
          }
        }, 600);
      };
    });
  }
};

window.ImageCompressor = ImageCompressor;
