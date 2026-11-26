import '@hotwired/turbo-rails';
import 'inventory_customization';
import 'inventory_autosave';
import 'inventory_discussion';
import 'inventory_enhancements';

import 'item_likes';
import 'bulk_selection';
import 'access_autocomplete';

function syncPagePreferences() {
  const { pageTheme, pageLocale } = document.body?.dataset || {};
  if (['light', 'dark'].includes(pageTheme)) {
    document.documentElement.setAttribute('data-bs-theme', pageTheme);
  }
  if (['en', 'pl'].includes(pageLocale)) {
    document.documentElement.lang = pageLocale;
  }
}

document.addEventListener('turbo:render', syncPagePreferences);
document.addEventListener('turbo:load', syncPagePreferences);
syncPagePreferences();
