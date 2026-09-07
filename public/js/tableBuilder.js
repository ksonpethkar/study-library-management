class n{constructor(t,e){typeof t=="string"?(this.container=document.getElementById(t),this.config=e||{}):t instanceof HTMLElement?(this.container=t,this.config=e||{}):(this.container=null,this.config=t||{}),this.config={pageSize:10,searchable:!1,sortable:!0,selectable:!1,actions:[],columns:[],emptyMessage:"No records found",...this.config},this.data=this.config.data||[],this.filteredData=[...this.data],this.currentPage=1,this.sortCol=null,this.sortAsc=!0,this.selectedIds=new Set,this.container&&this.render()}escapeHTML(t){return t==null?"":String(t).replace(/&/g,"&amp;").replace(/</g,"&lt;").replace(/>/g,"&gt;")}render(){const t=document.createElement("div");return t.className="data-table-wrapper",t.innerHTML=`
      <div style="overflow-x: auto;">
        <table class="table data-table mb-0" style="width: 100%; border-collapse: collapse;">
          <thead>
            <tr>
              ${this.config.selectable?'<th style="padding: 12px 16px; width: 40px;"><input type="checkbox" class="dt-select-all"></th>':""}
              ${this.config.columns.map(e=>`
                <th data-key="${e.key}" style="padding: 12px 16px; cursor: ${this.config.sortable&&e.sortable!==!1?"pointer":"default"};">
                  ${this.escapeHTML(e.label)} ${this.sortCol===e.key?this.sortAsc?"\u2191":"\u2193":""}
                </th>
              `).join("")}
              ${this.config.actions&&this.config.actions.length?'<th style="padding: 12px 16px;">Actions</th>':""}
            </tr>
          </thead>
          <tbody>
            ${this.renderBody()}
          </tbody>
        </table>
      </div>
    `,this.container&&(this.container.innerHTML="",this.container.appendChild(t)),t}renderBody(){if(this.filteredData.length===0)return`<tr><td colspan="${(this.config.columns.length||1)+(this.config.selectable?1:0)+(this.config.actions&&this.config.actions.length?1:0)}" style="padding: 24px; text-align: center; color: var(--color-text-muted, #888);">${this.config.emptyMessage}</td></tr>`;const t=(this.currentPage-1)*this.config.pageSize;return this.filteredData.slice(t,t+this.config.pageSize).map(e=>{const s=e._id||e.id||Math.random().toString();return`
        <tr>
          ${this.config.selectable?`<td style="padding: 12px 16px;"><input type="checkbox" class="dt-select" value="${s}" ${this.selectedIds.has(s)?"checked":""}></td>`:""}
          ${this.config.columns.map(i=>`
            <td style="padding: 12px 16px;">${i.render?i.render(e[i.key],e):this.escapeHTML(e[i.key]!==void 0?e[i.key]:"")}</td>
          `).join("")}
          ${this.config.actions&&this.config.actions.length?`
            <td style="padding: 12px 16px;">
              ${this.config.actions.map(i=>`<button class="btn btn-sm ${i.className||"btn-outline-primary"}" data-action="${i.name}" data-id="${s}" style="margin-right: 4px;">${this.escapeHTML(i.label)}</button>`).join("")}
            </td>
          `:""}
        </tr>
      `}).join("")}}export{n as DataTable};
