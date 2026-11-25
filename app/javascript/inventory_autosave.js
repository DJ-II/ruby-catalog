function initializeAutosave(form) {
  if (form.dataset.autosaveMounted === 'yes') return;
  form.dataset.autosaveMounted = 'yes';

  const indicator = form.querySelector('[data-autosave-status]');
  const reload = form.querySelector('[data-autosave-reload]');
  const versionInput = form.querySelector('input[name="inventory[lock_version]"], input[name="lock_version"]');
  if (!indicator || !versionInput) return;

  let revision = 0;
  let savedRevision = 0;
  let validationRevision = -1;
  let inFlight = false;
  let conflict = false;

  function status(type, details = '') {
    indicator.textContent = `${indicator.dataset[type] || type}${details ? `: ${details}` : ''}`;
    indicator.dataset.state = type;
    if (reload) reload.hidden = type !== 'conflict';
  }

  function markDirty() {
    revision += 1;
    if (!conflict) status('pending');
  }

  async function save() {
    if (conflict || inFlight || revision === savedRevision || revision === validationRevision) return;
    if (!form.checkValidity()) { status('invalid'); return; }
    inFlight = true;
    const submittedRevision = revision;
    status('saving');

    try {
      const response = await fetch(form.action, {
        method: form.method.toUpperCase(),
        body: new FormData(form),
        credentials: 'same-origin',
        headers: {
          Accept: 'application/json',
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]')?.content || ''
        }
      });
      const result = await response.json().catch(() => null);
      if (response.status === 409) {
        conflict = true;
        status('conflict');
        return;
      }
      if (!response.ok || !result || typeof result.lock_version !== 'number') {
        if (response.status === 422) {
          validationRevision = submittedRevision;
          status('invalid', Array.isArray(result?.errors) ? result.errors.join('; ').slice(0, 350) : '');
        } else {
          status('failed');
        }
        return;
      }
      versionInput.value = String(result.lock_version);
      savedRevision = submittedRevision;
      if (revision === savedRevision) status('saved');
      else status('pending');
    } catch (_) {
      status('failed');
    } finally {
      inFlight = false;
    }
  }

  status('saved');
  form.addEventListener('input', markDirty);
  form.addEventListener('change', markDirty);
  form.addEventListener('submit', event => {
    event.preventDefault();
    save();
  });

  const interval = window.setInterval(() => {
    if (!form.isConnected) {
      window.clearInterval(interval);
      return;
    }
    save();
  }, 8000);

  document.addEventListener('turbo:before-cache', () => {
    window.clearInterval(interval);
    delete form.dataset.autosaveMounted;
  }, { once: true });
}

function bootAutosave() {
  document.querySelectorAll('form[data-inventory-autosave]').forEach(initializeAutosave);
}

document.addEventListener('DOMContentLoaded', bootAutosave);
document.addEventListener('turbo:load', bootAutosave);
