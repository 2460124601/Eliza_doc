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
        console.error('複製失敗:', err);
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
