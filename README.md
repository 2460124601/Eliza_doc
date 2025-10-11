# Eliza

![Eliza Logo](public/assets/images/logo.png)

---

## About

Eliza is a lightweight documentation generator that makes writing docs feel as easy as taking notes.
It converts Markdown files into clean static HTML, automatically handles navigation, multilingual content, and version control.

Simply put:  
> Focus on your content, let Eliza do the rest.

Eliza supports:
- Docker setup
- Live reload
- Static output

For more details, visit:  
[https://eliza.siunn.ing/](https://eliza.siunn.ing/)

---

## 關於 Eliza

Eliza 是一個輕量級文件生成工具，  
初衷很簡單——讓「寫文件」變得跟寫筆記一樣自然。

它會把 Markdown 檔案轉成乾淨的 HTML 頁面，並產生標籤與目錄。

簡單來說：  
> 專注寫內容，其他交給 Eliza。

目前支援：
- Docker 一鍵啟動  
- 熱更新  
- 靜態輸出  

詳細說明請參閱：  
[https://eliza.siunn.ing/](https://eliza.siunn.ing/)

---

## Project Structure

```shell
Eliza/
├─ build.rb                 # Main generator (Kramdown + Nokogiri + ERB)
├─ template.html.erb        # Main HTML template
├─ watch_poll_serve.rb      # Live reload for development
├─ serve.rb                 # Local server script
├─ content/                 # Markdown source content
│   ├─ v1.0/
│   │   ├─ en/
│   │   └─ zh-TW/
│   └─ v2.4/
│       ├─ en/
│       └─ zh-TW/
├─ public/                  # Generated static files
│   ├─ assets/              # Images, CSS, JS
│   └─ ...                  # index.html, 01-*.html, ...
└─ config/
    └─ config.yml           # Configuration file
```

## Quick Start

```shell
git clone https://github.com/2460124601/Eliza_doc.git
cd ./Eliza
docker-compose up --build dev

# visit: http://127.0.0.1:8080
```

## License
MIT License