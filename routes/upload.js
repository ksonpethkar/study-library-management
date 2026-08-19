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
router.post('/', async (req, res) => {
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

      const ext = matches[1] === 'jpeg' ? 'jpg' : matches[1];
      const base64Data = matches[2];
      const buffer = Buffer.from(base64Data, 'base64');

      const filename = `img_${Date.now()}_${Math.random().toString(36).substring(2, 8)}.${ext}`;
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
