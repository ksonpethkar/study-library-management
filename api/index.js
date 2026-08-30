// Vercel Serverless Function Entrypoint
const app = require('../server');

module.exports = (req, res) => {
  if (req.body !== undefined && req.body !== null) {
    if (typeof req.body === 'string') {
      try {
        req.body = JSON.parse(req.body);
      } catch (e) {}
    }
    req._body = true;
  }
  return app(req, res);
};

