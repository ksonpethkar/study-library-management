const c={_metrics:{pageLoads:[],apiCalls:[],errors:0,sessionStart:Date.now(),navigationCount:0},_maxEntries:100,init(){window.performance&&window.performance.timing&&window.addEventListener("load",()=>{setTimeout(()=>{const t=performance.timing,e=t.loadEventEnd-t.navigationStart,o=t.domContentLoadedEventEnd-t.navigationStart,r=t.responseStart-t.navigationStart;this._metrics.initialLoad={pageLoad:e,domReady:o,ttfb:r},console.log(`[PerfMon] Initial load: ${e}ms (DOM ready: ${o}ms, TTFB: ${r}ms)`)},100)}),this._patchFetch(),console.log("[PerformanceMonitor] Initialized")},_patchFetch(){const t=window.fetch,e=this;window.fetch=async function(...o){const r=typeof o[0]=="string"?o[0]:o[0]?.url||"",i=o[1]?.method||"GET";if(!(r.startsWith("/api/")||r.startsWith("api/")))return t.apply(this,o);const a=performance.now();try{const s=await t.apply(this,o),d=Math.round(performance.now()-a);return e._trackApiCall(r,i,d,s.status),s}catch(s){const d=Math.round(performance.now()-a);throw e._trackApiCall(r,i,d,0),s}}},_trackApiCall(t,e,o,r){const i={endpoint:t.split("?")[0],method:e.toUpperCase(),duration:o,status:r,timestamp:Date.now()};this._metrics.apiCalls.push(i),this._metrics.apiCalls.length>this._maxEntries&&this._metrics.apiCalls.shift(),o>3e3&&console.warn(`[PerfMon] Slow API: ${e} ${t} took ${o}ms`)},trackPageLoad(t,e){this._metrics.navigationCount++,this._metrics.pageLoads.push({page:t,duration:Math.round(e),timestamp:Date.now()}),this._metrics.pageLoads.length>this._maxEntries&&this._metrics.pageLoads.shift()},getStats(){const t=this._metrics.apiCalls,e=this._metrics.pageLoads,o=Date.now(),r=Math.round((o-this._metrics.sessionStart)/1e3),i=t.filter(n=>o-n.timestamp<3e5),a=i.length>0?Math.round(i.reduce((n,l)=>n+l.duration,0)/i.length):0,s=i.filter(n=>n.duration>2e3).length,d=i.filter(n=>n.status===0||n.status>=500).length,p=e.length>0?Math.round(e.reduce((n,l)=>n+l.duration,0)/e.length):0;let m=null;performance.memory&&(m=Math.round(performance.memory.usedJSHeapSize/1048576));const g=window.ErrorBoundary?.getErrorCount?.()||0;return{sessionDuration:r,navigationCount:this._metrics.navigationCount,totalApiCalls:t.length,avgApiTime:a,slowApis:s,failedApis:d,avgPageLoad:p,memoryMB:m,errorCount:g,initialLoad:this._metrics.initialLoad||null}},getHealthScore(){const t=this.getStats();let e=100;return t.avgApiTime>2e3?e-=20:t.avgApiTime>1e3?e-=10:t.avgApiTime>500&&(e-=5),e-=Math.min(30,t.failedApis*10),e-=Math.min(20,t.errorCount*5),t.memoryMB&&t.memoryMB>200&&(e-=10),t.memoryMB&&t.memoryMB>500&&(e-=20),Math.max(0,Math.min(100,e))},renderHealthWidget(){const t=this.getStats(),e=this.getHealthScore(),o=e>=80?"var(--color-success)":e>=50?"var(--color-warning)":"var(--color-danger)",r=e>=80?"Healthy":e>=50?"Fair":"Degraded",i=a=>a<60?`${a}s`:a<3600?`${Math.floor(a/60)}m ${a%60}s`:`${Math.floor(a/3600)}h ${Math.floor(a%3600/60)}m`;return`
      <div class="card fade-in-up" style="padding: 20px;">
        <div style="display: flex; align-items: center; justify-content: space-between; margin-bottom: 16px;">
          <h4 style="margin: 0; font-size: 0.95rem; font-weight: 700; color: var(--color-text-primary);">\u26A1 System Health</h4>
          <span style="font-size: 0.78rem; font-weight: 700; color: ${o}; background: ${o}15; padding: 3px 10px; border-radius: 20px;">${e}/100 ${r}</span>
        </div>
        <div style="display: grid; grid-template-columns: repeat(2, 1fr); gap: 12px;">
          <div style="text-align: center; padding: 10px; border-radius: 10px; background: var(--color-bg-secondary);">
            <div style="font-size: 1.2rem; font-weight: 800; color: var(--color-text-primary);">${t.avgApiTime}<span style="font-size: 0.7rem; font-weight: 500;">ms</span></div>
            <div style="font-size: 0.72rem; color: var(--color-text-muted); margin-top: 2px;">Avg API Response</div>
          </div>
          <div style="text-align: center; padding: 10px; border-radius: 10px; background: var(--color-bg-secondary);">
            <div style="font-size: 1.2rem; font-weight: 800; color: var(--color-text-primary);">${t.totalApiCalls}</div>
            <div style="font-size: 0.72rem; color: var(--color-text-muted); margin-top: 2px;">API Calls</div>
          </div>
          <div style="text-align: center; padding: 10px; border-radius: 10px; background: var(--color-bg-secondary);">
            <div style="font-size: 1.2rem; font-weight: 800; color: ${t.errorCount>0?"var(--color-danger)":"var(--color-success)"};">${t.errorCount}</div>
            <div style="font-size: 0.72rem; color: var(--color-text-muted); margin-top: 2px;">JS Errors</div>
          </div>
          <div style="text-align: center; padding: 10px; border-radius: 10px; background: var(--color-bg-secondary);">
            <div style="font-size: 1.2rem; font-weight: 800; color: var(--color-text-primary);">${i(t.sessionDuration)}</div>
            <div style="font-size: 0.72rem; color: var(--color-text-muted); margin-top: 2px;">Session</div>
          </div>
          ${t.memoryMB!==null?`
          <div style="text-align: center; padding: 10px; border-radius: 10px; background: var(--color-bg-secondary); grid-column: span 2;">
            <div style="font-size: 1.2rem; font-weight: 800; color: ${t.memoryMB>200?"var(--color-warning)":"var(--color-text-primary)"};">${t.memoryMB}<span style="font-size: 0.7rem; font-weight: 500;">MB</span></div>
            <div style="font-size: 0.72rem; color: var(--color-text-muted); margin-top: 2px;">Memory Usage</div>
          </div>`:""}
        </div>
        ${t.slowApis>0||t.failedApis>0?`
        <div style="margin-top: 12px; padding: 8px 12px; border-radius: 8px; background: var(--color-warning-bg); font-size: 0.78rem; color: var(--color-warning-dark);">
          \u26A0\uFE0F ${t.slowApis} slow + ${t.failedApis} failed API calls in last 5 min
        </div>`:""}
      </div>
    `}};var h=c;window.PerformanceMonitor=c;export{c as PerformanceMonitor,h as default};
