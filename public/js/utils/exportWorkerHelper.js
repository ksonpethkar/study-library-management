const f=`
self.onmessage = function(e) {
  const { headers, rows, filename } = e.data;
  try {
    const escapeCol = (val) => {
      if (val === null || val === undefined) return '""';
      const str = String(val).replace(/"/g, '""');
      return '"' + str + '"';
    };

    const lines = [];
    if (headers && headers.length) {
      lines.push(headers.map(escapeCol).join(','));
    }

    const len = rows.length;
    for (let i = 0; i < len; i++) {
      const row = rows[i];
      if (Array.isArray(row)) {
        lines.push(row.map(escapeCol).join(','));
      } else if (typeof row === 'object' && row !== null) {
        lines.push(Object.values(row).map(escapeCol).join(','));
      }
    }

    const csvContent = '\\uFEFF' + lines.join('\\r\\n');
    const blob = new Blob([csvContent], { type: 'text/csv;charset=utf-8;' });
    self.postMessage({ success: true, blob, filename });
  } catch (err) {
    self.postMessage({ success: false, error: err.message });
  }
};
`;let d=null;function g(){if(!d&&typeof Blob<"u"&&typeof URL<"u"){const t=new Blob([f],{type:"application/javascript"});d=URL.createObjectURL(t)}return d}const w={async downloadCSV({headers:t=[],rows:c=[],filename:i="export.csv"}){return new Promise((r,u)=>{if(c.length<100||typeof Worker>"u"){try{const a=o=>'"'+(o==null?"":String(o).replace(/"/g,'""'))+'"',e=t.length?t.map(a).join(",")+`\r
`:"",n=c.map(o=>(Array.isArray(o)?o:Object.values(o)).map(a).join(",")).join(`\r
`),l=new Blob(["\uFEFF"+e+n],{type:"text/csv;charset=utf-8;"});this._triggerDownload(l,i),r(!0)}catch(a){u(a)}return}try{const a=g(),e=new Worker(a);e.onmessage=n=>{e.terminate(),n.data.success&&n.data.blob?(this._triggerDownload(n.data.blob,n.data.filename),r(!0)):u(new Error(n.data.error||"Worker export failed"))},e.onerror=n=>{e.terminate(),console.warn("Export worker error, falling back to main thread:",n);try{const l=p=>'"'+(p==null?"":String(p).replace(/"/g,'""'))+'"',o=t.length?t.map(l).join(",")+`\r
`:"",s=c.map(p=>(Array.isArray(p)?p:Object.values(p)).map(l).join(",")).join(`\r
`),b=new Blob(["\uFEFF"+o+s],{type:"text/csv;charset=utf-8;"});this._triggerDownload(b,i),r(!0)}catch(l){u(l)}},e.postMessage({headers:t,rows:c,filename:i})}catch(a){console.warn("Could not spawn export worker, using direct path:",a);try{const e=s=>'"'+(s==null?"":String(s).replace(/"/g,'""'))+'"',n=t.length?t.map(e).join(",")+`\r
`:"",l=c.map(s=>(Array.isArray(s)?s:Object.values(s)).map(e).join(",")).join(`\r
`),o=new Blob(["\uFEFF"+n+l],{type:"text/csv;charset=utf-8;"});this._triggerDownload(o,i),r(!0)}catch(e){u(e)}}})},_triggerDownload(t,c){const i=URL.createObjectURL(t),r=document.createElement("a");r.href=i,r.download=c,document.body.appendChild(r),r.click(),document.body.removeChild(r),setTimeout(()=>URL.revokeObjectURL(i),1e3)}};export{w as ExportHelper};
