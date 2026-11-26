const tagInstances = new Set();
let cloudinaryLibrary;

function setupTags() {
  document.querySelectorAll('[data-tag-input]').forEach(input => {
    if (input.dataset.enhanced === 'yes' || !window.Tagify) return;
    input.dataset.enhanced = 'yes';
    const tagify = new window.Tagify(input, {
      delimiters: ',',
      maxTags: 12,
      dropdown: { enabled: 1, maxItems: 12, highlightFirst: true },
      originalInputValueFormat: values => values.map(item => item.value).join(', ')
    });
    tagInstances.add(tagify);
    let pendingRequest;
    let recentQuery = '';
    tagify.on('input', event => {
      const query = event.detail.value.trim();
      recentQuery = query;
      pendingRequest?.abort();
      if (!query) {
        tagify.settings.whitelist = [];
        tagify.dropdown.hide();
        return;
      }
      pendingRequest = new AbortController();
      const url = new URL(input.dataset.suggestionsUrl, window.location.origin);
      url.searchParams.set('q', query);
      fetch(url.toString(), { signal: pendingRequest.signal, headers: { Accept: 'application/json' } })
        .then(response => response.ok ? response.json() : Promise.reject(new Error('Suggestions unavailable')))
        .then(data => {
          if (recentQuery !== query) return;
          tagify.settings.whitelist = Array.isArray(data.tags) ? data.tags : [];
          tagify.dropdown.show(query);
        })
        .catch(error => { if (error.name !== 'AbortError') tagify.dropdown.hide(); });
    });
    tagify.on('change', () => {
      input.closest('form')?.dispatchEvent(new Event('change', { bubbles: true }));
    });
  });
}

function cloudinaryWidgetScript() {
  if (window.cloudinary) return Promise.resolve(window.cloudinary);
  if (cloudinaryLibrary) return cloudinaryLibrary;
  cloudinaryLibrary = new Promise((resolve, reject) => {
    const script = document.createElement('script');
    script.src = 'https://upload-widget.cloudinary.com/latest/global/all.js';
    script.async = true;
    script.onload = () => window.cloudinary ? resolve(window.cloudinary) : reject(new Error('Cloudinary unavailable'));
    script.onerror = () => reject(new Error('Unable to load Cloudinary'));
    document.head.appendChild(script);
  }).catch(error => {
    cloudinaryLibrary = null;
    throw error;
  });
  return cloudinaryLibrary;
}

function validCloudinaryUrl(value, cloud) {
  try {
    const url = new URL(value);
    return url.protocol === 'https:' && url.hostname === 'res.cloudinary.com' &&
      url.pathname.startsWith(`/${cloud}/image/upload/`);
  } catch (_) {
    return false;
  }
}

function setupUploader() {
  document.querySelectorAll('[data-cloudinary-uploader]').forEach(root => {
    if (root.dataset.enhanced === 'yes') return;
    root.dataset.enhanced = 'yes';
    const input = root.querySelector('[data-cloudinary-input]');
    const preview = root.querySelector('[data-cloudinary-preview]');
    const open = root.querySelector('[data-cloudinary-open]');
    const remove = root.querySelector('[data-cloudinary-remove]');
    const status = root.querySelector('[data-cloudinary-status]');
    if (!input || !open) return;
    const cloud = root.dataset.cloudName;
    const preset = root.dataset.uploadPreset;
    const notice = message => { if (status) status.textContent = message; };
    const setImage = url => {
      input.value = url;
      preview.replaceChildren();
      if (url) {
        const image = document.createElement('img');
        image.src = url;
        image.alt = root.dataset.previewLabel || 'Inventory illustration';
        image.className = 'inventory-cover-preview rounded-3';
        preview.appendChild(image);
      }
      if (remove) remove.hidden = !url;
      input.dispatchEvent(new Event('change', { bubbles: true }));
    };
    open.addEventListener('click', async () => {
      open.disabled = true;
      try {
        const cloudinary = await cloudinaryWidgetScript();
        const widget = cloudinary.createUploadWidget({
          cloudName: cloud,
          uploadPreset: preset,
          sources: ['local'],
          multiple: false,
          resourceType: 'image',
          maxFileSize: 5_000_000,
          clientAllowedFormats: ['jpg', 'jpeg', 'png', 'webp', 'gif']
        }, (error, result) => {
          if (error) {
            notice(root.dataset.errorLabel || 'Upload failed');
          } else if (result?.event === 'success') {
            const url = result.info?.secure_url;
            if (validCloudinaryUrl(url, cloud)) {
              setImage(url);
              notice(root.dataset.successLabel || 'Image uploaded. Save changes to keep it.');
            } else {
              notice(root.dataset.errorLabel || 'Upload failed');
            }
          }
        });
        widget.open();
      } catch (_) {
        notice(root.dataset.errorLabel || 'Upload failed');
      } finally {
        open.disabled = false;
      }
    });
    remove?.addEventListener('click', () => setImage(''));
  });
}

function setupEnhancements() {
  setupTags();
  setupUploader();
}

document.addEventListener('DOMContentLoaded', setupEnhancements);
document.addEventListener('turbo:load', setupEnhancements);
document.addEventListener('turbo:before-cache', () => {
  tagInstances.forEach(instance => instance.destroy());
  tagInstances.clear();
  document.querySelectorAll('[data-tag-input]').forEach(input => delete input.dataset.enhanced);
});
