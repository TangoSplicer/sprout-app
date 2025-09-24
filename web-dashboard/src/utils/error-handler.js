// src/utils/error-handler.js

/**
 * Error types for the Sprout web dashboard
 */
export const ErrorType = {
  NETWORK: 'network',
  PARSING: 'parsing',
  VALIDATION: 'validation',
  AUTHENTICATION: 'authentication',
  PERMISSION: 'permission',
  STORAGE: 'storage',
  SYNC: 'sync',
  UNKNOWN: 'unknown'
};

/**
 * Custom error class for Sprout web dashboard
 */
export class SproutError extends Error {
  /**
   * Create a new SproutError
   * @param {string} message - Error message
   * @param {string} type - Error type from ErrorType enum
   * @param {Error|null} originalError - Original error if this is a wrapper
   * @param {Object} context - Additional context information
   */
  constructor(message, type = ErrorType.UNKNOWN, originalError = null, context = {}) {
    super(message);
    this.name = 'SproutError';
    this.type = type;
    this.originalError = originalError;
    this.context = context;
    this.timestamp = new Date();
  }

  /**
   * Get a user-friendly error message
   * @returns {string} User-friendly error message
   */
  getUserMessage() {
    switch (this.type) {
      case ErrorType.NETWORK:
        return 'Network connection issue. Please check your internet connection and try again.';
      case ErrorType.PARSING:
        return 'There was a problem processing the data. Please try again or contact support.';
      case ErrorType.VALIDATION:
        return 'The information provided is invalid. Please check your input and try again.';
      case ErrorType.AUTHENTICATION:
        return 'Authentication failed. Please sign in again.';
      case ErrorType.PERMISSION:
        return 'You don\'t have permission to perform this action.';
      case ErrorType.STORAGE:
        return 'Storage error. Unable to save or retrieve data.';
      case ErrorType.SYNC:
        return 'Synchronization error. Unable to sync with your device.';
      default:
        return 'An unexpected error occurred. Please try again later.';
    }
  }
}

/**
 * Global error handler for the Sprout web dashboard
 */
export class ErrorHandler {
  constructor() {
    this.errors = [];
    this.listeners = [];
    
    // Set up global error handling
    window.addEventListener('error', this.handleGlobalError.bind(this));
    window.addEventListener('unhandledrejection', this.handleUnhandledRejection.bind(this));
  }

  /**
   * Handle a global error event
   * @param {ErrorEvent} event - Error event
   */
  handleGlobalError(event) {
    const error = new SproutError(
      event.message || 'Unknown error',
      ErrorType.UNKNOWN,
      event.error,
      { fileName: event.filename, lineNumber: event.lineno, columnNumber: event.colno }
    );
    this.reportError(error);
  }

  /**
   * Handle an unhandled promise rejection
   * @param {PromiseRejectionEvent} event - Promise rejection event
   */
  handleUnhandledRejection(event) {
    const error = new SproutError(
      event.reason?.message || 'Unhandled promise rejection',
      ErrorType.UNKNOWN,
      event.reason
    );
    this.reportError(error);
  }

  /**
   * Report an error
   * @param {SproutError} error - Error to report
   */
  reportError(error) {
    console.error('[Sprout Error]', error);
    
    // Add to error log
    this.errors.push(error);
    
    // Notify listeners
    this.notifyListeners(error);
    
    // In production, we could send this to a monitoring service
    if (process.env.NODE_ENV === 'production') {
      this.sendToMonitoringService(error);
    }
  }

  /**
   * Send error to a monitoring service
   * @param {SproutError} error - Error to send
   */
  sendToMonitoringService(error) {
    // This would be implemented to send to a service like Sentry, LogRocket, etc.
    console.log('Would send to monitoring service:', error);
  }

  /**
   * Add an error listener
   * @param {Function} listener - Function to call when an error occurs
   * @returns {Function} Function to remove the listener
   */
  addListener(listener) {
    this.listeners.push(listener);
    return () => {
      this.listeners = this.listeners.filter(l => l !== listener);
    };
  }

  /**
   * Notify all listeners of an error
   * @param {SproutError} error - Error to notify about
   */
  notifyListeners(error) {
    this.listeners.forEach(listener => {
      try {
        listener(error);
      } catch (e) {
        console.error('Error in error listener:', e);
      }
    });
  }

  /**
   * Clear all errors
   */
  clearErrors() {
    this.errors = [];
  }

  /**
   * Get all errors
   * @returns {SproutError[]} All errors
   */
  getErrors() {
    return [...this.errors];
  }
}

// Create a singleton instance
export const errorHandler = new ErrorHandler();

/**
 * Error boundary component for React
 * @param {Function} Component - Component to wrap
 * @returns {Function} Wrapped component with error handling
 */
export function withErrorHandling(Component) {
  return function WithErrorHandling(props) {
    const [error, setError] = React.useState(null);
    
    React.useEffect(() => {
      const removeListener = errorHandler.addListener(err => {
        setError(err);
      });
      
      return removeListener;
    }, []);
    
    if (error) {
      return (
        <div className="error-boundary">
          <h2>Something went wrong</h2>
          <p>{error.getUserMessage()}</p>
          <button onClick={() => setError(null)}>Dismiss</button>
        </div>
      );
    }
    
    return <Component {...props} />;
  };
}

/**
 * Async function wrapper with error handling
 * @param {Function} fn - Async function to wrap
 * @returns {Function} Wrapped function with error handling
 */
export function withErrorHandlingAsync(fn) {
  return async function(...args) {
    try {
      return await fn(...args);
    } catch (e) {
      // Convert to SproutError if it's not already
      const error = e instanceof SproutError 
        ? e 
        : new SproutError(e.message, ErrorType.UNKNOWN, e);
      
      errorHandler.reportError(error);
      throw error;
    }
  };
}

/**
 * Create a network error
 * @param {string} message - Error message
 * @param {Error} originalError - Original error
 * @returns {SproutError} Network error
 */
export function createNetworkError(message, originalError = null) {
  return new SproutError(message, ErrorType.NETWORK, originalError);
}

/**
 * Create a parsing error
 * @param {string} message - Error message
 * @param {Error} originalError - Original error
 * @returns {SproutError} Parsing error
 */
export function createParsingError(message, originalError = null) {
  return new SproutError(message, ErrorType.PARSING, originalError);
}

/**
 * Create a validation error
 * @param {string} message - Error message
 * @param {Object} validationErrors - Validation errors by field
 * @returns {SproutError} Validation error
 */
export function createValidationError(message, validationErrors = {}) {
  return new SproutError(message, ErrorType.VALIDATION, null, { validationErrors });
}