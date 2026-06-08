import {
  IsDateString,
  IsEnum,
  IsInt,
  IsOptional,
  IsString,
  MaxLength,
  Min,
  MinLength,
} from 'class-validator';
import { Gender, StudentStatus } from '@prisma/client';

export class UpdateStudentDto {
  @IsOptional()
  @IsString()
  @MinLength(2)
  fullName?: string;

  @IsOptional()
  @IsEnum(Gender)
  gender?: Gender;

  @IsOptional()
  @IsString()
  classId?: string;

  @IsOptional()
  @IsString()
  email?: string;

  @IsOptional()
  @IsString()
  phone?: string;

  @IsOptional()
  @IsInt()
  @Min(1)
  rollNumber?: number;

  @IsOptional()
  @IsDateString()
  dateOfBirth?: string;

  @IsOptional()
  @IsString()
  bloodGroup?: string;

  @IsOptional()
  @IsString()
  address?: string;

  @IsOptional()
  @IsString()
  @MaxLength(500000)
  avatarUrl?: string;

  @IsOptional()
  @IsString()
  fatherName?: string;

  @IsOptional()
  @IsString()
  fatherPhone?: string;

  @IsOptional()
  @IsString()
  fatherOccupation?: string;

  @IsOptional()
  @IsString()
  motherName?: string;

  @IsOptional()
  @IsString()
  motherPhone?: string;

  @IsOptional()
  @IsString()
  motherOccupation?: string;

  @IsOptional()
  @IsString()
  parentAddress?: string;

  @IsOptional()
  @IsString()
  emergencyContact?: string;

  @IsOptional()
  @IsString()
  emergencyPhone?: string;

  @IsOptional()
  @IsEnum(StudentStatus)
  status?: StudentStatus;
}
