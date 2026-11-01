const fs = require('fs');
const path = require('path');

const portalDir = path.join(__dirname, '..', 'public', 'portal');
const indexPath = path.join(portalDir, 'index.html');
const cssPath = path.join(portalDir, 'style.css');
const jsPath = path.join(portalDir, 'app.js');

let html = fs.readFileSync(indexPath, 'utf8');
const css = fs.readFileSync(cssPath, 'utf8');
const js = fs.readFileSync(jsPath, 'utf8');

// Replace or update embedded <style>
if (html.includes('<style>') && html.includes('</style>')) {
  html = html.replace(/<style>[\s\S]*?<\/style>/, `<style>\n${css}\n  </style>`);
} else if (html.includes('<link rel="stylesheet" href="style.css">')) {
  html = html.replace(
    '<link rel="stylesheet" href="style.css">',
    `<style>\n${css}\n  </style>`
  );
}

// Replace or update embedded <script>
if (html.includes('<script>') && html.includes('</script>')) {
  html = html.replace(/<script>[\s\S]*?<\/script>/, `<script>\n${js}\n  </script>`);
} else if (html.includes('<script src="app.js"></script>')) {
  html = html.replace(
    '<script src="app.js"></script>',
    `<script>\n${js}\n  </script>`
  );
}

fs.writeFileSync(indexPath, html, 'utf8');
console.log('Successfully bundled portal index.html! New size:', fs.statSync(indexPath).size);

// Bundle TV Display
const tvDir = path.join(__dirname, '..', 'public', 'tv');
const tvIndexPath = path.join(tvDir, 'index.html');
const tvCssPath = path.join(tvDir, 'style.css');
const tvJsPath = path.join(tvDir, 'tv.js');

if (fs.existsSync(tvIndexPath) && fs.existsSync(tvCssPath) && fs.existsSync(tvJsPath)) {
  let tvHtml = fs.readFileSync(tvIndexPath, 'utf8');
  const tvCss = fs.readFileSync(tvCssPath, 'utf8');
  const tvJs = fs.readFileSync(tvJsPath, 'utf8');

  if (tvHtml.includes('<style>') && tvHtml.includes('</style>')) {
    tvHtml = tvHtml.replace(/<style>[\s\S]*?<\/style>/, `<style>\n${tvCss}\n  </style>`);
  } else if (tvHtml.includes('<link rel="stylesheet" href="style.css">')) {
    tvHtml = tvHtml.replace(
      '<link rel="stylesheet" href="style.css">',
      `<style>\n${tvCss}\n  </style>`
    );
  }

  if (tvHtml.includes('<script>') && tvHtml.includes('</script>')) {
    tvHtml = tvHtml.replace(/<script>[\s\S]*?<\/script>/, `<script>\n${tvJs}\n  </script>`);
  } else if (tvHtml.includes('<script src="tv.js"></script>')) {
    tvHtml = tvHtml.replace(
      '<script src="tv.js"></script>',
      `<script>\n${tvJs}\n  </script>`
    );
  }

  fs.writeFileSync(tvIndexPath, tvHtml, 'utf8');
  console.log('Successfully bundled TV index.html! New size:', fs.statSync(tvIndexPath).size);
}

