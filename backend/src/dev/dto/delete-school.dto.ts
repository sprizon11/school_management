import { IsString } from 'class-validator';

export class DeleteSchoolDto {
  @IsString()
  confirmCode: string;
}
