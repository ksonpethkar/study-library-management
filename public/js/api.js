class ApiClient {
  constructor(baseUrl = '') {
    this.baseUrl = baseUrl;
    this._inFlightGets = new Map();
  }
  
  async request(endpoint, options = {}, isFormData = false) {
    const token = localStorage.getItem('sl_token');
    const headers = {
      ...(token && { 'Authorization': `Bearer ${token}` }),
      ...options.headers
    };
    if (!isFormData) {
      headers['Content-Type'] = 'application/json';
    }
    const config = {
      headers,
      ...options
    };
    
    const method = (options.method || 'GET').toUpperCase();
    const isGet = method === 'GET';
    const maxRetries = isGet ? 3 : 1;
    let attempt = 0;
    
    while (attempt <= maxRetries) {
      const abortController = new AbortController();
      const timeoutId = setTimeout(() => abortController.abort(), 30000); // 30s timeout
      
      try {
        const response = await fetch(this.baseUrl + endpoint, {
          ...config,
          signal: abortController.signal
        });
        
        clearTimeout(timeoutId);
        
        let data = {};
        const contentType = response.headers.get("content-type");
        if (contentType && contentType.indexOf("application/json") !== -1) {
          data = await response.json();
        } else {
          data = await response.text();
        }
        
        if (response.status === 401) {
          localStorage.removeItem('sl_token');
          if (window.App && typeof window.App.showLogin === 'function') {
            window.App.showLogin();
          }
          if (!ApiClient._sessionExpiredShown) {
            ApiClient._sessionExpiredShown = true;
            if (window.Toast?.warning) {
              window.Toast.warning('⏰ Session expired — please sign in again.');
            }
            setTimeout(() => {
              ApiClient._sessionExpiredShown = false;
            }, 3000);
          }
          return null;
        }
        
        if (!response.ok) {
          if (response.status >= 400 && response.status < 500) {
            throw { message: data.message || 'Something went wrong', status: response.status, data };
          }
          throw { message: data.message || 'Server error', status: response.status, data, isServerError: true };
        }
        
        return data;
      } catch (error) {
        clearTimeout(timeoutId);
        
        const isNetworkError = error.message === 'Failed to fetch' || error instanceof TypeError;
        const isTimeout = error.name === 'AbortError';
        const isServerError = error.isServerError;
        
        const canRetry = isNetworkError || isTimeout || isServerError;
        
        if (!canRetry || attempt >= maxRetries) {
          if (isTimeout) {
            throw { message: 'Request timed out — please try again', status: 408 };
          }
          if (isNetworkError) {
            throw { message: 'Network error — check your connection', status: 0 };
          }
          throw error;
        }
        
        const backoff = Math.pow(2, attempt) * 1000;
        await new Promise(resolve => setTimeout(resolve, backoff));
        attempt++;
      }
    }
  }
  
  get(endpoint, params) {
    if (params) {
      const query = Object.entries(params)
        .filter(([, v]) => v !== undefined && v !== null && v !== '')
        .map(([k, v]) => `${encodeURIComponent(k)}=${encodeURIComponent(v)}`)
        .join('&');
      if (query) endpoint += `?${query}`;
    }
    const url = this.baseUrl + endpoint;
    if (this._inFlightGets.has(url)) {
      return this._inFlightGets.get(url);
    }
    const promise = this.request(endpoint).finally(() => {
      this._inFlightGets.delete(url);
    });
    this._inFlightGets.set(url, promise);
    return promise;
  }
  post(endpoint, body) {
    if (body instanceof FormData) return this.request(endpoint, { method: 'POST', body }, true);
    return this.request(endpoint, { method: 'POST', body: JSON.stringify(body) });
  }
  put(endpoint, body) {
    if (body instanceof FormData) return this.request(endpoint, { method: 'PUT', body }, true);
    return this.request(endpoint, { method: 'PUT', body: JSON.stringify(body) });
  }
  patch(endpoint, body) { return this.request(endpoint, { method: 'PATCH', body: JSON.stringify(body) }); }
  delete(endpoint) { return this.request(endpoint, { method: 'DELETE' }); }
}

const api = new ApiClient();
export { api, ApiClient };
export default api;
