const express = require('express');
const router = express.Router();
const path = require('path');
const fs = require('fs');
const { protect } = require('../middleware/auth');

// Ensure uploads folder exists
const uploadsDir = path.join(__dirname, '..', 'uploads');
if (!fs.existsSync(uploadsDir)) {
  fs.mkdirSync(uploadsDir, { recursive: true });
}

/**
 * @route   POST /api/upload
 * @desc    Upload image file (base64 or multipart)
 * @access  Private / Public
 */
router.post('/', protect, async (req, res) => {
  try {
    const { image, folder } = req.body;

    if (!image) {
      return res.status(400).json({ success: false, message: 'No image data provided' });
    }

    // Check if image is Base64 Data URL
    if (typeof image === 'string' && image.startsWith('data:image/')) {
      const matches = image.match(/^data:image\/([a-zA-Z0-9]+);base64,(.+)$/);
      if (!matches || matches.length !== 3) {
        return res.status(400).json({ success: false, message: 'Invalid Base64 image format' });
      }

      const ext = matches[1].toLowerCase();
      const base64Data = matches[2];

      // ── Security: whitelist allowed image types ──────────────────────────
      const ALLOWED_TYPES = ['jpg', 'jpeg', 'png', 'webp', 'gif', 'bmp'];
      if (!ALLOWED_TYPES.includes(ext === 'jpeg' ? 'jpg' : ext)) {
        return res.status(400).json({ success: false, message: `Image type '${ext}' not allowed. Use JPG, PNG, or WebP.` });
      }

      // ── Security: 5MB size limit (base64 is ~1.37× actual size) ─────────
      const MAX_BASE64_BYTES = 7 * 1024 * 1024; // 7MB base64 ≈ 5MB actual
      if (base64Data.length > MAX_BASE64_BYTES) {
        const actualMB = ((base64Data.length * 3) / 4 / 1024 / 1024).toFixed(1);
        return res.status(413).json({
          success: false,
          message: `Image too large (${actualMB} MB). Maximum allowed size is 5 MB. Please compress the image first.`
        });
      }

      const buffer = Buffer.from(base64Data, 'base64');

      const safeExt = ext === 'jpeg' ? 'jpg' : ext;
      const filename = `img_${Date.now()}_${Math.random().toString(36).substring(2, 8)}.${safeExt}`;
      const targetPath = path.join(uploadsDir, filename);

      await fs.promises.writeFile(targetPath, buffer);

      const fileUrl = `/uploads/${filename}`;
      return res.json({
        success: true,
        message: 'Image uploaded successfully',
        url: fileUrl,
        filename
      });
    }

    // Check if image is already a URL
    if (typeof image === 'string' && (image.startsWith('http://') || image.startsWith('https://') || image.startsWith('/uploads/'))) {
      return res.json({
        success: true,
        message: 'Image URL verified',
        url: image
      });
    }

    return res.status(400).json({ success: false, message: 'Unsupported upload format' });
  } catch (err) {
    console.error('Upload Error:', err);
    res.status(500).json({ success: false, message: 'Failed to save image' });
  }
});

module.exports = router;
