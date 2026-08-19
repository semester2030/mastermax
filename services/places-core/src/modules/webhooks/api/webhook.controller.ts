import { Controller, Headers, Param, Post, Req } from '@nestjs/common';
import { Request } from 'express';
import { Public } from '../../../shared/auth/auth.decorators';
import { CorrelatedRequest } from '../../../shared/observability/correlation';
import { PaymentService } from '../../payments/application/payment.service';

@Controller('v1/webhooks/psp')
export class WebhookController {
  constructor(private readonly payments: PaymentService) {}

  @Public()
  @Post(':pspName')
  handle(
    @Param('pspName') _psp: string,
    @Req() req: Request & CorrelatedRequest & { rawBody?: string },
    @Headers('x-stub-signature') signature: string | undefined,
  ) {
    const raw = req.rawBody ?? JSON.stringify(req.body ?? {});
    return this.payments.handleWebhook(raw, signature, req.correlationId);
  }
}
