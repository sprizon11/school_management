import { IsString, MinLength } from 'class-validator';

export class ResetAdminPasswordDto {
  @IsString()
  @MinLength(6)
  newPassword: string;
}
