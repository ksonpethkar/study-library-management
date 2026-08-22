class ApiClient {
  constructor(baseUrl = '') {
    this.baseUrl = baseUrl;
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
    
    try {
      const response = await fetch(this.baseUrl + endpoint, config);
      
      let data = {};
      const contentType = response.headers.get("content-type");
      if (contentType && contentType.indexOf("application/json") !== -1) {
        data = await response.json();
      } else {
        data = await response.text();
      }
      
      if (response.status === 401) {
        localStorage.removeItem('sl_token');
        // Graceful session expiry — don't hard reload (loses form data)
        if (!ApiClient._sessionExpiredShown) {
          ApiClient._sessionExpiredShown = true;
          // Show toast if Toast is available
          if (window.Toast?.warning) {
            window.Toast.warning('⏰ Session expired — please sign in again.');
          }
          // Navigate to login without hard reload
          setTimeout(() => {
            if (window.App?.showLogin) {
              window.App.showLogin();
            } else {
              window.location.hash = '';
              location.reload();
            }
            ApiClient._sessionExpiredShown = false;
          }, 1500);
        }
        return null;
      }
      
      if (!response.ok) {
        throw { message: data.message || 'Something went wrong', status: response.status, data };
      }
      
      return data;
    } catch (error) {
      if (error.message === 'Failed to fetch' || error instanceof TypeError) {
        throw { message: 'Network error — check your connection', status: 0 };
      }
      throw error;
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
    return this.request(endpoint);
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
export default api;
