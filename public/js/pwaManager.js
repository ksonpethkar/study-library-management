let t=null;function a(){"serviceWorker"in navigator&&window.addEventListener("load",()=>{navigator.serviceWorker.register("/sw.js").catch(e=>{console.warn("PWA ServiceWorker registration failed:",e)})}),window.addEventListener("beforeinstallprompt",e=>{e.preventDefault(),t=e,s()}),window.addEventListener("appinstalled",()=>{t=null,i()}),document.addEventListener("click",e=>{e.target.closest(".btn, .action-btn, .nav-item, .seat-card, .tab-item")&&o(12)})}function r(){const e=/iPad|iPhone|iPod/.test(navigator.userAgent)&&!window.MSStream;if(window.navigator.standalone||window.matchMedia("(display-mode: standalone)").matches){alert("StudyLib App is already installed and running in standalone mode!");return}t?(t.prompt(),t.userChoice.then(()=>{t=null,i()})):e?l():alert('To install StudyLib App on your phone, tap the menu (\u22EE or 3 dots) in your browser and select "Add to Home screen" or "Install App".')}function s(){document.querySelectorAll(".btn-pwa-install").forEach(e=>{e.style.display="inline-flex"})}function i(){document.querySelectorAll(".btn-pwa-install").forEach(e=>{e.style.display="none"})}function l(){const e=document.createElement("div");e.style.cssText=`
    position: fixed; bottom: 0; left: 0; right: 0; top: 0;
    background: rgba(15, 23, 42, 0.75); backdrop-filter: blur(8px);
    z-index: 99999; display: flex; align-items: flex-end; justify-content: center;
    padding: 1rem; animation: slideUp 0.3s ease;
  `,e.innerHTML=`
    <div style="background: var(--color-surface, #ffffff); width: 100%; max-width: 480px; border-radius: 20px; padding: 1.5rem; color: var(--color-text-primary, #1e293b); box-shadow: 0 -10px 40px rgba(0,0,0,0.3);">
      <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 1rem;">
        <h3 style="margin: 0; font-size: 1.2rem; font-weight: 800; display: flex; align-items: center; gap: 8px;">
          \u{1F4F2} Install StudyLib on iPhone / iPad
        </h3>
        <button id="btn-close-ios-pwa" style="background: none; border: none; font-size: 1.2rem; cursor: pointer; color: #94a3b8;">\u2715</button>
      </div>

      <p style="font-size: 0.9rem; color: #64748b; line-height: 1.5; margin-bottom: 1rem;">
        Install StudyLib App on your iOS home screen for instant 1-tap access, full screen view, and offline portal access.
      </p>

      <div style="background: #f8fafc; padding: 1rem; border-radius: 12px; font-size: 0.9rem; display: flex; flex-direction: column; gap: 10px; margin-bottom: 1.25rem;">
        <div style="display: flex; align-items: center; gap: 12px;">
          <span style="font-size: 1.4rem;">1\uFE0F\u20E3</span>
          <span>Tap the <strong>Share button</strong> <span style="font-size: 1.2rem;">\u238B</span> (bottom bar in Safari).</span>
        </div>
        <div style="display: flex; align-items: center; gap: 12px;">
          <span style="font-size: 1.4rem;">2\uFE0F\u20E3</span>
          <span>Scroll down & tap <strong>"Add to Home Screen"</strong> <span style="font-size: 1.1rem;">\u2795</span>.</span>
        </div>
        <div style="display: flex; align-items: center; gap: 12px;">
          <span style="font-size: 1.4rem;">3\uFE0F\u20E3</span>
          <span>Tap <strong>"Add"</strong> in top right corner to launch App!</span>
        </div>
      </div>

      <button id="btn-gotit-ios-pwa" class="btn btn-primary" style="width: 100%; font-weight: 700; padding: 10px; border-radius: 10px;">
        Got it!
      </button>
    </div>
  `,document.body.appendChild(e);const n=()=>e.remove();e.querySelector("#btn-close-ios-pwa")?.addEventListener("click",n),e.querySelector("#btn-gotit-ios-pwa")?.addEventListener("click",n)}function o(e=15){if(typeof navigator<"u"&&"vibrate"in navigator)try{navigator.vibrate(e)}catch{}}async function d(e={}){if(navigator.share)try{return await navigator.share(e),!0}catch{return!1}return!1}typeof window<"u"&&a();export{a as initPWA,d as nativeShare,r as promptPWAInstall,o as vibrate};
