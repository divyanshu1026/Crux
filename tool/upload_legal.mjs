import fs from 'node:fs';
import readline from 'node:readline';

const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout,
});

const serviceKey = process.argv[2] || await new Promise(resolve => {
  rl.question('Paste your Supabase service_role secret key: ', answer => {
    rl.close();
    resolve(answer.trim());
  });
});

if (!serviceKey) {
  console.error('Service role key cannot be empty.');
  process.exit(1);
}

const files = ['privacy-policy.html', 'terms-of-use.html', 'account-deletion.html'];
const baseUrl = 'https://ryklcllmzkpaxxpbsitg.supabase.co/storage/v1/object';

for (const file of files) {
  const filePath = `store/${file}`;
  if (!fs.existsSync(filePath)) {
    console.warn(`File not found: ${filePath}`);
    continue;
  }

  const content = fs.readFileSync(filePath);
  console.log(`Uploading ${file} with Content-Type: text/html...`);

  const res = await fetch(`${baseUrl}/Legal/${file}`, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${serviceKey}`,
      'apikey': serviceKey,
      'Content-Type': 'text/html; charset=utf-8',
      'x-upsert': 'true',
    },
    body: content,
  });

  const bodyText = await res.text();
  console.log(`Result for ${file} [${res.status}]:`, bodyText);

  const checkRes = await fetch(`${baseUrl}/public/Legal/${file}`, { method: 'HEAD' });
  console.log(`Verified Content-Type: ${checkRes.headers.get('content-type')}\n`);
}
