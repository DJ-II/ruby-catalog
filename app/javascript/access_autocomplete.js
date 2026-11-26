function setupAccessAutocomplete() {
  const input = document.querySelector('[data-suggest-url]');
  const datalist = document.getElementById('access-suggestions');
  if (!input || !datalist || input.dataset.bound === 'yes') return;
  input.dataset.bound = 'yes';
  let requestNumber = 0;
  input.addEventListener('input', async function () {
    const value = input.value.trim();
    const current = ++requestNumber;
    datalist.replaceChildren();
    if (value.length < 2) return;
    try {
      const response = await fetch(input.dataset.suggestUrl + '?q=' + encodeURIComponent(value), { headers: { Accept: 'application/json' } });
      if (!response.ok || current !== requestNumber) return;
      const users = await response.json();
      if (current !== requestNumber) return;
      users.forEach(function (user) {
        const byName = document.createElement('option');
        byName.value = user.username;
        byName.label = user.email;
        datalist.appendChild(byName);
        const byEmail = document.createElement('option');
        byEmail.value = user.email;
        byEmail.label = user.username;
        datalist.appendChild(byEmail);
      });
    } catch (_) {}
  });
}
document.addEventListener('DOMContentLoaded', setupAccessAutocomplete);
document.addEventListener('turbo:load', setupAccessAutocomplete);
