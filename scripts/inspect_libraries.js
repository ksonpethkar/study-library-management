const main = async () => {
  const res = await fetch('https://firestore.googleapis.com/v1/projects/study-lib-mgmt-2026/databases/(default)/documents/libraries');
  const data = await res.json();
  if (data.documents) {
    for (const doc of data.documents) {
      const id = doc.name.split('/').pop();
      const fields = doc.fields || {};
      const name = fields.name ? fields.name.stringValue : 'No Name';
      const email = fields.email ? fields.email.stringValue : 'No Email';
      const phone = fields.phone ? fields.phone.stringValue : 'No Phone';
      const ownerId = fields.ownerId ? fields.ownerId.stringValue : 'No OwnerId';
      console.log(`ID: ${id} | Name: "${name}" | Email: ${email} | Phone: ${phone} | OwnerId: ${ownerId}`);
    }
  } else {
    console.log('No documents or error:', data);
  }
};
main();
