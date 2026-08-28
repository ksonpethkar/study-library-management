/**
 * Global Error Boundary & Crash Reporter
 * Catches uncaught exceptions and unhandled promise rejections
 */

const ErrorBoundary = {
  _errors: [],
  _maxErrors: 50,
  
  init() {
    // Global JS error handler
    window.onerror = (message, source, lineno, colno, error) => {
      this._capture({
        type: 'uncaught_exception',
        message: message || 'Unknown error',
        source: source || '',
        line: lineno,
        col: colno,
        stack: error?.stack || '',
        timestamp: new Date().toISOString()
      });
      // Don't suppress — let it propagate to console
      return false;
    };

    // Unhandled Promise rejection handler
    window.addEventListener('unhandledrejection', (event) => {
      const reason = event.reason;
      this._capture({
        type: 'unhandled_rejection',
        message: reason?.message || String(reason) || 'Unhandled Promise rejection',
        stack: reason?.stack || '',
        timestamp: new Date().toISOString()
      });
    });

    // Network error tracking
    window.addEventListener('offline', () => {
      if (window.Toast?.warning) {
        window.Toast.warning('📡 You are offline — some features may not work');
      }
    });
    window.addEventListener('online', () => {
      if (window.Toast?.success) {
        window.Toast.success('🌐 Back online');
      }
    });

    console.log('[ErrorBoundary] Global error handlers initialized');
  },

  _capture(errorInfo) {
    // Store in memory (circular buffer)
    this._errors.push(errorInfo);
    if (this._errors.length > this._maxErrors) {
      this._errors.shift();
    }
    // Also persist to sessionStorage for debugging
    try {
      sessionStorage.setItem('sl_error_log', JSON.stringify(this._errors.slice(-20)));
    } catch (e) {}
    
    // Log to console with styling
    console.error(`[ErrorBoundary] ${errorInfo.type}:`, errorInfo.message, errorInfo.stack ? '\n' + errorInfo.stack : '');
  },

  getErrors() {
    return [...this._errors];
  },

  getErrorCount() {
    return this._errors.length;
  },

  clearErrors() {
    this._errors = [];
    try { sessionStorage.removeItem('sl_error_log'); } catch (e) {}
  }
};

export { ErrorBoundary };
export default ErrorBoundary;
window.ErrorBoundary = ErrorBoundary;
