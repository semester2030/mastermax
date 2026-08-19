import { Body, Controller, Headers, Post, Req } from '@nestjs/common';
import { IsOptional, IsString, Matches, MinLength } from 'class-validator';
import { AuthUser } from '../../../shared/auth/auth-user';
import {
  CurrentUser,
  Public,
  RequireClaim,
} from '../../../shared/auth/auth.decorators';
import { CorrelatedRequest } from '../../../shared/observability/correlation';
import { AppError } from '../../../shared/errors/app-error';
import { ErrorCodes } from '../../../shared/errors/error-codes';
import { OperatorAuthService } from '../application/operator-auth.service';

class SendOtpDto {
  @IsString()
  @Matches(/^\+[1-9]\d{7,14}$/)
  phoneE164!: string;

  @IsOptional()
  @IsString()
  @MinLength(8)
  providerId?: string;
}

class VerifyOtpDto {
  @IsString()
  @MinLength(8)
  challengeId!: string;

  @IsString()
  @Matches(/^\d{4,8}$/)
  code!: string;
}

@Controller('v1/auth')
export class OperatorAuthController {
  constructor(private readonly auth: OperatorAuthService) {}

  @Public()
  @Post('internal/otp/send')
  send(@Req() req: CorrelatedRequest, @Body() body: SendOtpDto) {
    return this.auth.sendOtp({
      phoneE164: body.phoneE164,
      providerId: body.providerId,
      correlationId: req.correlationId,
    });
  }

  @Public()
  @Post('internal/otp/verify')
  verify(@Req() req: CorrelatedRequest, @Body() body: VerifyOtpDto) {
    return this.auth.verifyOtp({
      challengeId: body.challengeId,
      code: body.code,
      correlationId: req.correlationId,
    });
  }

  @RequireClaim('placesInternalOperator')
  @Post('session/logout')
  logout(
    @CurrentUser() user: AuthUser,
    @Req() req: CorrelatedRequest,
    @Headers('authorization') authorization?: string,
  ) {
    const jti = user.jti;
    if (!jti) {
      throw new AppError(ErrorCodes.UNAUTHENTICATED, 'Missing session jti');
    }
    void authorization;
    return this.auth.logout({
      jti,
      actorUid: user.uid,
      correlationId: req.correlationId,
    });
  }
}
