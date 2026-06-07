import { IsArray, IsOptional, IsString, MaxLength, MinLength } from 'class-validator';

export class CreateTeacherDto {
  @IsString()
  @MinLength(2)
  fullName: string;

  @IsString()
  email: string;

  @IsOptional()
  @IsString()
  phone?: string;

  @IsString()
  department: string;

  @IsArray()
  @IsString({ each: true })
  subjects: string[];

  @IsOptional()
  @IsString()
  @MinLength(6)
  password?: string;

  @IsOptional()
  @IsString()
  @MaxLength(500000)
  avatarUrl?: string;

  @IsOptional()
  @IsString()
  classTeacherClassId?: string;
}
