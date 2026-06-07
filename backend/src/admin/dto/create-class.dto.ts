import { IsInt, IsOptional, IsString, Min, MinLength } from 'class-validator';

export class CreateClassDto {
  @IsInt()
  @Min(1)
  grade: number;

  @IsString()
  @MinLength(1)
  section: string;

  @IsString()
  @MinLength(2)
  name: string;

  @IsString()
  category: string;

  @IsOptional()
  @IsString()
  room?: string;

  @IsOptional()
  @IsString()
  classTeacherId?: string;

  @IsOptional()
  @IsString()
  academicYear?: string;
}
