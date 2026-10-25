document.addEventListener("DOMContentLoaded", function () {
  const codeContainers = document.querySelectorAll('.code-container');
  codeContainers.forEach(container => {
    const copyButton = document.createElement('button');
    copyButton.className = 'copy-button material-symbols-outlined';
    copyButton.innerText = 'content_copy';
    container.appendChild(copyButton);

    copyButton.addEventListener('click', function () {
      const codeElement = container.querySelector('code');
      const codeText = codeElement.innerText;
      navigator.clipboard.writeText(codeText).then(() => {
        copyButton.innerText = 'check';
        setTimeout(() => {
          copyButton.innerText = 'content_copy';
        }, 2000);
      }).catch(err => {
        console.error('Copy failed:', err);
      });
    });
  });
  const images = document.querySelectorAll(".showImage");
  images.forEach(image => {
    image.addEventListener('click', () => {
      const dialog = document.createElement('dialog');
      dialog.style = `
        position: fixed;
        inset: 0;
        background-color:rgb(141 141 141 / 49%);
        backdrop-filter: blur(5px);
        display: flex;
        justify-content: center;
        align-items: center;
        border: none;
        z-index: 1000;
      `;
      const dialogImage = document.createElement('img');
      dialogImage.src = image.src;
      dialogImage.style.maxWidth = '90%';
      dialogImage.style.maxHeight = '90%';

      const closeBtn = document.createElement('span');
      closeBtn.textContent = '×';
      closeBtn.style = `
        position: absolute;
        top: 20px;
        right: 30px;
        font-size: 40px;
        color: white;
        cursor: pointer;
        z-index: 1001;
      `;
      closeBtn.onclick = () => {
        dialog.close();
        dialog.remove();
      };

      dialog.onclick = (e) => {
        if (e.target === dialog) {
          dialog.close();
          dialog.remove();
        }
      };

      dialog.append(dialogImage, closeBtn);
      document.body.appendChild(dialog);
      dialog.showModal();
    });
  });
});

// Sidebar width: drag the handle, arrow keys to adjust, double-click to reset.
(function () {
  const KEY = 'eliza.sidebarWidth';
  const root = document.documentElement;
  const MIN = 160;
  const maxWidth = () => Math.round(window.innerWidth * 0.5);
  const clamp = (w) => Math.min(Math.max(w, MIN), maxWidth());

  function apply(w, save) {
    root.style.setProperty('--sidebar-width', w + 'px');
    if (save) {
      try { localStorage.setItem(KEY, String(w)); } catch (e) {}
    }
  }

  function reset() {
    root.style.removeProperty('--sidebar-width');
    try { localStorage.removeItem(KEY); } catch (e) {}
  }

  document.addEventListener('DOMContentLoaded', function () {
    const sidebar = document.getElementById('sidebarBox');
    const handle = document.getElementById('sidebarResizer');
    if (!sidebar || !handle) return;

    const current = () => sidebar.getBoundingClientRect().width;

    handle.addEventListener('pointerdown', function (e) {
      e.preventDefault();
      handle.setPointerCapture(e.pointerId);
      handle.classList.add('dragging');
      document.body.classList.add('sidebar-resizing');
    });
    handle.addEventListener('pointermove', function (e) {
      if (!handle.hasPointerCapture(e.pointerId)) return;
      apply(clamp(e.clientX), false);
    });
    function end(e) {
      if (!handle.hasPointerCapture(e.pointerId)) return;
      handle.releasePointerCapture(e.pointerId);
      handle.classList.remove('dragging');
      document.body.classList.remove('sidebar-resizing');
      apply(Math.round(current()), true);
    }
    handle.addEventListener('pointerup', end);
    handle.addEventListener('pointercancel', end);
    handle.addEventListener('dblclick', reset);
    handle.addEventListener('keydown', function (e) {
      const step = e.shiftKey ? 48 : 16;
      if (e.key === 'ArrowLeft') apply(clamp(current() - step), true);
      else if (e.key === 'ArrowRight') apply(clamp(current() + step), true);
      else return;
      e.preventDefault();
    });

    window.addEventListener('resize', function () {
      if (root.style.getPropertyValue('--sidebar-width')) apply(clamp(current()), false);
    });
  });
})();

(function () {
  const KEY = 'eliza.theme';
  const root = document.documentElement;
  const media = window.matchMedia('(prefers-color-scheme: light)');

  const current = () => root.getAttribute('data-theme') || (media.matches ? 'light' : 'dark');

  document.addEventListener('DOMContentLoaded', function () {
    const btn = document.getElementById('themeToggle');
    if (!btn) return;
    const icon = btn.querySelector('.material-symbols-outlined');
    const sync = () => {
      const t = current();
      if (icon) icon.textContent = t === 'light' ? 'dark_mode' : 'light_mode';
      btn.setAttribute('aria-label', t === 'light' ? 'Switch to dark theme' : 'Switch to light theme');
    };
    btn.addEventListener('click', function () {
      const next = current() === 'light' ? 'dark' : 'light';
      root.setAttribute('data-theme', next);
      try { localStorage.setItem(KEY, next); } catch (e) {}
      sync();
    });
    media.addEventListener('change', sync);
    sync();
  });
})();
