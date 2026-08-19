import { Toast } from '../ui.js';

/**
 * OptimisticUI Engine
 * Handles 0ms latency DOM state updates before network requests complete.
 * Automatically rolls back state and displays Toast errors if API request fails.
 */
export class OptimisticUI {
  /**
   * Executes an optimistic UI update.
   *
   * @param {Object} params
   * @param {Function} params.applyState - Synchronous callback to immediately update DOM / state
   * @param {Function} [params.rollbackState] - Callback to revert DOM / state changes on API failure
   * @param {Function} params.apiCall - Async callback that executes the server API request
   * @param {Function} [params.onSuccess] - Callback executed when server request succeeds
   * @param {Function} [params.onError] - Callback executed when server request fails
   */
  static async execute({ applyState, rollbackState, apiCall, onSuccess, onError }) {
    // 1. Immediately apply DOM/state changes (0ms latency)
    if (typeof applyState === 'function') {
      try {
        applyState();
      } catch (err) {
        console.error('[OptimisticUI] Error in applyState:', err);
      }
    }

    // 2. Perform API request in background
    try {
      const response = await apiCall();
      if (typeof onSuccess === 'function') {
        onSuccess(response);
      }
      return response;
    } catch (error) {
      // 3. Rollback state if network request fails
      if (typeof rollbackState === 'function') {
        try {
          rollbackState(error);
        } catch (rollErr) {
          console.error('[OptimisticUI] Error in rollbackState:', rollErr);
        }
      }

      // Extract & display error message via Toast
      const errorMsg = error?.message || (typeof error === 'string' ? error : 'Action failed. Changes reverted.');
      Toast.error(errorMsg);

      if (typeof onError === 'function') {
        onError(error);
      }

      throw error;
    }
  }
}

export default OptimisticUI;
