const admin = require("firebase-admin");

const oldServiceAccount = require("./old-service-account.json");
const newServiceAccount = require("./new-service-account.json");

const oldApp = admin.initializeApp(
  {
    credential: admin.credential.cert(oldServiceAccount),
  },
  "old"
);

const newApp = admin.initializeApp(
  {
    credential: admin.credential.cert(newServiceAccount),
  },
  "new"
);

const oldDb = oldApp.firestore();
const newDb = newApp.firestore();

const collections = [
  "users",
  "trips",
  "settings",
  "driver_applications",
];

async function copySubcollections(oldDocRef, newDocRef) {
  const subcollections = await oldDocRef.listCollections();

  for (const subcollection of subcollections) {
    const docs = await subcollection.get();

    for (const doc of docs.docs) {
      const newSubDocRef = newDocRef
        .collection(subcollection.id)
        .doc(doc.id);

      await newSubDocRef.set(doc.data());

      console.log(`  ↳ ${subcollection.id}/${doc.id}`);

      await copySubcollections(doc.ref, newSubDocRef);
    }
  }
}

async function copyCollection(collectionName) {
  console.log(`\n=== ${collectionName} ===`);

  const snapshot = await oldDb.collection(collectionName).get();

  console.log(`${snapshot.size} document bulundu`);

  for (const doc of snapshot.docs) {
    const newDocRef = newDb.collection(collectionName).doc(doc.id);

    await newDocRef.set(doc.data());

    console.log(`✓ ${collectionName}/${doc.id}`);

    await copySubcollections(doc.ref, newDocRef);
  }
}

async function main() {
  try {
    for (const collection of collections) {
      await copyCollection(collection);
    }

    console.log("\nTAŞIMA TAMAMLANDI");
    process.exit(0);
  } catch (e) {
    console.error(e);
    process.exit(1);
  }
}

main();