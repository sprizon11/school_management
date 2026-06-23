import { IsArray, IsEnum, IsOptional, IsString, MaxLength, MinLength } from 'class-validator';
import { Gender } from '@prisma/client';

export class CreateTeacherDto {
  @IsString()
  @MinLength(2)
  fullName: string;

  @IsString()
  email: string;

  @IsOptional()
  @IsString()
  phone?: string;

  @IsOptional()
  @IsEnum(Gender)
  gender?: Gender;

  @IsOptional()
  @IsString()
  department?: string;

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

  /** Additional classes where teacher teaches subject (not class teacher). */
  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  teachingClassIds?: string[];
}
