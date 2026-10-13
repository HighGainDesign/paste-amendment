(() => {
  'use strict';

  const textInputTypes = new Set(['text', 'search', 'url', 'tel', 'email', 'password', 'number']);

  function isWritableTarget(event) {
    // The first element is the actual target, including inside open shadow DOM.
    // Do not walk past a readonly field or a contenteditable="false" island.
    const target = event.composedPath().find(node => node instanceof HTMLElement);
    if (!target) return false;

    if (target instanceof HTMLInputElement) {
      return textInputTypes.has(target.type) && !target.readOnly && !target.matches(':disabled');
    }
    if (target instanceof HTMLTextAreaElement) {
      return !target.readOnly && !target.matches(':disabled');
    }
    return target.isContentEditable || (
      document.designMode === 'on' && !target.closest('[contenteditable="false"]')
    );
  }

  function preserveNativePaste(event) {
    if (isWritableTarget(event)) {
      // Prevent page handlers from canceling paste, leaving the browser's
      // default insertion, selection replacement, undo and input events intact.
      event.stopImmediatePropagation();
    }
  }

  window.addEventListener('paste', preserveNativePaste, true);
  window.addEventListener('beforeinput', event => {
    if (event.inputType?.startsWith('insertFromPaste')) preserveNativePaste(event);
  }, true);
  window.addEventListener('keydown', event => {
    const pasteShortcut = event.key?.toLowerCase() === 'v'
      && (event.metaKey || event.ctrlKey) && !event.altKey;
    const shiftInsert = event.key === 'Insert' && event.shiftKey
      && !event.metaKey && !event.ctrlKey && !event.altKey;
    if (pasteShortcut || shiftInsert) preserveNativePaste(event);
  }, true);
})();
