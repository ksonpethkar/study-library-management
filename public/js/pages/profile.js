import api from '../api.js';
import { Toast, Modal, Confirm, Loading, escapeHTML } from '../ui.js';
import { t } from '../i18n.js';
import { BiometricAuth } from '../utils/biometricAuth.js';

export async function render() {
  const container = document.createElement('div');
  container.className = 'page-container';

  container.innerHTML = `
    <!-- Standard Module Header -->
    <div class="module-header">
      <div class="module-title-area">
        <h2>👤 My Account & Security</h2>
        <p>Manage your personal admin profile credentials, contact info, and login password.</p>
      </div>
    </div>
    <div class="card" style="padding: 2.5rem; text-align: center;">
      <div class="loading-spinner" style="margin: 0 auto 1rem auto;"></div>
      <p style="color: var(--color-text-secondary); margin: 0;">Loading account profile...</p>
    </div>
  `;

  try {
    const res = await api.get('/api/auth/me');
    const user = res?.data || res || {};
    renderProfileUI(container, user);
  } catch (error) {
    console.error('Failed to load profile:', error);
    container.innerHTML = `
      <div class="page-header mb-4">
        <h2 style="margin: 0; font-size: 1.6rem; font-weight: 700; color: var(--color-text-primary);">My Account & Security</h2>
      </div>
      <div class="card" style="padding: 2rem; border-color: var(--color-danger); text-align: center;">
        <div style="font-size: 2.5rem; margin-bottom: 0.5rem;">⚠️</div>
        <h3 style="color: var(--color-danger); margin-bottom: 0.5rem;">Failed to load user profile</h3>
        <p style="color: var(--color-text-secondary); margin-bottom: 1.5rem;">${escapeHTML(error.message || 'Could not fetch current user details.')}</p>
        <button id="btn-retry-profile" class="btn btn-primary">Retry</button>
      </div>
    `;
    container.querySelector('#btn-retry-profile')?.addEventListener('click', () => render());
  }

  return container;
}

