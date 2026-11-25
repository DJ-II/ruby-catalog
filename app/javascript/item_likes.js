document.addEventListener('submit', async (event) => {
  const form = event.target.closest('form[data-item-like-form]');
  if (!form) return;
  event.preventDefault();
  const panel = form.closest('[data-like-panel]');
  const button = form.querySelector('button, input[type="submit"]');
  if (button?.disabled) return;
  if (button) button.disabled = true;
  const error = panel.querySelector('[data-like-error]');
  if (error) error.hidden = true;
  try {
    const response = await fetch(form.action, {
      method: 'POST',
      credentials: 'same-origin',
      headers: { Accept: 'application/json', 'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]')?.content || '' },
      body: new FormData(form)
    });
    if (!response.ok || response.redirected) throw new Error('Like request failed');
    const result = await response.json();
    panel.outerHTML = result.html;
  } catch (_) {
    if (error) error.hidden = false;
    if (button) button.disabled = false;
  }
});
