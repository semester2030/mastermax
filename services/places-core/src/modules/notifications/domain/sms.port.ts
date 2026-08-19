/**
 * Phase 5: outbound OTP SMS port.
 * Production must use a real adapter; fixed OTP remains internal/test-only.
 */
export interface SendOtpSmsInput {
  phoneE164: string;
  code: string;
  correlationId: string;
  challengeId: string;
}

export interface SmsPort {
  readonly providerName: string;
  sendOtpSms(input: SendOtpSmsInput): Promise<{ messageId: string }>;
}

export const SMS_PORT = Symbol("SMS_PORT");