function renderProfileUI(container, user) {
  const initials = (user.name || 'Admin')
    .split(' ')
    .map(w => w[0])
    .join('')
    .toUpperCase()
    .slice(0, 2);

  const roleLabels = {
    owner: '👑 Owner / Super Admin',
    branch_manager: '🏢 Branch Manager',
    student: '🎓 Student'
  };
  const roleDisplay = roleLabels[user.role] || user.role || 'Admin';

  const lastLoginFormatted = user.lastLogin
    ? new Date(user.lastLogin).toLocaleString('en-IN', {
        dateStyle: 'medium',
        timeStyle: 'short'
      })
    : 'Active now';

  const memberSinceFormatted = user.createdAt
    ? new Date(user.createdAt).toLocaleDateString('en-IN', {
        dateStyle: 'medium'
      })
    : 'Recently';

  container.innerHTML = `
    <!-- Standard Module Header -->
    <div class="module-header">
      <div class="module-title-area">
        <h2>👤 My Account & Security</h2>
        <p>Manage your personal admin profile credentials, contact info, and login password.</p>
      </div>
    </div>

    <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(420px, 1fr)); gap: 1.25rem; align-items: start;">
      
      <!-- ========================================== -->
      <!-- CARD 1: ADMIN PROFILE OVERVIEW & EDIT -->
      <!-- ========================================== -->
      <div class="card" style="background: var(--color-surface); border: 1px solid var(--color-border); border-radius: var(--radius-lg); overflow: hidden; box-shadow: var(--shadow-sm);">
        <div class="card-header" style="padding: 1.25rem 1.5rem; border-bottom: 1px solid var(--color-divider); background: var(--color-surface-hover); display: flex; justify-content: space-between; align-items: center;">
          <h3 style="margin: 0; font-size: 1.15rem; font-weight: 600; color: var(--color-text-primary); display: flex; align-items: center; gap: 0.5rem;">
            <span>👤</span> Admin Profile Details
          </h3>
          <span class="badge" style="background: var(--color-primary-bg); color: var(--color-primary); border: 1px solid var(--color-primary-light); padding: 4px 10px; border-radius: 20px; font-weight: 600; font-size: 0.8rem;">
            ${escapeHTML(roleDisplay)}
          </span>
        </div>

        <div class="card-body" style="padding: 1.5rem;">
          
          <!-- Summary Row (Avatar + Key Meta) -->
          <div style="display: flex; align-items: center; gap: 1.5rem; padding-bottom: 1.5rem; margin-bottom: 1.5rem; border-bottom: 1px solid var(--color-divider); flex-wrap: wrap;">
            
            <div style="display: flex; flex-direction: column; align-items: center; gap: 10px;">
              <div id="profile-avatar-display" style="width: 96px; height: 96px; border-radius: 50%; background: linear-gradient(135deg, var(--color-primary), var(--color-primary-dark)); color: #fff; display: flex; align-items: center; justify-content: center; font-size: 2.2rem; font-weight: 700; box-shadow: 0 4px 14px rgba(108, 92, 231, 0.35); overflow: hidden; border: 3px solid var(--color-surface); position: relative;">
                <img id="profile-avatar-img" src="${escapeHTML(user.avatar || '')}" alt="Avatar" style="width: 100%; height: 100%; object-fit: cover; display: ${user.avatar ? 'block' : 'none'};" onerror="this.style.display='none'; document.getElementById('profile-avatar-initials').style.display='block';">
                <span id="profile-avatar-initials" style="display: ${user.avatar ? 'none' : 'block'};">${escapeHTML(initials)}</span>
              </div>

              <div style="display: flex; gap: 6px; flex-wrap: wrap; justify-content: center;">
                <button type="button" id="btn-upload-avatar-file" class="btn btn-xs btn-outline-primary" style="font-weight: 600; padding: 4px 10px; font-size: 0.78rem;">
                  📁 Upload Photo
                </button>
                <button type="button" id="btn-take-avatar-cam" class="btn btn-xs btn-primary" style="font-weight: 600; padding: 4px 10px; font-size: 0.78rem;">
                  📸 Live Selfie
                </button>
                <button type="button" id="btn-remove-avatar" class="btn btn-xs btn-outline-danger" style="font-weight: 600; padding: 4px 10px; font-size: 0.78rem; display: ${user.avatar ? 'inline-flex' : 'none'};">
                  🗑️ Remove
                </button>
                <input type="file" id="input-avatar-file" accept="image/*" style="display: none;">
              </div>
            </div>

            <div style="flex: 1; min-width: 240px;">
              <div style="display: flex; align-items: center; gap: 0.5rem; flex-wrap: wrap;">
                <h3 id="display-user-name" style="margin: 0; font-size: 1.35rem; font-weight: 700; color: var(--color-text-primary);">${escapeHTML(user.name || 'Administrator')}</h3>
              </div>
              <div id="display-user-email" style="color: var(--color-text-secondary); font-size: 0.95rem; margin-top: 2px;">${escapeHTML(user.email || '')}</div>
              
              <div style="display: flex; gap: 1.25rem; margin-top: 0.75rem; flex-wrap: wrap; font-size: 0.85rem; color: var(--color-text-secondary);">
                <div style="display: flex; align-items: center; gap: 0.35rem;">
                  <span>🕒</span> Last Login: <strong id="display-user-lastlogin" style="color: var(--color-text-primary);">${escapeHTML(lastLoginFormatted)}</strong>
                </div>
                <div style="display: flex; align-items: center; gap: 0.35rem;">
                  <span>📅</span> Member Since: <strong style="color: var(--color-text-primary);">${escapeHTML(memberSinceFormatted)}</strong>
                </div>
              </div>
            </div>

          </div>

          <!-- Edit Profile Form -->
          <form id="form-edit-profile">
            <input type="hidden" id="profile-avatar" value="${escapeHTML(user.avatar || '')}">
            <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(260px, 1fr)); gap: 1.25rem; margin-bottom: 1.25rem;">
              
              <div class="form-group">
                <label class="form-label" for="profile-name" style="font-weight: 600;">Full Name *</label>
                <input type="text" id="profile-name" class="form-control" required value="${escapeHTML(user.name || '')}" placeholder="e.g. John Doe">
              </div>

              <div class="form-group">
                <label class="form-label" for="profile-email" style="font-weight: 600;">Email Address *</label>
                <input type="email" id="profile-email" class="form-control" required value="${escapeHTML(user.email || '')}" placeholder="admin@example.com">
              </div>

            </div>

            <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(260px, 1fr)); gap: 1.25rem; margin-bottom: 1.5rem;">
              
              <div class="form-group">
                <label class="form-label" for="profile-phone" style="font-weight: 600;">Phone Number</label>
                <input type="text" id="profile-phone" class="form-control" value="${escapeHTML(user.phone || '')}" placeholder="+91 98765 43210">
              </div>

              <div class="form-group">
                <label class="form-label" for="profile-avatar" style="font-weight: 600;">Avatar Image URL</label>
                <input type="url" id="profile-avatar" class="form-control" value="${escapeHTML(user.avatar || '')}" placeholder="Paste image URL or upload photo above">
                <small style="color: var(--color-text-secondary); display: block; margin-top: 4px;">Upload photo/selfie above or paste a custom image URL (leave blank for initials).</small>
              </div>

            </div>

            <div style="display: flex; justify-content: flex-end;">
              <button type="submit" id="btn-save-profile" class="btn btn-primary" style="font-weight: 600; min-width: 140px;">
                Save Profile
              </button>
            </div>
          </form>

        </div>
      </div>

      <!-- ========================================== -->
      <!-- CARD 2: SECURITY & PASSWORD CHANGE -->
      <!-- ========================================== -->
      <div class="card" style="background: var(--color-surface); border: 1px solid var(--color-border); border-radius: var(--radius-lg); overflow: hidden; box-shadow: var(--shadow-sm);">
        <div class="card-header" style="padding: 1.25rem 1.5rem; border-bottom: 1px solid var(--color-divider); background: var(--color-surface-hover); display: flex; justify-content: space-between; align-items: center;">
          <h3 style="margin: 0; font-size: 1.15rem; font-weight: 600; color: var(--color-text-primary); display: flex; align-items: center; gap: 0.5rem;">
            <span>🔒</span> Security & Password
          </h3>
          <span style="font-size: 0.8rem; color: var(--color-text-secondary);">Protect your admin session</span>
        </div>

        <div class="card-body" style="padding: 1.5rem;">
          <!-- Biometric WebAuthn Section -->
          <div style="background: var(--color-bg-secondary); border: 1px solid var(--color-border); border-radius: var(--radius-md); padding: 1.25rem; margin-bottom: 1.5rem;">
            <div style="display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 12px;">
              <div>
                <h4 style="margin: 0; font-size: 1rem; font-weight: 700; color: var(--color-text-primary); display: flex; align-items: center; gap: 6px;">
                  <span>👆</span> Biometric & Touch ID / Face ID Authentication
                </h4>
                <p style="margin: 4px 0 0 0; font-size: 0.83rem; color: var(--color-text-secondary);">
                  Log in instantly without typing your password using your device's biometric sensor.
                </p>
              </div>
              <button type="button" id="btn-enable-biometric" class="btn btn-outline-primary" style="font-weight: 700; display: flex; align-items: center; gap: 6px;">
                👆 Enable Biometric / Face ID Login on this Device
              </button>
            </div>
          </div>

          <form id="form-change-password">
            
            <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(260px, 1fr)); gap: 1.25rem; margin-bottom: 1.25rem;">
              
              <!-- Current Password -->
              <div class="form-group">
                <label class="form-label" for="pwd-current" style="font-weight: 600;">Current Password *</label>
                <div style="position: relative;">
                  <input type="password" id="pwd-current" class="form-control" required placeholder="Enter existing password" style="padding-right: 40px;">
                  <button type="button" class="btn-toggle-pwd" data-target="pwd-current" style="position: absolute; right: 8px; top: 50%; transform: translateY(-50%); background: none; border: none; color: var(--color-text-secondary); cursor: pointer; padding: 4px;">
                    👁️
                  </button>
                </div>
              </div>

              <!-- New Password -->
              <div class="form-group">
                <label class="form-label" for="pwd-new" style="font-weight: 600;">New Password *</label>
                <div style="position: relative;">
                  <input type="password" id="pwd-new" class="form-control" required placeholder="At least 6 characters" minlength="6" style="padding-right: 40px;">
                  <button type="button" class="btn-toggle-pwd" data-target="pwd-new" style="position: absolute; right: 8px; top: 50%; transform: translateY(-50%); background: none; border: none; color: var(--color-text-secondary); cursor: pointer; padding: 4px;">
                    👁️
                  </button>
                </div>
              </div>

              <!-- Confirm New Password -->
              <div class="form-group">
                <label class="form-label" for="pwd-confirm" style="font-weight: 600;">Confirm New Password *</label>
                <div style="position: relative;">
                  <input type="password" id="pwd-confirm" class="form-control" required placeholder="Re-enter new password" minlength="6" style="padding-right: 40px;">
                  <button type="button" class="btn-toggle-pwd" data-target="pwd-confirm" style="position: absolute; right: 8px; top: 50%; transform: translateY(-50%); background: none; border: none; color: var(--color-text-secondary); cursor: pointer; padding: 4px;">
                    👁️
                  </button>
                </div>
              </div>

            </div>

            <!-- Security Checklist -->
            <div style="background: var(--color-bg-primary); border: 1px solid var(--color-border); border-radius: var(--radius-md); padding: 1rem 1.25rem; margin-bottom: 1.5rem;">
              <div style="font-size: 0.85rem; font-weight: 600; color: var(--color-text-primary); margin-bottom: 0.5rem;">
                Password Security Checklist
              </div>
              <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 0.5rem; font-size: 0.85rem;">
                <div id="rule-len" style="display: flex; align-items: center; gap: 0.4rem; color: var(--color-text-muted);">
                  <span class="rule-icon">⚪</span> At least 6 characters
                </div>
                <div id="rule-match" style="display: flex; align-items: center; gap: 0.4rem; color: var(--color-text-muted);">
                  <span class="rule-icon">⚪</span> Passwords match
                </div>
                <div id="rule-diff" style="display: flex; align-items: center; gap: 0.4rem; color: var(--color-text-muted);">
                  <span class="rule-icon">⚪</span> Different from current
                </div>
              </div>
            </div>

            <div style="display: flex; justify-content: flex-end;">
              <button type="submit" id="btn-change-password" class="btn btn-primary" style="font-weight: 600; min-width: 170px;">
                Update Password
              </button>
            </div>

          </form>
        </div>
      </div>

    </div>
  `;

  // Avatar upload, live selfie & remove event handlers
  const avatarHiddenInput = container.querySelector('#profile-avatar');
  const avatarImg = container.querySelector('#profile-avatar-img');
  const avatarInitials = container.querySelector('#profile-avatar-initials');
  const btnUploadFile = container.querySelector('#btn-upload-avatar-file');
  const btnTakeCam = container.querySelector('#btn-take-avatar-cam');
  const btnRemoveAvatar = container.querySelector('#btn-remove-avatar');
  const inputAvatarFile = container.querySelector('#input-avatar-file');

  const updateAvatarPreview = (url) => {
    if (url) {
      avatarHiddenInput.value = url;
      avatarImg.src = url;
      avatarImg.style.display = 'block';
      avatarInitials.style.display = 'none';
      btnRemoveAvatar.style.display = 'inline-flex';
    } else {
      avatarHiddenInput.value = '';
      avatarImg.style.display = 'none';
      avatarInitials.style.display = 'block';
      btnRemoveAvatar.style.display = 'none';
    }
  };

  btnUploadFile?.addEventListener('click', () => {
    inputAvatarFile.click();
  });

  inputAvatarFile?.addEventListener('change', async (e) => {
    const file = e.target.files[0];
    if (!file) return;
    try {
      Loading.button(btnUploadFile, true);
      const compressedDataUrl = await ImageCompressor.compress(file, { maxWidth: 300, maxHeight: 300, quality: 0.82 });
      const uploadRes = await api.post('/api/upload', { image: compressedDataUrl });
      if (uploadRes.success && uploadRes.url) {
        updateAvatarPreview(uploadRes.url);
        Toast.success('Profile photo uploaded & compressed successfully!');
      } else {
        Toast.error(uploadRes.message || 'Upload failed');
      }
    } catch (err) {
      Toast.error(err.message || 'Image processing failed');
    } finally {
      Loading.button(btnUploadFile, false);
      inputAvatarFile.value = '';
    }
  });

  btnTakeCam?.addEventListener('click', async () => {
    try {
      const selfieDataUrl = await ImageCompressor.captureWebcam({ maxWidth: 300, maxHeight: 300, quality: 0.82 });
      Loading.button(btnTakeCam, true);
      const uploadRes = await api.post('/api/upload', { image: selfieDataUrl });
      if (uploadRes.success && uploadRes.url) {
        updateAvatarPreview(uploadRes.url);
        Toast.success('Live selfie captured & uploaded!');
      } else {
        Toast.error(uploadRes.message || 'Upload failed');
      }
    } catch (err) {
      if (err.message !== 'Camera capture cancelled') {
        Toast.error(err.message || 'Camera capture failed');
      }
    } finally {
      Loading.button(btnTakeCam, false);
    }
  });

  btnRemoveAvatar?.addEventListener('click', () => {
    updateAvatarPreview('');
    Toast.info('Profile picture removed');
  });

  // Password visibility toggle
  container.querySelectorAll('.btn-toggle-pwd').forEach(btn => {
    btn.addEventListener('click', () => {
      const targetId = btn.dataset.target;
      const input = container.querySelector(`#${targetId}`);
      if (input) {
        input.type = input.type === 'password' ? 'text' : 'password';
      }
    });
  });

  // Password checklist validator
  const currentPwdInput = container.querySelector('#pwd-current');
  const newPwdInput = container.querySelector('#pwd-new');
  const confirmPwdInput = container.querySelector('#pwd-confirm');

  const ruleLen = container.querySelector('#rule-len');
  const ruleMatch = container.querySelector('#rule-match');
  const ruleDiff = container.querySelector('#rule-diff');

  function checkPasswordRules() {
    const current = currentPwdInput?.value || '';
    const newPwd = newPwdInput?.value || '';
    const confirmPwd = confirmPwdInput?.value || '';

    // Rule 1: Length >= 6
    if (newPwd.length >= 6) {
      ruleLen.style.color = 'var(--color-success)';
      ruleLen.querySelector('.rule-icon').textContent = '✅';
    } else {
      ruleLen.style.color = 'var(--color-text-muted)';
      ruleLen.querySelector('.rule-icon').textContent = '⚪';
    }

    // Rule 2: Passwords match
    if (newPwd && newPwd === confirmPwd) {
      ruleMatch.style.color = 'var(--color-success)';
      ruleMatch.querySelector('.rule-icon').textContent = '✅';
    } else {
      ruleMatch.style.color = 'var(--color-text-muted)';
      ruleMatch.querySelector('.rule-icon').textContent = '⚪';
    }

    // Rule 3: Different from current
    if (newPwd && current && newPwd !== current) {
      ruleDiff.style.color = 'var(--color-success)';
      ruleDiff.querySelector('.rule-icon').textContent = '✅';
    } else {
      ruleDiff.style.color = 'var(--color-text-muted)';
      ruleDiff.querySelector('.rule-icon').textContent = '⚪';
    }
  }

  newPwdInput?.addEventListener('input', checkPasswordRules);
  confirmPwdInput?.addEventListener('input', checkPasswordRules);
  currentPwdInput?.addEventListener('input', checkPasswordRules);

  // Profile update submission
  container.querySelector('#form-edit-profile')?.addEventListener('submit', async (e) => {
    e.preventDefault();
    const btn = container.querySelector('#btn-save-profile');
    Loading.button(btn, true);

    const name = container.querySelector('#profile-name')?.value?.trim();
    const email = container.querySelector('#profile-email')?.value?.trim();
    const phone = container.querySelector('#profile-phone')?.value?.trim();
    const avatar = container.querySelector('#profile-avatar')?.value?.trim();

    try {
      const res = await api.put('/api/settings/admin-profile', {
        name,
        email,
        phone,
        avatar
      });

      const updated = res.data || {};

      // Update header & sidebar avatar dynamically
      if (typeof window.updateProfileAvatar === 'function') {
        window.updateProfileAvatar(updated.avatar || avatar);
      }

      // Update display text on profile card
      const displayName = container.querySelector('#display-user-name');
      if (displayName) displayName.textContent = updated.name || name;
      const displayEmail = container.querySelector('#display-user-email');
      if (displayEmail) displayEmail.textContent = updated.email || email;

      Toast.success(res?.message || 'Admin profile updated successfully');
    } catch (err) {
      Toast.error(err.message || 'Failed to update admin profile');
    } finally {
      Loading.button(btn, false);
    }
  });

  // Password change submission
  container.querySelector('#form-change-password')?.addEventListener('submit', async (e) => {
    e.preventDefault();
    const currentPassword = currentPwdInput?.value;
    const newPassword = newPwdInput?.value;
    const confirmPassword = confirmPwdInput?.value;

    if (!currentPassword) {
      Toast.warning('Please enter your current password');
      currentPwdInput?.focus();
      return;
    }

    if (!newPassword || newPassword.length < 6) {
      Toast.warning('New password must be at least 6 characters');
      newPwdInput?.focus();
      return;
    }

    if (newPassword !== confirmPassword) {
      Toast.error('New password and confirm password do not match');
      confirmPwdInput?.focus();
      return;
    }

    if (currentPassword === newPassword) {
      Toast.warning('New password must be different from current password');
      newPwdInput?.focus();
      return;
    }

    const btn = container.querySelector('#btn-change-password');
    Loading.button(btn, true);

    try {
      const res = await api.post('/api/settings/change-password', {
        currentPassword,
        newPassword
      });

      Toast.success(res?.message || 'Password changed successfully!');
      
      // Clear password fields
      currentPwdInput.value = '';
      newPwdInput.value = '';
      confirmPwdInput.value = '';
      checkPasswordRules();
    } catch (err) {
      Toast.error(err.message || 'Failed to change password. Check your current password.');
    } finally {
      Loading.button(btn, false);
    }
  });

  // Biometric registration button handler
  const btnEnableBiometric = container.querySelector('#btn-enable-biometric');
  if (btnEnableBiometric) {
    BiometricAuth.isSupported().then(supported => {
      if (!supported) {
        btnEnableBiometric.disabled = true;
        btnEnableBiometric.title = 'Biometrics not supported on this browser or device';
      }
    });

    btnEnableBiometric.addEventListener('click', async () => {
      try {
        Loading.button(btnEnableBiometric, true);
        await BiometricAuth.register(user);
      } catch (err) {
        // Handled inside BiometricAuth.register()
      } finally {
        Loading.button(btnEnableBiometric, false);
      }
    });
  }
}
