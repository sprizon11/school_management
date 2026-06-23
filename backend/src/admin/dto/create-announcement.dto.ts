import { AnnouncementAudience } from '@prisma/client';
import { IsEnum, IsOptional, IsString, MinLength } from 'class-validator';

export class CreateAnnouncementDto {
  @IsString()
  @MinLength(1)
  title: string;

  @IsString()
  @MinLength(1)
  body: string;

  @IsEnum(AnnouncementAudience)
  audience: AnnouncementAudience;

  @IsOptional()
  @IsString()
  eventDate?: string;
}
