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
      return res.status(400).json({ success: false, message: 'No image or document data provided' });
    }

    // Check if image is Base64 Data URL
    if (typeof image === 'string' && image.startsWith('data:')) {
      const match = image.match(/^data:([a-zA-Z0-9_\-\+\/]+);base64,(.+)$/s);
      if (!match) {
        return res.status(400).json({ success: false, message: 'Invalid Base64 file format' });
      }

      const mimeType = match[1].toLowerCase();
      const base64Data = match[2].trim();

      let ext = 'jpg';
      if (mimeType.includes('png')) ext = 'png';
      else if (mimeType.includes('webp')) ext = 'webp';
      else if (mimeType.includes('gif')) ext = 'gif';
      else if (mimeType.includes('pdf')) ext = 'pdf';
      else if (mimeType.includes('svg')) ext = 'svg';
      else if (mimeType.includes('bmp')) ext = 'bmp';
      else if (mimeType.includes('jpeg') || mimeType.includes('jpg')) ext = 'jpg';

      const buffer = Buffer.from(base64Data, 'base64');
      const filename = `doc_${Date.now()}_${Math.random().toString(36).substring(2, 8)}.${ext}`;
      const targetPath = path.join(uploadsDir, filename);

      await fs.promises.writeFile(targetPath, buffer);

      const fileUrl = `/uploads/${filename}`;
      return res.json({
        success: true,
        message: 'File uploaded successfully',
        url: fileUrl,
        filename
      });
    }

    // Check if image is already a URL
    if (typeof image === 'string' && (image.startsWith('http://') || image.startsWith('https://') || image.startsWith('/uploads/'))) {
      return res.json({
        success: true,
        message: 'File URL verified',
        url: image
      });
    }

    return res.status(400).json({ success: false, message: 'Unsupported upload format' });
  } catch (err) {
    console.error('Upload Error:', err);
    res.status(500).json({ success: false, message: 'Failed to save file' });
  }
});

module.exports = router;
