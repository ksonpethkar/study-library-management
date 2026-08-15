export class DataTable {
  constructor(containerOrConfig, config) {
    if (typeof containerOrConfig === 'string') {
      this.container = document.getElementById(containerOrConfig);
      this.config = config || {};
    } else if (containerOrConfig instanceof HTMLElement) {
      this.container = containerOrConfig;
      this.config = config || {};
    } else {
      this.container = null;
      this.config = containerOrConfig || {};
    }

    this.config = {
      pageSize: 10,
      searchable: false,
      sortable: true,
      selectable: false,
      actions: [],
      columns: [],
      emptyMessage: 'No records found',
      ...this.config
    };

    this.data = this.config.data || [];
    this.filteredData = [...this.data];
    this.currentPage = 1;
    this.sortCol = null;
    this.sortAsc = true;
    this.selectedIds = new Set();
    
    if (this.container) {
      this.render();
    }
  }

  escapeHTML(str) {
    if (str === null || str === undefined) return '';
    return String(str).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
  }

  render() {
    const wrapper = document.createElement('div');
    wrapper.className = 'data-table-wrapper';
    
    wrapper.innerHTML = `
      <div style="overflow-x: auto;">
        <table class="table data-table mb-0" style="width: 100%; border-collapse: collapse;">
          <thead>
            <tr>
              ${this.config.selectable ? `<th style="padding: 12px 16px; width: 40px;"><input type="checkbox" class="dt-select-all"></th>` : ''}
              ${this.config.columns.map(c => `
                <th data-key="${c.key}" style="padding: 12px 16px; cursor: ${this.config.sortable && c.sortable !== false ? 'pointer' : 'default'};">
                  ${this.escapeHTML(c.label)} ${this.sortCol === c.key ? (this.sortAsc ? '↑' : '↓') : ''}
                </th>
              `).join('')}
              ${this.config.actions && this.config.actions.length ? '<th style="padding: 12px 16px;">Actions</th>' : ''}
            </tr>
          </thead>
          <tbody>
            ${this.renderBody()}
          </tbody>
        </table>
      </div>
    `;

    if (this.container) {
      this.container.innerHTML = '';
      this.container.appendChild(wrapper);
    }
    
    return wrapper;
  }

  renderBody() {
    if (this.filteredData.length === 0) {
      const colSpan = (this.config.columns.length || 1) + (this.config.selectable ? 1 : 0) + (this.config.actions && this.config.actions.length ? 1 : 0);
      return `<tr><td colspan="${colSpan}" style="padding: 24px; text-align: center; color: var(--color-text-muted, #888);">${this.config.emptyMessage}</td></tr>`;
    }

    const start = (this.currentPage - 1) * this.config.pageSize;
    const pageData = this.filteredData.slice(start, start + this.config.pageSize);

    return pageData.map(row => {
      const id = row._id || row.id || Math.random().toString();
      return `
        <tr>
          ${this.config.selectable ? `<td style="padding: 12px 16px;"><input type="checkbox" class="dt-select" value="${id}" ${this.selectedIds.has(id) ? 'checked' : ''}></td>` : ''}
          ${this.config.columns.map(c => `
            <td style="padding: 12px 16px;">${c.render ? c.render(row[c.key], row) : this.escapeHTML(row[c.key] !== undefined ? row[c.key] : '')}</td>
          `).join('')}
          ${this.config.actions && this.config.actions.length ? `
            <td style="padding: 12px 16px;">
              ${this.config.actions.map(a => `<button class="btn btn-sm ${a.className || 'btn-outline-primary'}" data-action="${a.name}" data-id="${id}" style="margin-right: 4px;">${this.escapeHTML(a.label)}</button>`).join('')}
            </td>
          ` : ''}
        </tr>
      `;
    }).join('');
  }
}
