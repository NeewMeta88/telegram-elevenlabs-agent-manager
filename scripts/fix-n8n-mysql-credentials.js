const fs = require('fs');

const workflowPath = process.argv[2];

if (!workflowPath) {
  console.error('Usage: node scripts/fix-n8n-mysql-credentials.js <workflow.json>');
  process.exit(1);
}

const workflow = JSON.parse(fs.readFileSync(workflowPath, 'utf8'));

if (!Array.isArray(workflow.nodes)) {
  console.error('Invalid n8n workflow: nodes array not found.');
  process.exit(1);
}

const mysqlNodes = workflow.nodes.filter((node) =>
  String(node.type || '').toLowerCase().includes('mysql')
);

if (mysqlNodes.length === 0) {
  console.error('No MySQL nodes found.');
  process.exit(1);
}

let sourceNode = null;
let credentialKey = null;
let credentialValue = null;

for (const node of mysqlNodes) {
  const credentials = node.credentials || {};
  for (const [key, value] of Object.entries(credentials)) {
    if (key.toLowerCase().includes('mysql') && value && (value.id || value.name)) {
      sourceNode = node;
      credentialKey = key;
      credentialValue = value;
      break;
    }
  }

  if (sourceNode) break;
}

if (!sourceNode || !credentialKey || !credentialValue) {
  console.error('No MySQL node with a real credential found.');
  console.error('Assign MySQL credentials to one MySQL node in n8n, export the workflow, then run this script again.');
  process.exit(1);
}

let updated = 0;

for (const node of mysqlNodes) {
  node.credentials = node.credentials || {};

  for (const key of Object.keys(node.credentials)) {
    if (key.toLowerCase().includes('mysql')) {
      delete node.credentials[key];
    }
  }

  node.credentials[credentialKey] = credentialValue;
  updated += 1;
}

const stillMissing = mysqlNodes.filter((node) => {
  const credentials = node.credentials || {};
  return !credentials[credentialKey] || (!credentials[credentialKey].id && !credentials[credentialKey].name);
});

fs.writeFileSync(workflowPath, JSON.stringify(workflow, null, 2) + '\n');

console.log(`Source credential from node: ${sourceNode.name}`);
console.log(`Credential key: ${credentialKey}`);
console.log(`Credential name: ${credentialValue.name || '(no name)'}`);
console.log(`Updated MySQL nodes: ${updated}`);
console.log(`Still missing: ${stillMissing.length}`);

if (stillMissing.length > 0) {
  console.log('Nodes still missing credentials:');
  for (const node of stillMissing) {
    console.log(`- ${node.name}`);
  }
  process.exit(1);
}
