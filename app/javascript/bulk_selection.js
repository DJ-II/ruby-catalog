function syncBulkSelection(form) {
  const rows = Array.from(form.querySelectorAll('input[type="checkbox"], input[type="radio"]')).filter(input => input.name === form.dataset.bulkSelection && !input.disabled);
  const count = rows.filter(input => input.checked).length;
  form.querySelectorAll('[data-bulk-action]').forEach(button => { button.disabled = count === 0; });
  const status = form.querySelector('[data-bulk-count]');
  if (status) {
    status.hidden = false;
    status.querySelector('[data-bulk-number]').textContent = String(count);
  }
  const all = form.querySelector('[data-bulk-all]');
  if (all) {
    all.checked = rows.length > 0 && count === rows.length;
    all.indeterminate = count > 0 && count < rows.length;
    all.disabled = rows.length === 0;
  }
}

function bootBulkSelection() {
  document.querySelectorAll('form[data-bulk-selection]').forEach(syncBulkSelection);
}

document.addEventListener('change', event => {
  const input = event.target;
  const form = input.closest?.('form[data-bulk-selection]');
  if (!form) return;
  if (input.matches('[data-bulk-all]')) {
    form.querySelectorAll('input[type="checkbox"]').forEach(row => {
      if (row.name === form.dataset.bulkSelection && !row.disabled) row.checked = input.checked;
    });
  }
  syncBulkSelection(form);
});

document.addEventListener('DOMContentLoaded', bootBulkSelection);
document.addEventListener('turbo:load', bootBulkSelection);
document.addEventListener('turbo:render', bootBulkSelection);
document.addEventListener('pageshow', bootBulkSelection);
bootBulkSelection();
