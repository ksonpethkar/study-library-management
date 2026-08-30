const dns = require('dns');
try {
  if (dns.setDefaultResultOrder) {
    dns.setDefaultResultOrder('ipv4first');
  }
  if (!process.env.VERCEL) {
    dns.setServers(['8.8.8.8', '8.8.4.4', '1.1.1.1']);
  }
} catch (e) {}

const mongoose = require('mongoose');

let cachedPromise = null;

/**
 * Connect to MongoDB database (supports serverless connection caching)
 * @returns {Promise<any>}
 */
const connectDB = async () => {
  if (mongoose.connection.readyState === 1) {
    return mongoose.connection;
  }

  if (cachedPromise) {
    try {
      await cachedPromise;
      return mongoose.connection;
    } catch (e) {
      cachedPromise = null;
    }
  }

  try {
    cachedPromise = mongoose.connect(process.env.MONGODB_URI, {
      serverSelectionTimeoutMS: 5000,
      socketTimeoutMS: 30000,
    });

    const conn = await cachedPromise;
    console.log(`  🗄️  MongoDB connected: ${conn.connection.host}`);

    mongoose.connection.on('error', (err) => {
      console.error(`MongoDB connection error: ${err.message}`);
    });

    mongoose.connection.on('disconnected', () => {
      console.log('MongoDB disconnected — attempting reconnect...');
      cachedPromise = null;
    });

    mongoose.connection.on('reconnected', () => {
      console.log('MongoDB reconnected');
    });

    return conn;
  } catch (error) {
    cachedPromise = null;
    console.error(`Error connecting to MongoDB: ${error.message}`);
    throw error;
  }
};

// Graceful shutdown on SIGINT and SIGTERM
process.removeAllListeners('SIGINT');
process.removeAllListeners('SIGTERM');
const shutdown = async () => {
  await mongoose.connection.close();
  console.log('MongoDB connection closed due to app termination');
  process.exit(0);
};
process.on('SIGINT', shutdown);
process.on('SIGTERM', shutdown);

module.exports = connectDB;
