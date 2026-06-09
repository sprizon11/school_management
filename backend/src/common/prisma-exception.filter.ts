import {
  ArgumentsHost,
  Catch,
  ConflictException,
  ExceptionFilter,
  BadRequestException,
  NotFoundException,
} from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { Response } from 'express';

@Catch(Prisma.PrismaClientKnownRequestError)
export class PrismaExceptionFilter implements ExceptionFilter {
  catch(exception: Prisma.PrismaClientKnownRequestError, host: ArgumentsHost) {
    const ctx = host.switchToHttp();
    const response = ctx.getResponse<Response>();

    let status = 400;
    let message = 'Database request failed';

    switch (exception.code) {
      case 'P2002':
        status = 409;
        message = 'A record with these details already exists';
        break;
      case 'P2003':
        status = 400;
        message = 'A linked record is missing or invalid';
        break;
      case 'P2025':
        status = 404;
        message = 'Record not found';
        break;
      default:
        status = 400;
        message = exception.message;
        break;
    }

    const body =
      status === 409
        ? new ConflictException(message).getResponse()
        : status === 404
          ? new NotFoundException(message).getResponse()
          : new BadRequestException(message).getResponse();

    response.status(status).json(body);
  }
}
