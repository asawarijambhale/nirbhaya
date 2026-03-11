/**
 * Import function triggers from their respective submodules:
 *
 * const {onCall} = require("firebase-functions/v2/https");
 * const {onDocumentWritten} = require("firebase-functions/v2/firestore");
 *
 * See a full list of supported triggers at https://firebase.google.com/docs/functions
 */

const {setGlobalOptions} = require("firebase-functions");

const functions = require("firebase-functions");
const admin = require("firebase-admin");


admin.initializeApp();

const accountSid = "AC00a66c4da2719ee9cf356be01cb7a904";
const authToken = "cd1135693124206032cc5a1a24d13978";
const twilioNumber = "+1 831 279 2132";

const Twilio = require("twilio");
const client = new Twilio(accountSid, authToken);

exports.sendSOS = functions.firestore
    .document("sos_events/{eventId}")
    .onCreate(async (snap, context) => {
      const data = snap.data();
      const contacts = data.contacts;
      const location = data.location;

      const message = `🚨 EMERGENCY ALERT!
I need help!
My location: ${location}`;

      try {
        for (const contact of contacts) {
          await client.messages.create({
            body: message,
            from: twilioNumber,
            to: contact.phone,
          });
        }

        console.log("SMS sent successfully");
      } catch (error) {
        console.error("Error sending SMS:", error);
      }
    });
// For cost control, you can set the maximum number of containers that can be
// running at the same time. This helps mitigate the impact of unexpected
// traffic spikes by instead downgrading performance. This limit is a
// per-function limit. You can override the limit for each function using the
// `maxInstances` option in the function's options, e.g.
// `onRequest({ maxInstances: 5 }, (req, res) => { ... })`.
// NOTE: setGlobalOptions does not apply to functions using the v1 API. V1
// functions should each use functions.runWith({ maxInstances: 10 }) instead.
// In the v1 API, each function can only serve one request per container, so
// this will be the maximum concurrent request count.
setGlobalOptions({maxInstances: 10});

// Create and deploy your first functions
// https://firebase.google.com/docs/functions/get-started

// exports.helloWorld = onRequest((request, response) => {
//   logger.info("Hello logs!", {structuredData: true});
//   response.send("Hello from Firebase!");
// });
