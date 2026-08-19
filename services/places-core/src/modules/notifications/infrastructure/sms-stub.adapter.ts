import { Injectable, Logger } from "@nestjs/common";
import { SendOtpSmsInput, SmsPort } from "../domain/sms.port";

/**
 * Test/dev SMS sink — records last send; never delivers to a real network.
 * Forbidden in production via smsPortProvider().
 */
@Injectable()
export class SmsStubAdapter implements SmsPort {
  readonly providerName = "stub";
  private readonly logger = new Logger(SmsStubAdapter.name);
  last?: SendOtpSmsInput;

  async sendOtpSms(input: SendOtpSmsInput): Promise<{ messageId: string }> {
    this.last = input;
    this.logger.log({
      msg: "sms_stub_send",
      challengeId: input.challengeId,
      correlationId: input.correlationId,
      // Never log code or full phone.
      phoneSuffix: input.phoneE164.slice(-4),
    });
    return { messageId: `stub_sms_${input.challengeId}` };
  }
}
