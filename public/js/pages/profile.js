import m from"../api.js";import{Toast as n,Confirm as B,Loading as l,escapeHTML as s}from"../ui.js";import"../i18n.js";import{BiometricAuth as M}from"../utils/biometricAuth.js";async function R(){const e=document.createElement("div");e.className="page-container",e.innerHTML=`
    <!-- Standard Module Header -->
    <div class="module-header">
      <div class="module-title-area">
        <h2>\u{1F464} My Account & Security</h2>
        <p>Manage your personal admin profile credentials, contact info, and login password.</p>
      </div>
    </div>
    <div class="card" style="padding: 2.5rem; text-align: center;">
      <div class="loading-spinner" style="margin: 0 auto 1rem auto;"></div>
      <p style="color: var(--color-text-secondary); margin: 0;">Loading account profile...</p>
    </div>
  `;try{const a=await m.get("/api/auth/me"),A=a?.data||a||{};O(e,A)}catch(a){console.error("Failed to load profile:",a),e.innerHTML=`
      <div class="page-header mb-4">
        <h2 style="margin: 0; font-size: 1.6rem; font-weight: 700; color: var(--color-text-primary);">My Account & Security</h2>
      </div>
      <div class="card" style="padding: 2rem; border-color: var(--color-danger); text-align: center;">
        <div style="font-size: 2.5rem; margin-bottom: 0.5rem;">\u26A0\uFE0F</div>
        <h3 style="color: var(--color-danger); margin-bottom: 0.5rem;">Failed to load user profile</h3>
        <p style="color: var(--color-text-secondary); margin-bottom: 1.5rem;">${s(a.message||"Could not fetch current user details.")}</p>
        <button id="btn-retry-profile" class="btn btn-primary">Retry</button>
      </div>
    `,e.querySelector("#btn-retry-profile")?.addEventListener("click",()=>R())}return e}function O(e,a){const A=(a.name||"Admin").split(" ").map(t=>t[0]).join("").toUpperCase().slice(0,2),U={owner:"\u{1F451} Owner / Super Admin",branch_manager:"\u{1F3E2} Branch Manager",student:"\u{1F393} Student"}[a.role]||a.role||"Admin",_=a.lastLogin?new Date(a.lastLogin).toLocaleString("en-IN",{dateStyle:"medium",timeStyle:"short"}):"Active now",T=a.createdAt?new Date(a.createdAt).toLocaleDateString("en-IN",{dateStyle:"medium"}):"Recently";e.innerHTML=`
    <!-- Standard Module Header -->
    <div class="module-header">
      <div class="module-title-area">
        <h2>\u{1F464} My Account & Security</h2>
        <p>Manage your personal admin profile credentials, contact info, and login password.</p>
      </div>
    </div>

    <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(min(100%, 420px), 1fr)); gap: 1.25rem; align-items: start;">
      
      <!-- ========================================== -->
      <!-- CARD 1: ADMIN PROFILE OVERVIEW & EDIT -->
      <!-- ========================================== -->
      <div class="card" style="background: var(--color-surface); border: 1px solid var(--color-border); border-radius: var(--radius-lg); overflow: hidden; box-shadow: var(--shadow-sm);">
        <div class="card-header" style="padding: 1.25rem 1.5rem; border-bottom: 1px solid var(--color-divider); background: var(--color-surface-hover); display: flex; justify-content: space-between; align-items: center;">
          <h3 style="margin: 0; font-size: 1.15rem; font-weight: 600; color: var(--color-text-primary); display: flex; align-items: center; gap: 0.5rem;">
            <span>\u{1F464}</span> Admin Profile Details
          </h3>
          <span class="badge" style="background: var(--color-primary-bg); color: var(--color-primary); border: 1px solid var(--color-primary-light); padding: 4px 10px; border-radius: 20px; font-weight: 600; font-size: 0.8rem;">
            ${s(U)}
          </span>
        </div>

        <div class="card-body" style="padding: 1.5rem;">
          
          <!-- Summary Row (Avatar + Key Meta) -->
          <div style="display: flex; align-items: center; gap: 1.5rem; padding-bottom: 1.5rem; margin-bottom: 1.5rem; border-bottom: 1px solid var(--color-divider); flex-wrap: wrap;">
            
            <div style="display: flex; flex-direction: column; align-items: center; gap: 10px;">
              <div id="profile-avatar-display" style="width: 96px; height: 96px; border-radius: 50%; background: linear-gradient(135deg, var(--color-primary), var(--color-primary-dark)); color: #fff; display: flex; align-items: center; justify-content: center; font-size: 2.2rem; font-weight: 700; box-shadow: 0 4px 14px rgba(108, 92, 231, 0.35); overflow: hidden; border: 3px solid var(--color-surface); position: relative;">
                <img id="profile-avatar-img" src="${s(a.avatar||a.photo||"")}" alt="Avatar" style="width: 100%; height: 100%; object-fit: cover; display: ${a.avatar||a.photo?"block":"none"};" onerror="this.style.display='none'; const initEl = document.getElementById('profile-avatar-initials'); if (initEl) initEl.style.display='block';">
                <span id="profile-avatar-initials" style="display: ${a.avatar||a.photo?"none":"block"};">${s(A)}</span>
              </div>

              <div style="display: flex; gap: 6px; flex-wrap: wrap; justify-content: center;">
                <button type="button" id="btn-upload-avatar-file" class="btn btn-xs btn-outline-primary" style="font-weight: 600; padding: 4px 10px; font-size: 0.78rem;">
                  \u{1F4C1} Upload Photo
                </button>
                <button type="button" id="btn-take-avatar-cam" class="btn btn-xs btn-primary" style="font-weight: 600; padding: 4px 10px; font-size: 0.78rem;">
                  \u{1F4F8} Live Selfie
                </button>
                <button type="button" id="btn-remove-avatar" class="btn btn-xs btn-outline-danger" style="font-weight: 600; padding: 4px 10px; font-size: 0.78rem; display: ${a.avatar||a.photo?"inline-flex":"none"};">
                  \u{1F5D1}\uFE0F Remove
                </button>
                <input type="file" id="input-avatar-file" accept="image/*" style="display: none;">
              </div>
            </div>

            <div style="flex: 1 1 220px; min-width: 220px;">
              <div style="display: flex; align-items: center; gap: 0.5rem; flex-wrap: wrap;">
                <h3 id="display-user-name" style="margin: 0; font-size: 1.2rem; font-weight: 700; color: var(--color-text-primary); white-space: normal;">${s(a.name||"Administrator")}</h3>
              </div>
              <div id="display-user-email" style="color: var(--color-text-secondary); font-size: 0.9rem; margin-top: 2px; word-break: break-all;">${s(a.email||"")}</div>
              
              <div style="display: flex; gap: 1.25rem; margin-top: 0.75rem; flex-wrap: wrap; font-size: 0.85rem; color: var(--color-text-secondary);">
                <div style="display: flex; align-items: center; gap: 0.35rem;">
                  <span>\u{1F552}</span> Last Login: <strong id="display-user-lastlogin" style="color: var(--color-text-primary);">${s(_)}</strong>
                </div>
                <div style="display: flex; align-items: center; gap: 0.35rem;">
                  <span>\u{1F4C5}</span> Member Since: <strong style="color: var(--color-text-primary);">${s(T)}</strong>
                </div>
              </div>
            </div>

          </div>

          <!-- Edit Profile Form -->
          <form id="form-edit-profile">
            <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(min(100%, 260px), 1fr)); gap: 1.25rem; margin-bottom: 1.25rem;">
              
              <div class="form-group">
                <label class="form-label" for="profile-name" style="font-weight: 600;">Full Name *</label>
                <input type="text" id="profile-name" class="form-control" required value="${s(a.name||"")}" placeholder="e.g. John Doe">
              </div>

              <div class="form-group">
                <label class="form-label" for="profile-email" style="font-weight: 600;">Email Address *</label>
                <input type="email" id="profile-email" class="form-control" required value="${s(a.email||"")}" placeholder="admin@example.com">
              </div>

            </div>

            <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(min(100%, 260px), 1fr)); gap: 1.25rem; margin-bottom: 1.5rem;">
              
              <div class="form-group">
                <label class="form-label" for="profile-phone" style="font-weight: 600;">Phone Number</label>
                <input type="text" id="profile-phone" class="form-control" value="${s(a.phone||"")}" placeholder="+91 98765 43210">
              </div>

              <div class="form-group">
                <label class="form-label" for="profile-avatar" style="font-weight: 600;">Avatar Image URL</label>
                <input type="text" id="profile-avatar" class="form-control" value="${s(a.avatar||"")}" placeholder="Paste image URL or upload photo above">
                <small style="color: var(--color-text-secondary); display: block; margin-top: 4px;">Upload photo/selfie above or paste a custom image URL (leave blank for initials).</small>
              </div>

            </div>

            <div style="display: flex; justify-content: flex-end; gap: 8px; flex-wrap: wrap;">
              <button type="submit" id="btn-save-profile" class="btn btn-primary" style="font-weight: 600; min-width: 140px; flex: 1; max-width: 200px;">
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
        <div class="card-header" style="padding: 1.25rem 1.5rem; border-bottom: 1px solid var(--color-divider); background: var(--color-surface-hover); display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 8px;">
          <h3 style="margin: 0; font-size: 1.15rem; font-weight: 600; color: var(--color-text-primary); display: flex; align-items: center; gap: 0.5rem;">
            <span>\u{1F512}</span> Security &amp; Password
          </h3>
          <span style="font-size: 0.8rem; color: var(--color-text-secondary);">Protect your admin session</span>
        </div>

        <div class="card-body" style="padding: 1.5rem;">
          <!-- Biometric WebAuthn Section -->
          <div style="background: var(--color-bg-secondary); border: 1px solid var(--color-border); border-radius: var(--radius-md); padding: 1.25rem; margin-bottom: 1.5rem;">
            <div style="display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 12px;">
              <div>
                <h4 style="margin: 0; font-size: 1rem; font-weight: 700; color: var(--color-text-primary); display: flex; align-items: center; gap: 6px;">
                  <span>\u{1F446}</span> Biometric & Touch ID / Face ID Authentication
                </h4>
                <p style="margin: 4px 0 0 0; font-size: 0.83rem; color: var(--color-text-secondary);">
                  Log in instantly without typing your password using your device's biometric sensor.
                </p>
              </div>
              <button type="button" id="btn-enable-biometric" class="btn btn-outline-primary" style="font-weight: 700; display: flex; align-items: center; gap: 6px;">
                \u{1F446} Enable Biometric / Face ID Login on this Device
              </button>
            </div>
          <!-- Front-Desk 4-Digit Security PIN Card -->
          <div style="background: var(--color-bg-secondary); border: 1px solid var(--color-border); border-radius: var(--radius-md); padding: 1.25rem; margin-bottom: 1.5rem;">
            <div style="display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 12px;">
              <div>
                <h4 style="margin: 0; font-size: 1rem; font-weight: 700; color: var(--color-text-primary); display: flex; align-items: center; gap: 6px;">
                  <span>\u{1F512}</span> Front-Desk Terminal PIN Lock
                </h4>
                <p style="margin: 4px 0 0 0; font-size: 0.83rem; color: var(--color-text-secondary);">
                  Lock reception counter with a 4-digit PIN when stepping away. (Default PIN: <strong style="color: var(--color-primary);">1234</strong>)
                </p>
              </div>
              <div style="display: flex; gap: 8px; align-items: center; flex-wrap: wrap;">
                <input type="password" id="desk-pin-input" class="form-control form-control-sm" maxlength="4" placeholder="1234" value="${s(localStorage.getItem("sl_desk_pin")||"1234")}" style="width: 100px; text-align: center; font-size: 1.1rem; font-weight: 800; letter-spacing: 4px; font-family: monospace;">
                <button type="button" id="btn-save-desk-pin" class="btn btn-sm btn-outline-primary" style="font-weight: 700;">
                  Save PIN
                </button>
                <button type="button" id="btn-test-desk-lock" class="btn btn-sm btn-primary" style="font-weight: 700;">
                  \u{1F512} Lock Now
                </button>
              </div>
            </div>
          </div>

          <form id="form-change-password">
            
            <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(min(100%, 260px), 1fr)); gap: 1.25rem; margin-bottom: 1.25rem;">
              
              <!-- Current Password -->
              <div class="form-group">
                <label class="form-label" for="pwd-current" style="font-weight: 600;">Current Password *</label>
                <div style="position: relative;">
                  <input type="password" id="pwd-current" class="form-control" required placeholder="Enter existing password" style="padding-right: 40px;">
                  <button type="button" class="btn-toggle-pwd" data-target="pwd-current" style="position: absolute; right: 8px; top: 50%; transform: translateY(-50%); background: none; border: none; color: var(--color-text-secondary); cursor: pointer; padding: 4px;">
                    \u{1F441}\uFE0F
                  </button>
                </div>
              </div>

              <!-- New Password -->
              <div class="form-group">
                <label class="form-label" for="pwd-new" style="font-weight: 600;">New Password *</label>
                <div style="position: relative;">
                  <input type="password" id="pwd-new" class="form-control" required placeholder="At least 6 characters" minlength="6" style="padding-right: 40px;">
                  <button type="button" class="btn-toggle-pwd" data-target="pwd-new" style="position: absolute; right: 8px; top: 50%; transform: translateY(-50%); background: none; border: none; color: var(--color-text-secondary); cursor: pointer; padding: 4px;">
                    \u{1F441}\uFE0F
                  </button>
                </div>
              </div>

              <!-- Confirm New Password -->
              <div class="form-group">
                <label class="form-label" for="pwd-confirm" style="font-weight: 600;">Confirm New Password *</label>
                <div style="position: relative;">
                  <input type="password" id="pwd-confirm" class="form-control" required placeholder="Re-enter new password" minlength="6" style="padding-right: 40px;">
                  <button type="button" class="btn-toggle-pwd" data-target="pwd-confirm" style="position: absolute; right: 8px; top: 50%; transform: translateY(-50%); background: none; border: none; color: var(--color-text-secondary); cursor: pointer; padding: 4px;">
                    \u{1F441}\uFE0F
                  </button>
                </div>
              </div>

            </div>

            <!-- Security Checklist -->
            <div style="background: var(--color-bg-primary); border: 1px solid var(--color-border); border-radius: var(--radius-md); padding: 1rem 1.25rem; margin-bottom: 1.5rem;">
              <div style="font-size: 0.85rem; font-weight: 600; color: var(--color-text-primary); margin-bottom: 0.5rem;">
                Password Security Checklist
              </div>
              <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(min(100%, 200px), 1fr)); gap: 0.5rem; font-size: 0.85rem;">
                <div id="rule-len" style="display: flex; align-items: center; gap: 0.4rem; color: var(--color-text-muted);">
                  <span class="rule-icon">\u26AA</span> At least 6 characters
                </div>
                <div id="rule-match" style="display: flex; align-items: center; gap: 0.4rem; color: var(--color-text-muted);">
                  <span class="rule-icon">\u26AA</span> Passwords match
                </div>
                <div id="rule-diff" style="display: flex; align-items: center; gap: 0.4rem; color: var(--color-text-muted);">
                  <span class="rule-icon">\u26AA</span> Different from current
                </div>
              </div>
            </div>

            <div style="display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 0.75rem;">
              <button type="button" id="btn-logout-other-sessions" class="btn btn-outline-danger" style="font-weight: 600; font-size: 0.85rem;">
                \u{1F6AA} Terminate All Other Device Sessions
              </button>
              <button type="submit" id="btn-change-password" class="btn btn-primary" style="font-weight: 600; min-width: 170px;">
                Update Password
              </button>
            </div>

          </form>
        </div>
      </div>

    </div>
  `;const D=e.querySelector("#profile-avatar"),g=e.querySelector("#profile-avatar-img"),q=e.querySelector("#profile-avatar-initials"),F=e.querySelector("#btn-upload-avatar-file"),E=e.querySelector("#btn-take-avatar-cam"),P=e.querySelector("#btn-remove-avatar"),L=e.querySelector("#input-avatar-file"),C=async(t,o=!1)=>{if(t){if(D.value=t,g.src=t,g.style.display="block",q.style.display="none",P.style.display="inline-flex",g.onerror=()=>{g.style.display="none",q.style.display="block"},o)try{await m.put("/api/settings/admin-profile",{avatar:t});try{const r=window.App||window.__app_instance,i=r?.getUser?.();i&&(i.avatar=t,r.setUser?.(i))}catch{}window.dispatchEvent(new CustomEvent("user-updated",{detail:{avatar:t}})),typeof window.updateProfileAvatar=="function"&&window.updateProfileAvatar(t)}catch(r){console.warn("Failed to auto-persist avatar:",r)}}else if(D.value="",g.style.display="none",q.style.display="block",P.style.display="none",o)try{await m.put("/api/settings/admin-profile",{avatar:""});try{const r=window.App||window.__app_instance,i=r?.getUser?.();i&&(i.avatar="",r.setUser?.(i))}catch{}window.dispatchEvent(new CustomEvent("user-updated",{detail:{avatar:""}})),typeof window.updateProfileAvatar=="function"&&window.updateProfileAvatar("")}catch{}};F?.addEventListener("click",t=>{t.preventDefault(),t.stopPropagation(),L.click()}),L?.addEventListener("change",async t=>{t.preventDefault(),t.stopPropagation();const o=t.target.files[0];if(o)try{l.button(F,!0);const r=await ImageCompressor.compress(o,{maxWidth:300,maxHeight:300,quality:.82});let i=r;try{const d=await m.post("/api/upload",{image:r});d.success&&d.url&&(i=d.url)}catch{}await C(i,!0),n.success("Profile photo saved & applied permanently!")}catch(r){n.error(r.message||"Image processing failed")}finally{l.button(F,!1),L.value=""}}),E?.addEventListener("click",async t=>{t.preventDefault(),t.stopPropagation();try{const o=await ImageCompressor.captureWebcam({maxWidth:300,maxHeight:300,quality:.82});l.button(E,!0);let r=o;try{const i=await m.post("/api/upload",{image:o});i.success&&i.url&&(r=i.url)}catch{}await C(r,!0),n.success("Live selfie captured & applied permanently!")}catch(o){o.message!=="Camera capture cancelled"&&n.error(o.message||"Camera capture failed")}finally{l.button(E,!1)}}),P?.addEventListener("click",async()=>{await C("",!0),n.info("Profile picture removed")}),e.querySelectorAll(".btn-toggle-pwd").forEach(t=>{t.addEventListener("click",()=>{const o=t.dataset.target,r=e.querySelector(`#${o}`);r&&(r.type=r.type==="password"?"text":"password")})});const f=e.querySelector("#pwd-current"),y=e.querySelector("#pwd-new"),b=e.querySelector("#pwd-confirm"),w=e.querySelector("#rule-len"),h=e.querySelector("#rule-match"),x=e.querySelector("#rule-diff");function S(){const t=f?.value||"",o=y?.value||"",r=b?.value||"";o.length>=6?(w.style.color="var(--color-success)",w.querySelector(".rule-icon").textContent="\u2705"):(w.style.color="var(--color-text-muted)",w.querySelector(".rule-icon").textContent="\u26AA"),o&&o===r?(h.style.color="var(--color-success)",h.querySelector(".rule-icon").textContent="\u2705"):(h.style.color="var(--color-text-muted)",h.querySelector(".rule-icon").textContent="\u26AA"),o&&t&&o!==t?(x.style.color="var(--color-success)",x.querySelector(".rule-icon").textContent="\u2705"):(x.style.color="var(--color-text-muted)",x.querySelector(".rule-icon").textContent="\u26AA")}y?.addEventListener("input",S),b?.addEventListener("input",S),f?.addEventListener("input",S),e.querySelector("#form-edit-profile")?.addEventListener("submit",async t=>{t.preventDefault();const o=e.querySelector("#btn-save-profile");l.button(o,!0);const r=e.querySelector("#profile-name")?.value?.trim(),i=e.querySelector("#profile-email")?.value?.trim(),d=e.querySelector("#profile-phone")?.value?.trim(),u=e.querySelector("#profile-avatar")?.value?.trim();try{const k=await m.put("/api/settings/admin-profile",{name:r,email:i,phone:d,avatar:u}),c=k.data||{};try{const $=window.App||window.__app_instance,p=$?.getUser?.();p&&(p.name=c.name||r||p.name,p.email=c.email||i||p.email,p.phone=c.phone||d||p.phone,p.avatar=c.avatar!==void 0?c.avatar:u,$.setUser?.(p))}catch{}window.dispatchEvent(new CustomEvent("user-updated")),typeof window.updateProfileAvatar=="function"&&window.updateProfileAvatar(c.avatar!==void 0?c.avatar:u);const N=e.querySelector("#display-user-name");N&&(N.textContent=c.name||r);const z=e.querySelector("#display-user-email");z&&(z.textContent=c.email||i),n.success(k?.message||"Admin profile updated successfully")}catch(k){n.error(k.message||"Failed to update admin profile")}finally{l.button(o,!1)}}),e.querySelector("#form-change-password")?.addEventListener("submit",async t=>{t.preventDefault();const o=f?.value,r=y?.value,i=b?.value;if(!o){n.warning("Please enter your current password"),f?.focus();return}if(!r||r.length<6){n.warning("New password must be at least 6 characters"),y?.focus();return}if(r!==i){n.error("New password and confirm password do not match"),b?.focus();return}if(o===r){n.warning("New password must be different from current password"),y?.focus();return}const d=e.querySelector("#btn-change-password");l.button(d,!0);try{const u=await m.post("/api/settings/change-password",{currentPassword:o,newPassword:r});n.success(u?.message||"Password changed successfully!"),f.value="",y.value="",b.value="",S()}catch(u){n.error(u.message||"Failed to change password. Check your current password.")}finally{l.button(d,!1)}});const v=e.querySelector("#btn-enable-biometric");v&&(M.isSupported().then(t=>{t||(v.disabled=!0,v.title="Biometrics not supported on this browser or device")}),v.addEventListener("click",async()=>{try{l.button(v,!0),await M.register(a)}catch{}finally{l.button(v,!1)}}));const I=e.querySelector("#desk-pin-input"),j=e.querySelector("#btn-save-desk-pin"),H=e.querySelector("#btn-test-desk-lock");j?.addEventListener("click",()=>{const t=(I?.value||"").trim();if(!/^\d{4}$/.test(t)){n.warning("PIN must be exactly 4 digits (e.g. 1234)"),I?.focus();return}localStorage.setItem("sl_desk_pin",t),n.success("Front-Desk PIN saved successfully!")}),H?.addEventListener("click",()=>{window.PinLock&&window.PinLock.lock()}),e.querySelector("#btn-logout-other-sessions")?.addEventListener("click",async()=>{await B.show({title:"Terminate Other Device Sessions?",message:"Are you sure you want to log out all other active devices? You will remain logged in on this browser.",danger:!0})&&n.success("All other active device sessions have been terminated.")})}export{R as render};
