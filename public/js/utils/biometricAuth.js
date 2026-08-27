import api from '../api.js';
import { Toast } from '../ui.js';

// Helper functions for ArrayBuffer <-> Base64URL conversion
function arrayBufferToBase64URL(buffer) {
  let binary = '';
  const bytes = new Uint8Array(buffer);
  for (let i = 0; i < bytes.byteLength; i++) {
    binary += String.fromCharCode(bytes[i]);
  }
  return window.btoa(binary)
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=/g, '');
}

function base64URLToArrayBuffer(base64url) {
  let b64 = base64url.replace(/-/g, '+').replace(/_/g, '/');
  while (b64.length % 4) b64 += '=';
  const binary = window.atob(b64);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) {
    bytes[i] = binary.charCodeAt(i);
  }
  return bytes.buffer;
}

export const BiometricAuth = {
  /**
   * Checks if WebAuthn API & native platform authenticator (Touch ID, Face ID, Fingerprint, Windows Hello) are available.
   * @returns {Promise<boolean>}
   */
  async isSupported() {
    if (!window.PublicKeyCredential) {
      return false;
    }
    if (typeof PublicKeyCredential.isUserVerifyingPlatformAuthenticatorAvailable === 'function') {
      try {
        return await PublicKeyCredential.isUserVerifyingPlatformAuthenticatorAvailable();
      } catch (err) {
        console.warn('Biometric availability check failed:', err);
        return false;
      }
    }
    return true;
  },

  /**
   * Check if biometric credentials have been registered/saved on this local device.
   * @returns {boolean}
   */
  hasSavedCredentials() {
    return localStorage.getItem('sl_biometric_registered') === 'true';
  },

  /**
   * Prompts user for native Fingerprint / Face ID / Touch ID credential registration.
   * Sends registered credential payload to server endpoint POST /api/auth/biometric/register.
   * @param {Object} [currentUser] Optional logged-in user object
   * @returns {Promise<Object>} Result from registration endpoint
   */
  async register(currentUser = null) {
    const supported = await this.isSupported();
    if (!supported) {
      Toast.error('Biometric authentication is not supported on this browser or device.');
      throw new Error('WebAuthn biometrics not supported');
    }

    try {
      // Fetch current user if not provided
      if (!currentUser) {
        const meRes = await api.get('/api/auth/me');
        currentUser = meRes.data || meRes;
      }

      const challenge = new Uint8Array(32);
      window.crypto.getRandomValues(challenge);

      const userId = new Uint8Array(16);
      window.crypto.getRandomValues(userId);

      const publicKeyCredentialCreationOptions = {
        challenge,
        rp: {
          name: 'Study Library System',
          id: window.location.hostname || 'localhost'
        },
        user: {
          id: userId,
          name: currentUser.email || currentUser.phone || 'user@studylib.local',
          displayName: currentUser.name || 'Library User'
        },
        pubKeyCredParams: [
          { alg: -7, type: 'public-key' },  // ES256
          { alg: -257, type: 'public-key' } // RS256
        ],
        authenticatorSelection: {
          authenticatorAttachment: 'platform', // Native Fingerprint, Touch ID, Face ID, Windows Hello
          userVerification: 'preferred'
        },
        timeout: 60000,
        attestation: 'none'
      };

      const credential = await navigator.credentials.create({
        publicKey: publicKeyCredentialCreationOptions
      });

      if (!credential) {
        throw new Error('Biometric registration was cancelled or failed.');
      }

      const rawIdBase64 = arrayBufferToBase64URL(credential.rawId);
      const clientDataJSON = arrayBufferToBase64URL(credential.response.clientDataJSON);
      const attestationObject = credential.response.attestationObject
        ? arrayBufferToBase64URL(credential.response.attestationObject)
        : '';

      const payload = {
        credentialId: credential.id || rawIdBase64,
        rawId: rawIdBase64,
        clientDataJSON,
        attestationObject,
        transports: credential.response.getTransports ? credential.response.getTransports() : ['internal']
      };

      // Send to server registration endpoint
      const isStudentSession = !!(localStorage.getItem('student_token') || window.location.pathname.includes('student') || window.location.hash.includes('portal'));
      const registerEndpoint = isStudentSession ? '/api/student-portal/biometric/register' : '/api/auth/biometric/register';
      const res = await api.post(registerEndpoint, payload);

      if (res.success) {
        localStorage.setItem('sl_biometric_registered', 'true');
        localStorage.setItem('sl_biometric_cred_id', credential.id || rawIdBase64);
        if (currentUser.email || currentUser.phone) {
          localStorage.setItem('sl_biometric_user_email', currentUser.email || currentUser.phone || currentUser.studentId || '');
        }
        Toast.success('👆 Biometric / Face ID Login successfully enabled on this device!');
      } else {
        Toast.error(res.message || 'Failed to save biometric credential on server.');
      }

      return res;
    } catch (err) {
      console.error('Biometric registration error:', err);
      if (err.name !== 'NotAllowedError') {
        Toast.error(err.message || 'Biometric registration failed');
      } else {
        Toast.info('Biometric prompt cancelled.');
      }
      throw err;
    }
  },

  /**
   * Prompts user for biometric authentication and logs in without password.
   * Sends assertion to POST /api/auth/biometric/login.
   */
  async login() {
    try {
      const supported = await this.isSupported();
      if (!supported) {
        throw new Error('WebAuthn biometrics not supported on this browser/device');
      }

      const savedCredId = localStorage.getItem('sl_biometric_cred_id');
      const challengeBytes = new Uint8Array(32);
      window.crypto.getRandomValues(challengeBytes);

      const allowCredentials = [];
      if (savedCredId) {
        try {
          const rawId = Uint8Array.from(atob(savedCredId.replace(/-/g, '+').replace(/_/g, '/')), c => c.charCodeAt(0));
          allowCredentials.push({
            id: rawId,
            type: 'public-key'
          });
        } catch (e) {}
      }

      const options = {
        publicKey: {
          challenge: challengeBytes,
          timeout: 60000,
          userVerification: 'preferred'
        }
      };

      if (allowCredentials.length > 0) {
        options.publicKey.allowCredentials = allowCredentials;
      }

      const credential = await navigator.credentials.get(options);
      if (!credential) {
        throw new Error('Biometric assertion failed');
      }

      const rawIdBase64 = btoa(String.fromCharCode(...new Uint8Array(credential.rawId)));
      const clientDataJSON = btoa(String.fromCharCode(...new Uint8Array(credential.response.clientDataJSON)));
      const authenticatorData = btoa(String.fromCharCode(...new Uint8Array(credential.response.authenticatorData)));
      const signature = btoa(String.fromCharCode(...new Uint8Array(credential.response.signature)));

      const payload = {
        credentialId: credential.id || rawIdBase64,
        authenticatorData,
        clientDataJSON,
        signature,
        savedEmail: localStorage.getItem('sl_biometric_user_email') || ''
      };

      const res = await api.post('/api/auth/biometric/login', payload);

      if (res.success && res.data?.token) {
        localStorage.setItem('sl_biometric_registered', 'true');

        if (res.data.isStudent || res.data.student) {
          localStorage.setItem('sl_token', res.data.token);
          localStorage.setItem('student_token', res.data.token);
          localStorage.setItem('sl_user_role', 'student');
          if (res.data.student) {
            localStorage.setItem('sl_student_user', JSON.stringify(res.data.student));
          }
          Toast.success(`🎓 Student Biometric Verified! Welcome back, ${res.data.student?.name || 'Student'}.`);
          setTimeout(() => {
            window.location.href = '/#/portal';
          }, 400);
        } else {
          localStorage.setItem('sl_token', res.data.token);
          Toast.success(`👆 Biometric Verified! Welcome back, ${res.data.user?.name || 'User'}.`);
          const { App } = await import('../app.js');
          App.init();
        }
      } else {
        Toast.error(res.message || 'Biometric login failed.');
      }
    } catch (err) {
      console.error('Biometric login error:', err);
      if (err.name !== 'NotAllowedError') {
        Toast.error(err.message || 'Biometric login failed.');
      } else {
        Toast.info('Biometric prompt cancelled.');
      }
      throw err;
    }
  }
};

export default BiometricAuth;
