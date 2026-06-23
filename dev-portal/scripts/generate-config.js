const fs = require('fs');
const path = require('path');

const apiBase =
  process.env.PORTAL_API_BASE ||
  process.env.API_BASE_URL ||
  'https://school-management-9yzh.onrender.com/api';

const file = `window.PORTAL_CONFIG = {
  apiBase: ${JSON.stringify(apiBase.replace(/\/$/, ''))},
};
`;

fs.writeFileSync(path.join(__dirname, '..', 'config.js'), file);
console.log('Generated config.js for', apiBase);
