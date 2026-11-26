const dateTokens = ['yyyy', 'ddd', 'yy', 'MM', 'dd', 'HH', 'mm', 'ss'];

function dateExample(pattern, date, errors) {
  const two = value => String(value).padStart(2, '0');
  const values = {
    yyyy: String(date.getFullYear()),
    ddd: ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'][date.getDay()],
    yy: two(date.getFullYear() % 100),
    MM: two(date.getMonth() + 1),
    dd: two(date.getDate()),
    HH: two(date.getHours()),
    mm: two(date.getMinutes()),
    ss: two(date.getSeconds())
  };
  let output = '';
  for (let i = 0; i < pattern.length;) {
    const token = dateTokens.find(value => pattern.startsWith(value, i));
    if (token) {
      output += values[token];
      i += token.length;
    } else if (/[-_ .:/]/.test(pattern[i])) {
      output += pattern[i];
      i += 1;
    } else {
      throw new Error(errors.date_format);
    }
  }
  return output;
}

function numericExample(value, pattern, errors) {
  const matched = /^([DX])([1-9][0-9]?)?$/.exec(pattern);
  if (!matched) throw new Error(errors.number_format);
  return value.toString(matched[1] === 'X' ? 16 : 10).toUpperCase().padStart(Number(matched[2] || 0), '0');
}

function partExample(kind, pattern, sequence, date, errors) {
  switch (kind) {
    case 'fixed':
      if (!pattern.length) throw new Error(errors.empty_pattern);
      return pattern;
    case 'random20': return numericExample(0xA7E3A, pattern, errors);
    case 'random32': return numericExample(0xE74FA329, pattern, errors);
    case 'random6': return numericExample(123456, pattern, errors);
    case 'random9': return numericExample(123456789, pattern, errors);
    case 'sequence': return numericExample(sequence, pattern, errors);
    case 'datetime': return dateExample(pattern, date, errors);
    case 'guid': {
      const value = 'A1B2C3D4-0123-4567-89AB-0123456789AB';
      if (pattern === 'N') return value.replaceAll('-', '');
      if (pattern === 'D') return value;
      if (pattern === 'B') return `{${value}}`;
      if (pattern === 'P') return `(${value})`;
      throw new Error(errors.guid_format);
    }
    default: throw new Error(errors.unknown_kind);
  }
}

function nativeReorder(list, rowSelector, handleSelector, refresh, removeOutside = false) {
  let dragged = null;
  function dragOver(event) {
    if (!dragged) return;
    const row = event.target.closest(rowSelector);
    if (!row || row === dragged || row.parentElement !== list) return;
    const rect = row.getBoundingClientRect();
    list.insertBefore(dragged, event.clientY < rect.top + rect.height / 2 ? row : row.nextElementSibling);
  }

  function allowDrop(event) {
    if (!dragged) return;
    if (removeOutside || list.contains(event.target)) event.preventDefault();
  }

  function drop(event) {
    if (!dragged) return;
    if (removeOutside && !list.contains(event.target)) dragged.remove();
    refresh();
  }

  function finish() {
    if (!dragged) return;
    dragged = null;
    document.removeEventListener('dragover', allowDrop);
    document.removeEventListener('drop', drop);
    refresh();
  }

  function bind(row) {
    const handle = row.querySelector(handleSelector);
    handle.draggable = true;
    handle.addEventListener('dragstart', event => {
      dragged = row;
      event.dataTransfer.effectAllowed = 'move';
      event.dataTransfer.setData('text/plain', 'inventoryhub-row');
      document.addEventListener('dragover', allowDrop);
      document.addEventListener('drop', drop);
    });
    handle.addEventListener('dragend', finish);
  }
  list.addEventListener('dragover', dragOver);
  return bind;
}

