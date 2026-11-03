const main = async () => {
  const res = await fetch('https://firestore.googleapis.com/v1/projects/study-lib-mgmt-2026/databases/(default)/documents/libraries/aPSMq8xSAjuZQh2fTtuY/students');
  const data = await res.json();
  if (data.documents) {
    for (const doc of data.documents) {
      const id = doc.name.split('/').pop();
      const fields = doc.fields || {};
      const name = fields.name ? fields.name.stringValue : 'No Name';
      const email = fields.email ? fields.email.stringValue : 'No Email';
      const phone = fields.phone ? fields.phone.stringValue : 'No Phone';
      const userId = fields.userId ? fields.userId.stringValue : 'No UserId';
      console.log(`Student ID: ${id} | Name: "${name}" | Email: ${email} | Phone: ${phone} | UserId: ${userId}`);
    }
  } else {
    console.log('No documents or error:', data);
  }
};
main();
