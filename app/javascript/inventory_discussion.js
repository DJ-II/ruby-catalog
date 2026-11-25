function initializeDiscussion(root) {
  if (root.dataset.discussionMounted === 'yes') return;
  root.dataset.discussionMounted = 'yes';

  const list = root.querySelector('[data-discussion-list]');
  const endpoint = root.dataset.pollUrl;
  let lastId = Number(root.dataset.lastId || 0);
  let busy = false;

  async function poll() {
    if (busy || document.hidden || !root.isConnected) return;
    busy = true;
    try {
      const url = new URL(endpoint, window.location.href);
      url.searchParams.set('after_id', String(lastId));
      const response = await fetch(url, { headers: { Accept: 'application/json' }, credentials: 'same-origin' });
      if (!response.ok) return;
      const result = await response.json();
      if (typeof result.html === 'string' && result.html.length > 0) {
        list.insertAdjacentHTML('beforeend', result.html);
        root.querySelector('[data-discussion-empty]')?.remove();
      }
      if (typeof result.last_id === 'number') lastId = Math.max(lastId, result.last_id);
      if (result.more) window.queueMicrotask(poll);
    } catch (_) {
    } finally {
      busy = false;
    }
  }

  const timer = window.setInterval(poll, 3000);
  const onVisible = () => { if (!document.hidden) poll(); };
  document.addEventListener('visibilitychange', onVisible);
  document.addEventListener('turbo:before-cache', () => {
    window.clearInterval(timer);
    document.removeEventListener('visibilitychange', onVisible);
    delete root.dataset.discussionMounted;
  }, { once: true });
}

function bootDiscussion() {
  document.querySelectorAll('[data-discussion-feed]').forEach(initializeDiscussion);
}

document.addEventListener('DOMContentLoaded', bootDiscussion);
document.addEventListener('turbo:load', bootDiscussion);