function initializeIdBuilder(root) {
  if (root.dataset.initialized === 'yes') return;
  root.dataset.initialized = 'yes';
  const list = root.querySelector('[data-id-parts]');
  const trash = root.querySelector('[data-id-trash]');
  const preview = root.querySelector('[data-id-preview]');
  const previewMessage = root.querySelector('[data-id-preview-message]');
  const defaultMessage = previewMessage.textContent;
  const emptyMessage = root.querySelector('[data-empty-id-parts]');
  const addButton = root.querySelector('[data-add-id-part]');
  const count = root.querySelector('[data-id-part-count]');
  const template = root.querySelector('[data-id-part-template]');
  const defaults = JSON.parse(root.dataset.defaults);
  const help = JSON.parse(root.dataset.helpMessages);
  const errors = JSON.parse(root.dataset.errorMessages);
  const sampleSequence = Number(root.dataset.sampleSequence);
  const sampleDate = new Date(root.dataset.sampleDate);
  const maxParts = Number(root.dataset.maxParts);
  let nextKey = 0;
  let initializing = true;
  function rows() {
    return [...list.querySelectorAll('[data-id-part]')];
  }

  function refresh() {
    const entries = rows();
    entries.forEach((element, index) => {
      element.querySelector('[data-id-position]').value = String(index);
    });
    count.textContent = entries.length;
    addButton.disabled = entries.length >= maxParts;
    emptyMessage.hidden = entries.length !== 0;
    try {
      const value = entries.length === 0
        ? `INV-${String(sampleSequence).padStart(6, '0')}`
        : entries.map(element => partExample(
          element.querySelector('[data-id-kind]').value,
          element.querySelector('[data-id-pattern]').value,
          sampleSequence,
          sampleDate,
          errors
        )).join('');
      if (value.length > 200) throw new Error(errors.generated_too_long);
      preview.textContent = value;
      preview.classList.remove('is-invalid');
      previewMessage.textContent = defaultMessage;
    } catch (error) {
      preview.textContent = error.message;
      preview.classList.add('is-invalid');
      previewMessage.textContent = '';
    }
    if (!initializing) root.querySelector('form[data-inventory-autosave]')?.dispatchEvent(new Event('change', { bubbles: true }));
  }
  const bindNativeRow = window.Sortable ? null : nativeReorder(list, '[data-id-part]', '.id-drag-handle', refresh, true);
  function bindRow(row) {
    bindNativeRow?.(row);
    const selector = row.querySelector('[data-id-kind]');
    const pattern = row.querySelector('[data-id-pattern]');
    const helpButton = row.querySelector('[data-id-help-trigger]');
    const handle = row.querySelector('.id-drag-handle');
    function updateHelp() {
      helpButton.setAttribute('data-bs-title', selector.selectedOptions[0].textContent);
      helpButton.setAttribute('data-bs-content', help[selector.value] || '');
      if (window.bootstrap?.Popover) {
        window.bootstrap.Popover.getInstance(helpButton)?.dispose();
        window.bootstrap.Popover.getOrCreateInstance(helpButton);
      } else {
        helpButton.title = help[selector.value] || '';
      }
    }
    selector.addEventListener('change', () => {
      pattern.value = defaults[selector.value];
      updateHelp();
      refresh();
    });
    pattern.addEventListener('input', refresh);
    row.querySelector('[data-remove-id-part]').addEventListener('click', () => {
      row.remove();
      refresh();
    });
    handle.addEventListener('keydown', event => {
      if (!['ArrowUp', 'ArrowDown'].includes(event.key)) return;
      event.preventDefault();
      const sibling = event.key === 'ArrowUp' ? row.previousElementSibling : row.nextElementSibling;
      if (!sibling) return;
      if (event.key === 'ArrowUp') list.insertBefore(row, sibling);
      else list.insertBefore(sibling, row);
      refresh();
      handle.focus();
    });
    updateHelp();
  }
  rows().forEach(bindRow);
  addButton.addEventListener('click', () => {
    if (rows().length >= maxParts) return;
    const key = `new_${nextKey++}`;
    const fragment = template.innerHTML.replaceAll('__KEY__', key);
    list.insertAdjacentHTML('beforeend', fragment);
    const row = list.lastElementChild;
    const type = root.querySelector('[data-new-id-kind]').value;
    row.querySelector('[data-id-kind]').value = type;
    row.querySelector('[data-id-pattern]').value = defaults[type];
    bindRow(row);
    refresh();
    row.querySelector('[data-id-pattern]').focus();
  });
  if (window.Sortable) {
    window.Sortable.create(list, {
      group: { name: 'inventory_id_parts', pull: true, put: false },
      handle: '.id-drag-handle', animation: 160, ghostClass: 'id-sort-ghost',
      onEnd(event) {
        const source = event.originalEvent;
        const rect = list.getBoundingClientRect();
        const x = source?.clientX ?? source?.changedTouches?.[0]?.clientX;
        const y = source?.clientY ?? source?.changedTouches?.[0]?.clientY;
        if (typeof x === 'number' && typeof y === 'number'
            && (x < rect.left || x > rect.right || y < rect.top || y > rect.bottom)) {
          event.item.remove();
        }
        refresh();
      },
      onSort: refresh
    });
    window.Sortable.create(trash, {
      group: { name: 'inventory_id_parts', pull: false, put: true },
      sort: false, animation: 120,
      onAdd(event) {
        event.item.remove();
        trash.classList.remove('trash-over');
        refresh();
      },
      onMove() { trash.classList.add('trash-over'); }
    });
  }
  refresh();
  initializing = false;
}

function initializeFields(root) {
  if (root.dataset.initialized === 'yes') return;
  root.dataset.initialized = 'yes';
  let initializing = true;
  function refresh() {
    root.querySelectorAll('[data-field-row]').forEach((row, index) => {
      row.querySelector('[data-field-position]').value = String(index + 1);
    });
    if (!initializing) root.closest('form[data-inventory-autosave]')?.dispatchEvent(new Event('change', { bubbles: true }));
  }
  const bindNativeRow = window.Sortable ? null : nativeReorder(root, '[data-field-row]', '[data-field-handle]', refresh);
  root.querySelectorAll('[data-field-row]').forEach(row => {
    bindNativeRow?.(row);
    const active = row.querySelector('[data-field-active]');
    const visible = row.querySelector('[data-field-visible]');
    if (active && visible) {
      const syncVisibility = () => {
        visible.disabled = !active.checked;
        if (!active.checked) visible.checked = false;
      };
      active.addEventListener('change', syncVisibility);
      syncVisibility();
    }
    row.querySelector('[data-field-handle]').addEventListener('keydown', event => {
      if (!['ArrowUp', 'ArrowDown'].includes(event.key)) return;
      event.preventDefault();
      const sibling = event.key === 'ArrowUp' ? row.previousElementSibling : row.nextElementSibling;
      if (!sibling) return;
      if (event.key === 'ArrowUp') root.insertBefore(row, sibling);
      else root.insertBefore(sibling, row);
      refresh();
      row.querySelector('[data-field-handle]').focus();
    });
  });
  if (window.Sortable) {
    window.Sortable.create(root, {
      handle: '[data-field-handle]', animation: 160,
      ghostClass: 'id-sort-ghost', onEnd: refresh
    });
  }
  refresh();
  initializing = false;
}

function bootInventoryCustomization() {
  document.querySelectorAll('[data-id-builder]').forEach(initializeIdBuilder);
  document.querySelectorAll('[data-sort-fields]').forEach(initializeFields);
}

document.addEventListener('DOMContentLoaded', bootInventoryCustomization);
document.addEventListener('turbo:load', bootInventoryCustomization);
