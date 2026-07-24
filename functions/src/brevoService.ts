/**
 * brevoService.ts
 * Dental Clinic Staff/Admin App — Cloud Functions
 *
 * Transactional email service integrating Brevo (formerly Sendinblue) v3 REST API.
 * Dispatches appointment updates, confirmations, and reminders.
 */

import * as logger from "firebase-functions/logger";

export interface SendEmailInput {
  toEmail: string;
  toName: string;
  subject: string;
  htmlContent: string;
}

export interface SendEmailResult {
  success: boolean;
  messageId?: string;
  error?: string;
}

/**
 * Sends a transactional email using Brevo's v3 SMTP REST API.
 * Falls back to dev logger if BREVO_API_KEY is not configured or mock.
 */
export async function sendBrevoEmail(input: SendEmailInput): Promise<SendEmailResult> {
  const apiKey = process.env.BREVO_API_KEY || "";
  const senderEmail = process.env.BREVO_SENDER_EMAIL || "no-reply@oralscope.dev";
  const senderName = process.env.BREVO_SENDER_NAME || "OralScope Dental Clinic";

  // Development / Mock fallback if key is unconfigured or mock
  if (!apiKey || apiKey.startsWith("mock") || apiKey === "re_BafTxwMY_NJ6pYmZtjPJxCCPrGVuHP6MX") {
    logger.info("[Brevo Service (DEV MOCK)] Email Dispatch Triggered:", {
      toEmail: input.toEmail,
      toName: input.toName,
      subject: input.subject,
      sender: `${senderName} <${senderEmail}>`,
      notice: "Configure BREVO_API_KEY in functions/.env for live inbox delivery.",
    });
    return { success: true, messageId: `mock_brevo_${Date.now()}` };
  }

  const payload = {
    sender: {
      name: senderName,
      email: senderEmail,
    },
    to: [
      {
        email: input.toEmail,
        name: input.toName,
      },
    ],
    subject: input.subject,
    htmlContent: input.htmlContent,
  };

  try {
    const response = await fetch("https://api.brevo.com/v3/smtp/email", {
      method: "POST",
      headers: {
        "accept": "application/json",
        "api-key": apiKey.trim(),
        "content-type": "application/json",
      },
      body: JSON.stringify(payload),
    });

    if (!response.ok) {
      const errorText = await response.text();
      logger.error("[Brevo Service] API dispatch error:", {
        status: response.status,
        statusText: response.statusText,
        error: errorText,
      });
      return { success: false, error: `Brevo API ${response.status}: ${errorText}` };
    }

    const data = await response.json() as { messageId?: string };
    logger.info("[Brevo Service] Email sent successfully:", {
      messageId: data.messageId,
      toEmail: input.toEmail,
      subject: input.subject,
    });

    return { success: true, messageId: data.messageId };
  } catch (err) {
    const errorMsg = (err as Error).message;
    logger.error("[Brevo Service] Network exception:", { error: errorMsg });
    return { success: false, error: errorMsg };
  }
}
