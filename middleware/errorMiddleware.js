/**
 * Centralized Backend Error Handling Middleware & Crash Recovery
 */

/**
 * Express Global Error Handling Middleware
 * Captures all unhandled exceptions passed to next(err) or thrown inside route handlers,
 * logs detailed stack tracebacks, and returns standardized JSON responses.
 */
const errorHandler = (err, req, res, next) => {
  // Log full stack traceback for debugging
  console.error(`\n❌ [Express Error] ${req.method} ${req.originalUrl}`);
  console.error(err.stack || err);

  const statusCode = err.statusCode || (res.statusCode && res.statusCode !== 200 ? res.statusCode : 500);
  const response = {
    success: false,
    message: err.message || 'Internal Server Error'
  };

  // Include stack trace only in development environment
  if (process.env.NODE_ENV === 'development') {
    response.stack = err.stack;
  }

  res.status(statusCode).json(response);
};

/**
 * Register process-level event listeners for uncaught exceptions and unhandled promise rejections
 */
const initProcessErrorHandlers = () => {
  process.on('uncaughtException', (err) => {
    console.error('\n💥 UNCAUGHT EXCEPTION DETECTED!');
    console.error(err.stack || err);
  });

  process.on('unhandledRejection', (reason, promise) => {
    console.error('\n⚠️  UNHANDLED PROMISE REJECTION DETECTED!');
    console.error('Reason:', reason?.stack || reason);
  });
};

module.exports = {
  errorHandler,
  initProcessErrorHandlers
};
