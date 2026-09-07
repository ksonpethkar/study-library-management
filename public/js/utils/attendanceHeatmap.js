async function X(t,r){const e=new Map;try{const s=localStorage.getItem("sl_token")||"",l=await fetch(`/api/attendance?studentId=${encodeURIComponent(t)}&year=${r}&limit=400`,{headers:{Authorization:`Bearer ${s}`}});if(!l.ok)return e;const n=await l.json(),o=n.data||n.records||n||[];(Array.isArray(o)?o:[]).forEach(i=>{const w=new Date(i.date||i.checkInTime||i.createdAt);if(!isNaN(w)){const g=w.toISOString().slice(0,10),u=i.status||(i.checkInTime?"present":"absent");e.set(g,u.toLowerCase().includes("present")||u==="in"?"present":"absent")}})}catch(s){console.warn("Heatmap fetch error:",s)}return e}function O(t,r="dark"){return t?t==="present"?"#22c55e":t==="absent"?"#ef4444":t==="holiday"?"#f59e0b":r==="dark"?"#1e293b":"#ebedf0":r==="dark"?"#1e293b":"#ebedf0"}function Z(t){const r=[],e=new Date(t,0,1);for(;e.getFullYear()===t;)r.push(e.toISOString().slice(0,10)),e.setDate(e.getDate()+1);return r}async function A(t,r,e=new Date().getFullYear(),s={}){const{theme:l=document.documentElement.getAttribute("data-theme")||"dark",compact:n=!1}=s;if(!t)return;t.innerHTML=`
    <div class="heatmap-loading" style="display:flex;align-items:center;gap:8px;color:var(--color-text-muted,#64748b);font-size:0.85rem;">
      <div style="width:16px;height:16px;border:2px solid #6c5ce7;border-top-color:transparent;border-radius:50%;animation:heatmap-spin 0.7s linear infinite;flex-shrink:0;"></div>
      Loading attendance calendar...
    </div>
    <style>@keyframes heatmap-spin{to{transform:rotate(360deg)}}</style>
  `;const o=await X(r,e),i=Z(e),w=new Date().toISOString().slice(0,10);let g=0,u=0,E=0;o.forEach(a=>{a==="present"?g++:a==="absent"&&u++,E++});const m=E>0?Math.round(g/E*100):0,j=["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"],J=n?["","M","","W","","F",""]:["S","M","T","W","T","F","S"],P=new Date(e,0,1).getDay(),M=Array(P).fill(null).concat(i),$=[];for(let a=0;a<M.length;a+=7)$.push(M.slice(a,a+7));const p=n?10:13,f=2,G=$.length*(p+f),B=[];let C=-1;$.forEach((a,d)=>{a.forEach(c=>{if(!c)return;const b=new Date(c).getMonth();b!==C&&(C=b,B.push({month:b,weekIdx:d}))})});const R="http://www.w3.org/2000/svg",v=20,k=n?0:24,F=k+G+4,W=v+7*(p+f)+4;let I="";$.forEach((a,d)=>{a.forEach((c,b)=>{if(!c)return;const L=c>w,N=o.get(c)||null,q=L?"transparent":O(N,l),K=k+d*(p+f),Q=v+b*(p+f),V=`${c}: ${N||"No record"}`;I+=`<rect x="${K}" y="${Q}" width="${p}" height="${p}" rx="2" fill="${q}" style="cursor:default;opacity:${L?0:1}"><title>${V}</title></rect>`})});let T="";n||B.forEach(({month:a,weekIdx:d})=>{const c=k+d*(p+f);T+=`<text x="${c}" y="${v-5}" font-size="9" fill="var(--color-text-muted,#64748b)" font-family="sans-serif">${j[a]}</text>`});let H="";n||J.forEach((a,d)=>{if(!a)return;const c=v+d*(p+f)+p-2;H+=`<text x="${k-4}" y="${c}" font-size="9" fill="var(--color-text-muted,#64748b)" text-anchor="end" font-family="sans-serif">${a}</text>`});const U=`
    <svg width="${F}" height="${W}" xmlns="${R}" style="max-width:100%;overflow:visible;">
      ${T}
      ${H}
      ${I}
    </svg>
  `,S=m>=75?"#22c55e":m>=50?"#f59e0b":"#ef4444",_=m>=75?"Good":m>=50?"Average":"Low";t.innerHTML=`
    <div class="attendance-heatmap-wrap" style="overflow-x:auto;-webkit-overflow-scrolling:touch;">
      <div style="display:flex;align-items:center;justify-content:space-between;margin-bottom:10px;flex-wrap:wrap;gap:8px;">
        <div style="font-size:0.82rem;font-weight:700;color:var(--color-text-secondary,#94a3b8);letter-spacing:0.04em;text-transform:uppercase;">
          ${e} Attendance Calendar
        </div>
        <div style="display:flex;align-items:center;gap:10px;flex-wrap:wrap;">
          <span style="font-size:0.78rem;color:var(--color-text-muted,#64748b);">${g} present / ${u} absent</span>
          <span style="background:${S}22;color:${S};font-weight:700;font-size:0.78rem;padding:2px 10px;border-radius:20px;border:1px solid ${S}55;">
            ${m}% \u2014 ${_}
          </span>
        </div>
      </div>
      <div class="heatmap-svg-container" style="min-width:${F}px;">
        ${U}
      </div>
      <div style="display:flex;align-items:center;gap:8px;margin-top:8px;font-size:0.75rem;color:var(--color-text-muted,#64748b);">
        <span>Less</span>
        <span style="display:inline-flex;gap:3px;">
          ${[O(null,l),"#22c55e88","#22c55e","#ef4444","#f59e0b"].map(a=>`<span style="width:11px;height:11px;border-radius:2px;background:${a};display:inline-block;"></span>`).join("")}
        </span>
        <span>More/Present</span>
        <span style="margin-left:auto;display:flex;gap:8px;">
          <span style="display:flex;align-items:center;gap:3px;"><span style="width:11px;height:11px;border-radius:2px;background:#22c55e;display:inline-block;"></span>Present</span>
          <span style="display:flex;align-items:center;gap:3px;"><span style="width:11px;height:11px;border-radius:2px;background:#ef4444;display:inline-block;"></span>Absent</span>
        </span>
      </div>
    </div>
    <style>
      .attendance-heatmap-wrap { user-select: none; }
    </style>
  `;const h=document.createElement("div");h.style.cssText="display:flex;align-items:center;gap:8px;margin-bottom:8px;";const y=document.createElement("button");y.textContent="\u2039",y.className="btn btn-sm btn-ghost",y.style.cssText="padding:2px 8px;font-size:1rem;";const z=document.createElement("span");z.textContent=String(e),z.style.cssText="font-weight:700;font-size:0.9rem;min-width:40px;text-align:center;";const x=document.createElement("button");x.textContent="\u203A",x.className="btn btn-sm btn-ghost",x.style.cssText="padding:2px 8px;font-size:1rem;",x.disabled=e>=new Date().getFullYear(),h.appendChild(y),h.appendChild(z),h.appendChild(x),t.insertBefore(h,t.firstChild),y.onclick=()=>A(t,r,e-1,s),x.onclick=()=>{e<new Date().getFullYear()&&A(t,r,e+1,s)}}function D(t=0,r=100,e=0){const s=Math.min(e/30*100,100),l=Math.round(t*.4+r*.4+s*.2);let n,o,i;return l>=80?(n="A+",o="#22c55e",i="Excellent"):l>=65?(n="B",o="#f59e0b",i="Good"):l>=45?(n="C",o="#f97316",i="Average"):(n="D",o="#ef4444",i="At Risk"),{score:l,grade:n,color:o,label:i}}function Y(t,r,e){const{score:s,grade:l,color:n,label:o}=D(t,r,e);return`<span class="behavior-badge" title="Behavior Score: ${s}/100 (Attendance ${t}% + Payment ${r}% + Streak ${e}d)" style="background:${n}22;color:${n};border:1px solid ${n}55;border-radius:20px;padding:2px 10px;font-size:0.75rem;font-weight:700;display:inline-flex;align-items:center;gap:4px;cursor:help;">
  <span style="font-size:0.85rem;">${s>=80?"\u{1F7E2}":s>=65?"\u{1F7E1}":s>=45?"\u{1F7E0}":"\u{1F534}"}</span>
  ${l} \xB7 ${o}
</span>`}typeof window<"u"&&(window.AttendanceHeatmap={renderHeatmap:A,calculateBehaviorScore:D,renderBehaviorBadge:Y});export{D as calculateBehaviorScore,Y as renderBehaviorBadge,A as renderHeatmap};
