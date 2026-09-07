class n{constructor(t,e){typeof t=="string"?(this.container=document.getElementById(t),this.config=e||{}):t instanceof HTMLElement?(this.container=t,this.config=e||{}):(this.container=null,this.config=t||{}),this.config={pageSize:25,searchable:!1,sortable:!0,selectable:!1,actions:[],columns:[],emptyMessage:"No records found",virtualScroll:!0,renderChunkSize:25,...this.config},this.data=this.config.data||[],this.filteredData=[...this.data],this.currentPage=1,this.sortCol=null,this.sortAsc=!0,this.selectedIds=new Set,this._renderedChunks=1,this.container&&this.render()}escapeHTML(t){return t==null?"":String(t).replace(/&/g,"&amp;").replace(/</g,"&lt;").replace(/>/g,"&gt;")}render(){const t=document.createElement("div");if(t.className="data-table-wrapper",t.innerHTML=`
      <div class="table-responsive" style="overflow-x: auto; max-height: 70vh; position: relative;">
        <table class="table data-table mb-0" style="width: 100%; border-collapse: collapse;">
          <thead>
            <tr style="position: sticky; top: 0; z-index: 2; background: var(--color-surface, #1e2230);">
              ${this.config.selectable?'<th style="padding: 12px 16px; width: 40px;"><input type="checkbox" class="dt-select-all"></th>':""}
              ${this.config.columns.map(e=>`
                <th data-key="${e.key}" style="padding: 12px 16px; cursor: ${this.config.sortable&&e.sortable!==!1?"pointer":"default"}; white-space: nowrap;">
                  ${this.escapeHTML(e.label)} ${this.sortCol===e.key?this.sortAsc?"\u2191":"\u2193":""}
                </th>
              `).join("")}
              ${this.config.actions&&this.config.actions.length?'<th style="padding: 12px 16px; white-space: nowrap;">Actions</th>':""}
            </tr>
          </thead>
          <tbody class="dt-body">
            ${this.renderBody()}
          </tbody>
        </table>
      </div>
    `,this.config.virtualScroll&&this.filteredData.length>this.config.renderChunkSize){const e=t.querySelector(".table-responsive");e&&e.addEventListener("scroll",()=>{e.scrollTop+e.clientHeight>=e.scrollHeight-150&&this._appendNextChunk(t.querySelector(".dt-body"))},{passive:!0})}return this.container&&(this.container.innerHTML="",this.container.appendChild(t)),t}renderBody(){if(this.filteredData.length===0)return`<tr><td colspan="${(this.config.columns.length||1)+(this.config.selectable?1:0)+(this.config.actions&&this.config.actions.length?1:0)}" style="padding: 24px; text-align: center; color: var(--color-text-muted, #888);">${this.config.emptyMessage}</td></tr>`;const t=this.config.virtualScroll?Math.min(this._renderedChunks*this.config.renderChunkSize,this.filteredData.length):this.filteredData.length;return this._renderRowsSlice(0,t)}_renderRowsSlice(t,e){return this.filteredData.slice(t,e).map(s=>{const i=s._id||s.id||Math.random().toString();return`
        <tr data-id="${i}">
          ${this.config.selectable?`<td style="padding: 12px 16px;"><input type="checkbox" class="dt-select" value="${i}" ${this.selectedIds.has(i)?"checked":""}></td>`:""}
          ${this.config.columns.map(o=>`
            <td style="padding: 12px 16px;">${o.render?o.render(s[o.key],s):this.escapeHTML(s[o.key]!==void 0?s[o.key]:"")}</td>
          `).join("")}
          ${this.config.actions&&this.config.actions.length?`
            <td style="padding: 12px 16px; white-space: nowrap;">
              ${this.config.actions.map(o=>`<button class="btn btn-sm ${o.className||"btn-outline-primary"}" data-action="${o.name}" data-id="${i}" style="margin-right: 4px;">${this.escapeHTML(o.label)}</button>`).join("")}
            </td>
          `:""}
        </tr>
      `}).join("")}_appendNextChunk(t){if(!t)return;const e=this._renderedChunks*this.config.renderChunkSize;if(e>=this.filteredData.length)return;this._renderedChunks++;const s=Math.min(this._renderedChunks*this.config.renderChunkSize,this.filteredData.length),o=this._renderRowsSlice(e,s),i=document.createElement("template");i.innerHTML=o,t.appendChild(i.content)}}export{n as DataTable};
